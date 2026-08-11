# CRM Deals — Port to Chatwoot v4.16 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the CRM deals feature, built and reviewed against Chatwoot 3.14.1, onto Chatwoot v4.16.2 — the version actually running in production.

**Architecture:** The source work lives on branch `develop` of this fork (49 commits, base `69f10a94c`). Every backend file it adds or touches still exists in v4.16.2, and the shared-file edits are additive, so the backend ports by copy plus re-applied hunks. The frontend CRM screens are self-contained and copy across, but three of the five mount points changed: `modules/contact/components/ContactPanel.vue` and `routes/dashboard/contacts/components/ContactInfoPanel.vue` are gone, and the primary nav moved from a `primaryMenu.js` array into an inline structure in `components-next/sidebar/Sidebar.vue`.

**Tech Stack:** Ruby 3.4.4, Rails 7.x, RSpec; Vue 3 `<script setup>`, Vuex, vue-i18n, Vitest, `@vue/test-utils`, Tailwind, `components-next` design system.

**Source of truth for the feature:** `docs/superpowers/specs/2026-08-11-crm-deals-design.md` on `develop` (not present on this branch until Task P1 copies it).

## Global Constraints

- Work happens in the worktree at `.worktrees/v4`, branch `feat/crm-v4`, based on tag `v4.16.2`. Never commit to `develop` from here.
- Backend commands run in the container `cw-v4-rails-1` (Ruby 3.4.4), repo mounted at `/app`:
  `docker exec -w /app -e RAILS_ENV=test cw-v4-rails-1 bundle exec <cmd>`
  Note this is a DIFFERENT container from `cw-dev-rails-1`, which serves the 3.14 tree.
- Frontend commands run on the host from `.worktrees/v4` with the system Node 24 and pnpm 10 — v4's `engines` require exactly those, so no PATH override is needed here (unlike the 3.14 tree).
- The reference implementation is on `develop`. Read a file from it with `git show develop:<path>`; never edit `develop`.
- Feature flag stays `deals`, shipping disabled.
- Every behaviour the 3.14 version had must survive the port. The 3.14 specs are the contract: they come across too, and they must pass.
- Tenancy rule stands: a deal's `contact`, `deal_stage` and `assignee` must belong to the deal's own account, enforced by a model validation.
- New user-facing strings live in `en` and `pt_BR` only.
- There is no browser verification available. Component specs are the only verification, exactly as in the source work.

---

## Task P1: Backend port

**Files — copy verbatim from `develop`:**
- `db/migrate/20260811120000_create_deal_stages.rb`, `20260811120100_create_deals.rb`, `20260811120200_create_deal_activities.rb`
- `app/models/deal_stage.rb`, `deal.rb`, `deal_activity.rb`, `app/models/concerns/deal_activity_loggable.rb`
- `app/policies/deal_policy.rb`, `deal_stage_policy.rb`
- `app/controllers/api/v1/accounts/deals_controller.rb`, `deal_stages_controller.rb`, `deals/activities_controller.rb`, `contacts/deals_controller.rb`
- `app/views/api/v1/models/_deal.json.jbuilder`, `_deal_stage.json.jbuilder`, `_deal_activity.json.jbuilder`
- `app/views/api/v1/accounts/deals/**`, `deal_stages/**`, `contacts/deals/**`
- `spec/factories/deals.rb`, `deal_stages.rb`, `deal_activities.rb`
- `spec/models/deal_spec.rb`, `deal_stage_spec.rb`, `deal_activity_spec.rb`
- `spec/policies/deal_policy_spec.rb`, `deal_stage_policy_spec.rb`
- `spec/controllers/api/v1/accounts/deals_controller_spec.rb`, `deal_stages_controller_spec.rb`, `deals/activities_controller_spec.rb`

