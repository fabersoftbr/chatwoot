# CRM Deals — Round 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the gaps the whole-branch review found between the design spec and what round 1 shipped, and fix the value-input semantics.

**Architecture:** Round 1 (tasks 1–18, merged on `feat/crm-deals`) delivered the three tables, the account-scoped API, the policies, the `deals` flag, and the kanban / drawer / sidebar / settings screens. This round adds the four screens the spec promised but no task built, and changes the money input to read in currency units instead of cents.

**Tech Stack:** Rails 7.0, RSpec; Vue 3 `<script setup>`, Vuex, vue-i18n, Vitest, `@vue/test-utils`.

**Spec:** `docs/superpowers/specs/2026-08-11-crm-deals-design.md` · **Round 1 plan:** `docs/superpowers/plans/2026-08-11-crm-deals.md`

## Global Constraints

Everything from the round-1 plan's Global Constraints still binds. In addition:

- The `deals` DB column stays `value_cents`. No migration. Conversion happens at the input boundary only.
- Use only translation keys that already exist in `app/javascript/dashboard/i18n/locale/en/crm.json`, unless a task below explicitly authorizes a new key — and a new key must be added to BOTH `en/crm.json` and `pt_BR/crm.json` at the same path.
- Every new interactive control needs an accessible name.
- The environment has no Ruby on the host and no way to serve the app. Backend commands run as `docker exec -w /app -e RAILS_ENV=test cw-dev-rails-1 bundle exec <cmd>`; frontend commands need `export PATH=<scratchpad>/node-v20.18.1-darwin-arm64/bin:$PATH` first. **Browser verification is impossible — every task compensates with component specs.**
- Never `git add Gemfile.lock`.

---

## Task 19: Value input in currency units

**Files:**
- Modify: `app/javascript/dashboard/routes/dashboard/crm/helpers/position.js`
- Modify: `app/javascript/dashboard/routes/dashboard/crm/components/DealFormDialog.vue`
- Modify: `app/javascript/dashboard/routes/dashboard/crm/components/DealDetailsTab.vue`
- Test: `app/javascript/dashboard/routes/dashboard/crm/helpers/specs/position.spec.js`, `components/specs/DealFormDialog.spec.js`, `components/specs/DealDetailsTab.spec.js`

**Interfaces:**
- Consumes: `formatDealValue(valueCents, currency, locale)` (unchanged)
- Produces: `centsToUnits(valueCents)` → Number (`1200000 → 12000`), `unitsToCents(value)` → Number (`12000 → 1200000`), both returning `0` for null/undefined/NaN input

- [ ] **Step 1: Write the failing helper spec**

Append to `helpers/specs/position.spec.js`:

```js
import { centsToUnits, unitsToCents } from '../position';

describe('centsToUnits', () => {
  it('converts cents to currency units', () => {
    expect(centsToUnits(1200000)).toBe(12000);
  });

  it('returns 0 for empty input', () => {
    expect(centsToUnits(null)).toBe(0);
    expect(centsToUnits(undefined)).toBe(0);
  });
});

describe('unitsToCents', () => {
  it('converts currency units to cents', () => {
    expect(unitsToCents(12000)).toBe(1200000);
  });

  it('rounds to whole cents', () => {
    expect(unitsToCents(10.005)).toBe(1001);
  });

  it('returns 0 for empty input', () => {
    expect(unitsToCents('')).toBe(0);
    expect(unitsToCents(null)).toBe(0);
  });
});
```

- [ ] **Step 2: Run it and watch it fail**

Run: `export PATH=<scratchpad>/node-v20.18.1-darwin-arm64/bin:$PATH && TZ=UTC pnpm vitest run app/javascript/dashboard/routes/dashboard/crm/helpers/specs/position.spec.js`
Expected: FAIL — `centsToUnits is not a function`.

- [ ] **Step 3: Write the helpers**

Append to `helpers/position.js`:

```js
export const centsToUnits = valueCents => {
  const cents = Number(valueCents);

  return Number.isFinite(cents) ? cents / 100 : 0;
};

export const unitsToCents = value => {
  const units = Number(value);

  return Number.isFinite(units) ? Math.round(units * 100) : 0;
};
```

- [ ] **Step 4: Run the helper spec**

Expected: PASS.