**Files — re-apply additive hunks by hand:**
- `app/models/account.rb`: `has_many :deal_stages`, `:deals`, `:deal_activities`, all `dependent: :destroy_async`
- `app/models/contact.rb`: `has_many :deals, dependent: :destroy_async`
- `config/routes.rb`: the `deal_stages` block (with `patch :reorder, on: :collection`), the `deals` block (with `get :board, on: :collection`, `patch :move, on: :member`, and the nested `scope module: :deals { resources :activities, only: [:index, :create] }`), and inside the existing `resources :contacts` block, `scope module: :contacts { resources :deals, only: [:index] }`
- `config/features.yml`: `- name: deals` / `enabled: false`
- `config/locales/en.yml` and `pt_BR.yml`: `errors.deal_stages.has_deals` and `errors.deal_activities.invalid_type`

- [ ] **Step 1: Copy the new files**

For each path in the copy list: `git show develop:<path> > <path>` (creating directories as needed). Do not hand-retype them.

- [ ] **Step 2: Run the model specs and watch them fail**

Run: `docker exec -w /app -e RAILS_ENV=test cw-v4-rails-1 bundle exec rspec spec/models/deal_spec.rb`
Expected: FAIL — the tables do not exist yet, and `Account#deals` is not defined.

- [ ] **Step 3: Re-apply the shared-file hunks**

Read each shared file on this branch first, then add the lines listed above in the position that matches THIS file's current structure — not the line numbers from 3.14. Compare against `git show develop:<path>` to see exactly what the source added.

- [ ] **Step 4: Migrate**

Run: `docker exec -w /app -e RAILS_ENV=test cw-v4-rails-1 bundle exec rails db:create db:migrate`
Expected: the three tables created, `db/schema.rb` regenerated.

- [ ] **Step 5: Run the full backend feature suite**

Run: `docker exec -w /app -e RAILS_ENV=test cw-v4-rails-1 bundle exec rspec spec/models/deal_spec.rb spec/models/deal_stage_spec.rb spec/models/deal_activity_spec.rb spec/policies/deal_policy_spec.rb spec/policies/deal_stage_policy_spec.rb spec/controllers/api/v1/accounts/deals_controller_spec.rb spec/controllers/api/v1/accounts/deal_stages_controller_spec.rb spec/controllers/api/v1/accounts/deals`
Expected: PASS. The 3.14 run was 121 examples, 0 failures — the count here should match or exceed it.

Any failure is a real API drift between 3.14 and v4. Fix the port, not the spec, unless the spec asserts something v4 legitimately changed — and if so, say exactly what changed and why in your report.

- [ ] **Step 6: Rubocop and commit**

```bash
docker exec -w /app cw-v4-rails-1 bundle exec rubocop app/models/deal.rb app/models/deal_stage.rb app/models/deal_activity.rb app/models/concerns/deal_activity_loggable.rb app/policies/deal_policy.rb app/policies/deal_stage_policy.rb app/controllers/api/v1/accounts/deals_controller.rb app/controllers/api/v1/accounts/deal_stages_controller.rb app/controllers/api/v1/accounts/deals app/controllers/api/v1/accounts/contacts/deals_controller.rb -a
git add db/migrate app/models app/policies app/controllers app/views config/routes.rb config/features.yml config/locales/en.yml config/locales/pt_BR.yml db/schema.rb spec
git commit -m "feat: port the CRM deals backend to v4.16"
```

---

## Task P2: Frontend state and self-contained screens

**Files — copy verbatim from `develop`:**
- `app/javascript/dashboard/api/deals.js`, `dealStages.js`
- `app/javascript/dashboard/store/modules/deals.js`, `dealStages.js`
- `app/javascript/dashboard/store/modules/specs/deals/**`
- `app/javascript/dashboard/routes/dashboard/crm/**` (pages, components, helpers, and their specs)
- `app/javascript/dashboard/routes/dashboard/settings/dealStages/**`
- `app/javascript/dashboard/i18n/locale/en/crm.json`, `pt_BR/crm.json`