- [ ] **Step 5: Convert the create dialog**

In `DealFormDialog.vue`, the form field becomes currency units and converts on submit. Replace the `value_cents` entry in the `form` reactive with `value: 0`, bind the input to `form.value`, and in `submit()` build the payload as:

```js
  const deal = await store.dispatch('deals/create', {
    ...form,
    value: undefined,
    value_cents: unitsToCents(form.value),
  });
```

Import `unitsToCents` from `../helpers/position`. Leave `open()`'s reset assigning `form.value = 0`.

- [ ] **Step 6: Convert the details tab**

In `DealDetailsTab.vue`, keep the store field name but display units. Bind the input to a local `valueInput` initialised from `centsToUnits(props.deal.value_cents)`, re-synced by the existing `watch` on `props.deal`, and emit on blur as:

```js
const saveValue = () => emit('update', { value_cents: unitsToCents(valueInput.value) });
```

Import both helpers from `../helpers/position`.

- [ ] **Step 7: Update both component specs**

In `DealFormDialog.spec.js`, the submit assertion's expected payload changes: typing `12000` must dispatch `value_cents: 1200000`. In `DealDetailsTab.spec.js`, add an example asserting the input renders `12000` for a deal with `value_cents: 1200000`, and that blurring after typing `500` emits `{ value_cents: 50000 }`.

- [ ] **Step 8: Run the crm suite and lint**

Run: `export PATH=...:$PATH && TZ=UTC pnpm vitest run app/javascript/dashboard/routes/dashboard/crm`
Expected: all green.
Then eslint the three changed files; expected 0 errors, 0 warnings.

- [ ] **Step 9: Commit**

```bash
git add app/javascript/dashboard/routes/dashboard/crm
git commit -m "fix: read and write deal value in currency units instead of cents"
```

---

## Task 20: Kanban filter bar

**Files:**
- Modify: `app/controllers/api/v1/accounts/deals_controller.rb`
- Test: `spec/controllers/api/v1/accounts/deals_controller_spec.rb`
- Create: `app/javascript/dashboard/routes/dashboard/crm/components/DealFilters.vue`
- Create: `app/javascript/dashboard/routes/dashboard/crm/components/specs/DealFilters.spec.js`
- Modify: `app/javascript/dashboard/routes/dashboard/crm/pages/DealsBoardPage.vue`

**Interfaces:**
- Consumes: `deals/fetchBoard(params)` (already forwards params to `DealsAPI.board(params)`), `agents/getAgents` + `agents/get`
- Produces:
  - `GET /deals/board` now honours `assignee_id`, `temperature`, `overdue` and `q`, applying them to the per-column deals AND to `deals_count` / `deals_value_cents`, so the headers match what is shown. `stage_id` is deliberately NOT honoured on `board` — the board groups by stage.
  - `DealFilters` props: none; emits `change` with `{ q, assignee_id, temperature, overdue }`, omitting empty values

- [ ] **Step 1: Write the failing controller spec**

Add to the `GET /deals/board` describe block in `spec/controllers/api/v1/accounts/deals_controller_spec.rb`:

```ruby
    it 'applies the same filters as the index and reflects them in the counts' do
      create(:deal, account: account, contact: contact, deal_stage: open_stage, value_cents: 10_000)
      wanted = create(:deal, account: account, contact: contact, deal_stage: open_stage,
                             value_cents: 25_000, temperature: :hot)

      get "/api/v1/accounts/#{account.id}/deals/board",
          params: { temperature: 'hot' },
          headers: agent.create_new_auth_token

      column = response.parsed_body['payload'].find { |stage| stage['id'] == open_stage.id }
      expect(column['deals'].pluck('id')).to eq([wanted.id])
      expect(column['deals_count']).to eq(1)
      expect(column['deals_value_cents']).to eq(25_000)
    end
```

- [ ] **Step 2: Run it and watch it fail**

Run: `docker exec -w /app -e RAILS_ENV=test cw-dev-rails-1 bundle exec rspec spec/controllers/api/v1/accounts/deals_controller_spec.rb -e 'applies the same filters'`
Expected: FAIL — the unfiltered column returns both deals and a count of 2.

- [ ] **Step 3: Make the filter chain reusable and apply it in `board`**

In `deals_controller.rb`, change `filtered_deals` to take an optional starting scope, and have `board` use it:

```ruby
  def board
    @deal_stages = DealStage.seed_defaults(Current.account)
    stage_deals = filtered_deals(Current.account.deals.where(deal_stage_id: @deal_stages.map(&:id)))

    @counts = stage_deals.unscope(:order).group(:deal_stage_id).count
    @sums = stage_deals.unscope(:order).group(:deal_stage_id).sum(:value_cents)
    @deals_by_stage = @deal_stages.index_with do |stage|
      stage_deals.where(deal_stage_id: stage.id).limit(RESULTS_PER_PAGE)
    end
  end
```

and

```ruby
  # rubocop:disable Metrics/AbcSize
  def filtered_deals(scope = Current.account.deals)
    deals = scope.includes(contact: { avatar_attachment: [:blob] }, assignee: { avatar_attachment: [:blob] }).ordered
    deals = deals.where(deal_stage_id: params[:stage_id]) if params[:stage_id].present? && action_name != 'board'
    deals = deals.where(assignee_id: params[:assignee_id]) if params[:assignee_id].present?
    deals = deals.where(temperature: params[:temperature]) if params[:temperature].present?
    deals = deals.overdue if ActiveModel::Type::Boolean.new.cast(params[:overdue])
    deals = search(deals) if params[:q].present?
    deals
  end
  # rubocop:enable Metrics/AbcSize
```

`index` keeps calling `filtered_deals` with no argument.

- [ ] **Step 4: Run the controller spec**

Run the whole `deals_controller_spec.rb`.
Expected: PASS, including the pre-existing board examples.

- [ ] **Step 5: Write the failing filter-bar spec**

Create `components/specs/DealFilters.spec.js`, following the mounting and i18n idiom of the neighbouring specs. Assert: typing in the search box emits `change` with `{ q }`; selecting a temperature emits it in the payload; toggling "overdue" emits `overdue: true` and un-toggling omits the key entirely; every control has an accessible name.

- [ ] **Step 6: Run it and watch it fail**

Expected: FAIL — cannot resolve `../DealFilters.vue`.

- [ ] **Step 7: Build the filter bar**

Create `DealFilters.vue` as a `<script setup>` component holding a `reactive` filter object with `q`, `assignee_id`, `temperature`, `overdue`; a search input, an assignee `<select>` populated from `useMapGetter('agents/getAgents')`, a temperature `<select>` with the three `CRM.TEMPERATURE.*` options plus an all-option using `CRM.FILTERS.ALL`, and an overdue checkbox labelled `CRM.FILTERS.OVERDUE`. Dispatch `agents/get` in `onMounted` when the agent list is empty. Emit `change` with a payload built by stripping empty values:

```js
const emitChange = () => {
  const payload = Object.fromEntries(
    Object.entries(filters).filter(([, value]) => value !== '' && value !== null && value !== false)
  );

  emit('change', payload);
};
```

Label the search input with `CRM.SEARCH_PLACEHOLDER`, the assignee select with `CRM.FILTERS.ASSIGNEE`, the temperature select with `CRM.FILTERS.TEMPERATURE`. All five keys already exist.

- [ ] **Step 8: Wire it into the board**

In `DealsBoardPage.vue`, hold `const filters = ref({})`, render `<DealFilters @change="onFiltersChange" />` under the header, and:

```js
const onFiltersChange = newFilters => {
  filters.value = newFilters;
  refresh();
};
```

with `refresh` changed to `store.dispatch('deals/fetchBoard', filters.value)`.

- [ ] **Step 9: Run the suites and lint**

Run the crm vitest suite and the backend deals controller spec; both green. eslint the changed frontend files and rubocop the controller; both clean.

- [ ] **Step 10: Commit**

```bash
git add app/controllers/api/v1/accounts/deals_controller.rb spec/controllers/api/v1/accounts/deals_controller_spec.rb app/javascript/dashboard/routes/dashboard/crm
git commit -m "feat: add kanban filter bar and honour filters on the board endpoint"
```

---

## Task 21: Assignee and currency in the details tab