**Files — re-apply additive hunks by hand:**
- `featureFlags.js`: `DEALS: 'deals'`
- `store/index.js`: register `deals` and `dealStages`
- `store/mutation-types.js`: the `// DEALS` and `// DEAL STAGES` blocks
- `routes/dashboard/dashboard.routes.js`: mount `crmRoutes.routes`
- `routes/dashboard/settings/settings.routes.js`: mount `dealStages.routes`
- `i18n/locale/en/index.js` and `pt_BR/index.js`: import and spread `crm.json`

- [ ] **Step 1: Copy the files, then run the store spec and watch it fail**

Copy as in P1 Step 1, but re-apply the shared hunks LAST so you get a genuine red run first.

Run: `cd .worktrees/v4 && TZ=UTC pnpm vitest run app/javascript/dashboard/store/modules/specs/deals`
Expected: FAIL — the module is not registered.

- [ ] **Step 2: Re-apply the shared hunks**

Same method as P1 Step 3: read the v4 file, add the lines where they belong in ITS structure.

- [ ] **Step 3: Run every CRM spec**

Run: `TZ=UTC pnpm vitest run app/javascript/dashboard/routes/dashboard/crm app/javascript/dashboard/routes/dashboard/settings/dealStages app/javascript/dashboard/store/modules/specs/deals`
Expected: PASS.

Two failure modes to expect and handle honestly:
- A component the CRM screens import (`Avatar.vue`, `woot-button`, `useAlert`, `dashboard/composables/store`) moved or changed API in v4. Fix the import or swap to the v4 equivalent, and list every such swap in your report.
- A spec's mounting idiom no longer matches v4's test setup. Match what v4's own component specs do.

- [ ] **Step 4: Lint and commit**

```bash
pnpm eslint <the files you touched> --fix
git add app/javascript/dashboard/api app/javascript/dashboard/store app/javascript/dashboard/routes/dashboard/crm app/javascript/dashboard/routes/dashboard/settings app/javascript/dashboard/i18n app/javascript/dashboard/featureFlags.js
git commit -m "feat: port the CRM deals frontend state and screens to v4.16"
```

---

## Task P3: The three mount points

**Files — modify:**
- `app/javascript/dashboard/components-next/sidebar/Sidebar.vue` — the primary nav entry
- `app/javascript/dashboard/routes/dashboard/conversation/ContactPanel.vue` — the deals block in the conversation sidebar
- `app/javascript/dashboard/routes/dashboard/contacts/pages/ContactManageView.vue` — the deals section on the contact profile

**Files — copy from `develop` and adapt:**
- `app/javascript/dashboard/routes/dashboard/conversation/contact/ContactDeals.vue`

**Interfaces produced:** all three mounts gated on `FEATURE_FLAGS.DEALS` via `accounts/isFeatureEnabledonAccount`.

- [ ] **Step 1: Read all three v4 files before changing any of them**

They are structurally different from their 3.14 counterparts. `Sidebar.vue` builds its menu as an inline computed structure with `i-lucide-*` icons, `accountScopedRoute(...)` targets and `activeOn` arrays, grouped with children — not the flat `primaryMenu.js` array the source used. Note in your report how each one composes its sections.

- [ ] **Step 2: Copy `ContactDeals.vue` and fix its imports**

It imports `DealCard`, `DealFormDialog`, `formatDealValue`, `useAlert`, `useRouter` and the store composables. Verify each path against v4 and adjust.

- [ ] **Step 3: Mount the nav entry**

Add a CRM entry to `Sidebar.vue`'s menu structure, gated on the `deals` flag the same way v4 gates its own flagged entries — find one and copy the mechanism. Point it at the `deals_board` route from `crm.routes.js`. Use an `i-lucide-*` icon that is not already used by another top-level entry, and say which you chose.

- [ ] **Step 4: Mount the conversation sidebar block**

Render `ContactDeals` in `routes/dashboard/conversation/ContactPanel.vue`, flag-gated, following how that file composes its existing sections.

- [ ] **Step 5: Mount the contact profile section**