**Files:**
- Modify: `app/javascript/dashboard/routes/dashboard/crm/components/DealDetailsTab.vue`
- Modify: `app/javascript/dashboard/routes/dashboard/crm/components/specs/DealDetailsTab.spec.js`
- Modify: `app/javascript/dashboard/i18n/locale/en/crm.json`, `app/javascript/dashboard/i18n/locale/pt_BR/crm.json`

**Interfaces:**
- Consumes: `agents/getAgents`, `agents/get`
- Produces: the details tab emits `update` with `{ assignee_id }` and `{ currency }`

**Authorized new key:** `CRM.FORM.CURRENCY` — "Currency" / "Moeda". Add it to BOTH locale files. `CRM.FORM.ASSIGNEE` already exists.

- [ ] **Step 1: Add the locale key to both files**

Add `"CURRENCY": "Currency"` to the `CRM.FORM` object in `en/crm.json` and `"CURRENCY": "Moeda"` at the same path in `pt_BR/crm.json`. Then verify the two files still have identical key structures with a script that walks both objects and diffs the key paths.

- [ ] **Step 2: Write the failing spec examples**

In `DealDetailsTab.spec.js`, add: the assignee select renders the account's agents and pre-selects the deal's current assignee; changing it emits `update` with only `{ assignee_id }`; the currency select renders and changing it emits only `{ currency }`; both controls have accessible names.

- [ ] **Step 3: Run and watch them fail**

Expected: FAIL — no such selects in the rendered output.

- [ ] **Step 4: Add both controls**

In `DealDetailsTab.vue`, add an assignee `<select>` bound to `form.assignee_id`, populated from `useMapGetter('agents/getAgents')` with a blank option for "no owner", saving via the existing `save('assignee_id')`; and a currency `<select>` bound to `form.currency` with options `BRL`, `USD`, `EUR`, saving via `save('currency')`. Dispatch `agents/get` in `onMounted` when the list is empty. Label both with `CRM.FORM.ASSIGNEE` and `CRM.FORM.CURRENCY`.

- [ ] **Step 5: Run the crm suite and lint**

Expected: all green, 0 eslint problems.

- [ ] **Step 6: Commit**

```bash
git add app/javascript/dashboard/routes/dashboard/crm app/javascript/dashboard/i18n/locale/en/crm.json app/javascript/dashboard/i18n/locale/pt_BR/crm.json
git commit -m "feat: allow editing a deal's owner and currency"
```

---

## Task 22: Complete the contact deals block

**Files:**
- Modify: `app/javascript/dashboard/routes/dashboard/conversation/contact/ContactDeals.vue`
- Modify: `app/javascript/dashboard/routes/dashboard/conversation/contact/specs/ContactDeals.spec.js`

**Interfaces:**
- Consumes: `deals/fetchByContact`, `deals/getStages`, `deals/move`, `DealCard.vue`, `formatDealValue`
- Produces: the block lists open AND closed deals and shows a won total

- [ ] **Step 1: Write the failing spec examples**

In `ContactDeals.spec.js`, add: a closed (won) deal is rendered rather than filtered out; the won total sums only deals in `won` stages and is formatted as currency; the advance button is absent on a deal in a non-open stage.

- [ ] **Step 2: Run and watch them fail**

Expected: FAIL — the closed deal is filtered out and no total renders.

- [ ] **Step 3: Render open and closed deals through `DealCard`**

In `ContactDeals.vue`, replace the hand-rolled row markup with `DealCard` (imported from `dashboard/routes/dashboard/crm/components/DealCard.vue`), rendering all of the contact's deals, open first. Keep the advance button, but render it only when the deal's stage is `open` and a next open stage exists. Add the won total under the list:

```js
const wonTotal = computed(() => {
  const wonStageIds = stages.value
    .filter(stage => stage.stage_type === 'won')
    .map(stage => stage.id);

  return deals.value
    .filter(deal => wonStageIds.includes(deal.deal_stage_id))
    .reduce((sum, deal) => sum + deal.value_cents, 0);
});
```

rendered with `formatDealValue(wonTotal, ...)` behind the existing `CRM.CONTACT_PANEL.TOTAL_WON` label, and only when it is non-zero.

- [ ] **Step 4: Run the suites and lint**

Run the crm vitest suite plus `app/javascript/dashboard/routes/dashboard/conversation`.
Expected: green, 0 eslint problems.

- [ ] **Step 5: Commit**

```bash
git add app/javascript/dashboard/routes/dashboard/conversation/contact
git commit -m "feat: show closed deals and the won total in the contact deals block"
```

---

## Task 23: Contact tab in the deal drawer

**Files:**
- Create: `app/javascript/dashboard/routes/dashboard/crm/components/DealContactTab.vue`
- Create: `app/javascript/dashboard/routes/dashboard/crm/components/specs/DealContactTab.spec.js`
- Modify: `app/javascript/dashboard/routes/dashboard/crm/components/DealDrawer.vue`

**Interfaces:**
- Consumes: the `deal.contact` object already on every serialized deal (`id, name, email, phone_number, thumbnail`)
- Produces: `DealContactTab` props: `contact` (Object, required)

- [ ] **Step 1: Write the failing spec**

Create `components/specs/DealContactTab.spec.js` asserting: name, email and phone render; a contact with no email or phone renders without printing "undefined"; the profile link points at `/app/accounts/:accountId/contacts/:id`.

- [ ] **Step 2: Run and watch it fail**

Expected: FAIL — cannot resolve `../DealContactTab.vue`.

- [ ] **Step 3: Build the tab**

Create `DealContactTab.vue` as a `<script setup>` component taking the `contact` prop and rendering its name, email and phone number — each row omitted when the value is blank — plus a router-link to the contact profile built with `frontendURL` from `dashboard/helper/URLHelper.js` and the `accountId` from `useRoute().params`. Use the existing `CRM.TABS.CONTACT` key for the tab label; do not add new keys for the field rows — reuse whatever generic contact labels the repo already ships (check `en/contact.json`) and say in your report which you used.

- [ ] **Step 4: Add the tab to the drawer**

In `DealDrawer.vue`, extend the tab list from `['details', 'activity']` to `['details', 'activity', 'contact']` and render `<DealContactTab v-if="activeTab === 'contact'" :contact="deal.contact" />`.

- [ ] **Step 5: Run the crm suite and lint**

Expected: green, 0 eslint problems.

- [ ] **Step 6: Commit**

```bash
git add app/javascript/dashboard/routes/dashboard/crm
git commit -m "feat: add a contact tab to the deal drawer"
```

---

## Task 24: Round-2 sweep

**Files:** none

- [ ] **Step 1: Backend suite**

Run: `docker exec -w /app -e RAILS_ENV=test cw-dev-rails-1 bundle exec rspec spec/models/deal_spec.rb spec/models/deal_stage_spec.rb spec/models/deal_activity_spec.rb spec/policies/deal_policy_spec.rb spec/policies/deal_stage_policy_spec.rb spec/controllers/api/v1/accounts/deals_controller_spec.rb spec/controllers/api/v1/accounts/deal_stages_controller_spec.rb spec/controllers/api/v1/accounts/deals`
Expected: 0 failures.

- [ ] **Step 2: Frontend suite**

Run: `export PATH=...:$PATH && TZ=UTC pnpm vitest run`
Expected: 0 failures.

- [ ] **Step 3: Linters**

rubocop on the changed backend files and eslint across the changed frontend files.
Expected: no offenses; 0 eslint errors AND 0 warnings.

- [ ] **Step 4: Production build**

Run: `export PATH=...:$PATH && NODE_OPTIONS=--max-old-space-size=8192 pnpm vite build`
Expected: `✓ built`. This is the only proof the new SFCs compile.

---

## Self-Review

**Spec coverage:** Task 19 closes the value-input defect; 20 the kanban filter bar (spec §Telas 1); 21 the assignee and currency fields (spec §Telas 2); 22 the contact deals list as specced (spec §Telas 4); 23 the drawer Contact tab (spec §Telas 2). Per-column infinite scroll remains deliberately out of scope — the filter bar addresses the same "too many cards" problem with less machinery, and `GET /deals` stays available for it later.

**Placeholder scan:** none — every step names its command and expected result, and every code step carries real code.

**Type consistency:** `centsToUnits`/`unitsToCents` are defined in Task 19 and consumed in Tasks 19 and 22 with the same signatures. `DealFilters` emits `change` with the same key names the board endpoint reads (`assignee_id`, `temperature`, `overdue`, `q`). `stage_type` is read as the string `'open' | 'won' | 'lost'` throughout, matching the jbuilder partial.