Render `ContactDeals` in `routes/dashboard/contacts/pages/ContactManageView.vue`, flag-gated, following how that file composes `ContactNotes` and its siblings.

- [ ] **Step 6: Specs**

Write or port a spec per mount point asserting the block renders with the flag ON and does NOT render with it OFF. The 3.14 branch has one for `ContactInfoPanel` (`git show develop:app/javascript/dashboard/routes/dashboard/contacts/components/specs/ContactInfoPanel.spec.js`) — adapt it to whichever v4 file you mounted into.

- [ ] **Step 7: Verify and commit**

Run the CRM specs plus the specs of all three files you touched. Everything green, eslint clean.

```bash
git commit -m "feat: mount the CRM deals screens in the v4 shell"
```

---

## Task P4: Visual alignment with components-next

**Files:** the CRM components under `app/javascript/dashboard/routes/dashboard/crm/`

The screens were styled against 3.14's Tailwind conventions (`bg-slate-25`, `dark:bg-slate-800`, hand-rolled buttons and dialogs). v4 ships a `components-next` design system with its own primitives and token palette.

- [ ] **Step 1: Inventory the gap**

Read two or three v4 `components-next` screens (a page, a dialog, a card) and list concretely: which primitives exist that the CRM screens hand-roll (Button, Dialog, Input, Select, Avatar, Card), and which colour tokens v4 uses where the CRM uses `slate-*`.

Report that inventory BEFORE changing anything, with your recommendation on how far to go. Restyling everything is not automatically right — say what you would leave alone.

- [ ] **Step 2: Swap the primitives you listed**

Replace hand-rolled buttons, dialogs and inputs with the v4 equivalents where the swap is mechanical. Keep every behaviour and every spec assertion working; if a spec asserts on markup a primitive changes, update the assertion to the new markup and say so.

- [ ] **Step 3: Verify**

All CRM specs green, eslint clean, and report what remains visually inconsistent and why you left it.

- [ ] **Step 4: Commit**

```bash
git commit -m "refactor: align the CRM screens with the v4 design system"
```

---

## Task P5: Port sweep

- [ ] **Step 1: Backend suite**

`docker exec -w /app -e RAILS_ENV=test cw-v4-rails-1 bundle exec rspec spec/models/deal_spec.rb spec/models/deal_stage_spec.rb spec/models/deal_activity_spec.rb spec/policies/deal_policy_spec.rb spec/policies/deal_stage_policy_spec.rb spec/controllers/api/v1/accounts/deals_controller_spec.rb spec/controllers/api/v1/accounts/deal_stages_controller_spec.rb spec/controllers/api/v1/accounts/deals spec/models/account_spec.rb spec/models/contact_spec.rb`

- [ ] **Step 2: Full frontend suite**

`TZ=UTC pnpm vitest run` — the whole repo, so a broken shared file shows up.

- [ ] **Step 3: Linters**

rubocop on the changed backend files; `pnpm eslint` across `app/**`. Report the exact error and warning counts.

- [ ] **Step 4: Production build**

`pnpm vite build` — the only proof the ported SFCs compile against v4's toolchain.

- [ ] **Step 5: Run the app and seed demo data**

Bring up the v4 app on port 3010, enable the `deals` flag on the seeded account, and create demo deals — the same shape the 3.14 tree got. This is the first build where a human can actually click the feature in the UI they use in production, so it matters more here than anywhere else in either plan.

---

## Self-Review

**Spec coverage:** P1 ports every backend file and its specs; P2 the state layer and self-contained screens; P3 the three mount points that changed; P4 the visual language; P5 verifies the whole. The feature's behaviour contract is the ported 3.14 spec suite, which must pass unchanged except where v4 legitimately changed an API — and every such exception must be named in a report.

**Placeholder scan:** none — every step names its command and its expected result.

**Known risk this plan does not remove:** no browser verification exists in this environment for the 3.14 tree, but P5 Step 5 does stand the v4 app up, so the port ends in a clickable state. The drag-and-drop path, the deep link and the flag-off behaviour still need a human.
