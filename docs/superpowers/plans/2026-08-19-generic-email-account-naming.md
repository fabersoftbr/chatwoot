# Generic Email Account Naming — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop Chatwoot from naming accounts after free mailbox providers ("Gmail", "Outlook") at every entry point, and cover the change with tests.

**Architecture:** One shared predicate (`EmailHelper#generic_email_domain?`) decides what a generic domain is. Every place that derives an account name or fetches brand data from an email consults it: the signup form, the Google OAuth callback, the branding service (OSS and its Enterprise overlay). `AccountBuilder` falls back to the user's name so a deliberately-blank account name still satisfies `accounts.name`, which is `NOT NULL` and presence-validated.

**Tech Stack:** Rails 7 / RSpec / Vue 3 Composition API / Vitest

**Spec:** `docs/superpowers/specs/2026-08-19-generic-email-account-naming-design.md`

## Global Constraints

- Ruby lint: `bundle exec rubocop -a`, max line length 150.
- JS lint: `pnpm eslint:fix`.
- Conventional Commits: `type(scope): subject`.
- **Do not reference Claude in commit messages** (project CLAUDE.md).
- Specs: no custom helper methods for setup; prefer `let` and direct per-example setup.
- Specs: prefer `with_modified_env` over stubbing `ENV`.
- Branch is `fix/generic-email-account-name`, PR #9 against `main`. Do not commit to `main`.
- **No Ruby toolchain on this machine** (no rbenv; `/usr/bin/ruby` is 2.6; bundler 2.5.16 missing). Every `bundle exec rspec` step below will fail to run locally until someone runs `rbenv install $(cat .ruby-version) && bundle install`. If it cannot be installed, say so plainly and mark the step unverified rather than claiming it passed.

## Already Implemented

Commits `2639584ad` and `c4b1bceee` on the branch already contain, untested:

- `app/helpers/email_helper.rb` — `GENERIC_EMAIL_DOMAINS` + `generic_email_domain?`
- `app/javascript/v3/helpers/AuthHelper.js` + its spec (passing, 9/9)
- `app/services/website_branding_service.rb` — `return nil if generic_email_domain?(@email)`
- `app/controllers/devise_overrides/omniauth_callbacks_controller.rb` — `account_name_from_email`
- `app/builders/account_builder.rb` — `@account_name.presence || user_full_name`
- `app/javascript/dashboard/routes/dashboard/onboarding/Index.vue` + `en/onboarding.json`

Tasks 1, 2, 4 and 5 write the missing tests for that code. Because the implementation
already exists, the usual red-green order is inverted: write the test, watch it pass,
then **deliberately break the implementation and re-run to confirm the test actually
catches the regression**, then restore. A test that passes against both the fixed and
the broken implementation is worthless.

## File Structure

| File | Responsibility | Task |
|---|---|---|
| `spec/helpers/email_helper_spec.rb` | modify — cover the shared predicate | 1 |
| `spec/services/website_branding_service_spec.rb` | modify — OSS guard skips the fetch | 2 |
| `enterprise/app/services/enterprise/website_branding_service.rb` | modify — same guard in the overlay | 3 |
| `spec/enterprise/services/enterprise/website_branding_service_spec.rb` | modify — overlay skips Context.dev | 3 |
| `spec/builders/account_builder_spec.rb` | modify — blank name falls back to user name | 4 |
| `spec/controllers/devise/omniauth_callbacks_controller_spec.rb` | modify — OAuth leaves the name blank | 5 |
| `app/controllers/api/v2/accounts_controller.rb` | modify — forward the name params | 6 |
| `spec/controllers/api/v2/accounts_controller_spec.rb` | modify — argument matcher + real builder | 6 |

Task order matters only for 3 and 6, where the implementation must land with its test.
The rest are independent and can be reviewed separately.

---

### Task 1: Cover the shared predicate

`EmailHelper#generic_email_domain?` is the single decision point every other task leans on. It exists but has no test.

**Files:**
- Modify: `app/helpers/email_helper.rb` (only if a test exposes a bug)
- Test: `spec/helpers/email_helper_spec.rb`

**Interfaces:**
- Consumes: nothing.
- Produces: `EmailHelper#generic_email_domain?(email) -> Boolean`. Included by `WebsiteBrandingService` and `DeviseOverrides::OmniauthCallbacksController`. Tasks 2 and 3 rely on it returning `true` for `'user@gmail.com'`.

- [ ] **Step 1: Write the test**

Add this `describe` block inside the existing `describe EmailHelper do` in `spec/helpers/email_helper_spec.rb`, after the `#normalize_email_with_plus_addressing` block. The existing file uses RSpec's `helper` object for a helper module — keep that.

```ruby
  describe '#generic_email_domain?' do
    it 'returns true for free mailbox providers' do
      expect(helper.generic_email_domain?('john@gmail.com')).to be(true)
      expect(helper.generic_email_domain?('john@hotmail.com.br')).to be(true)
      expect(helper.generic_email_domain?('john@proton.me')).to be(true)
    end

    it 'returns false for company domains' do
      expect(helper.generic_email_domain?('john@acme.com')).to be(false)
      expect(helper.generic_email_domain?('john@stripe.com')).to be(false)
    end

    it 'ignores case and surrounding whitespace' do
      expect(helper.generic_email_domain?('john@GMAIL.com')).to be(true)
      expect(helper.generic_email_domain?('john@Hotmail.com.BR ')).to be(true)
    end

    it 'does not match a company domain that merely ends with a provider domain' do
      expect(helper.generic_email_domain?('john@notgmail.com')).to be(false)
      expect(helper.generic_email_domain?('john@mail.gmail.com')).to be(false)
    end

    it 'returns false when the address has no domain' do
      expect(helper.generic_email_domain?('')).to be(false)
      expect(helper.generic_email_domain?(nil)).to be(false)
    end
  end
```

- [ ] **Step 2: Run the test**

Run: `bundle exec rspec spec/helpers/email_helper_spec.rb`
Expected: PASS. The implementation already exists.

If it fails on the `nil` example, `generic_email_domain?` is missing its `to_s` guard — the implementation should read `email.to_s.split('@').last&.downcase&.strip`.

- [ ] **Step 3: Prove the test can fail**

Temporarily change `app/helpers/email_helper.rb` so the predicate always returns `false`:

```ruby
  def generic_email_domain?(email)
    false
  end
```

Run: `bundle exec rspec spec/helpers/email_helper_spec.rb`
Expected: FAIL on the first two examples.

Then `git checkout app/helpers/email_helper.rb` to restore.

- [ ] **Step 4: Lint**

Run: `bundle exec rubocop -a spec/helpers/email_helper_spec.rb`
Expected: no offenses.

- [ ] **Step 5: Commit**

```bash
git add spec/helpers/email_helper_spec.rb
git commit -m "test(email_helper): cover generic email domain predicate"
```

---

### Task 2: Prove the OSS branding service makes no request for generic domains

The guard already returns `nil`. The test must assert the *absence of the HTTP request*, not just the nil — a `nil` return could also come from a failed fetch, so asserting only the return value would pass against a broken guard.

**Files:**
- Test: `spec/services/website_branding_service_spec.rb`

**Interfaces:**
- Consumes: `EmailHelper#generic_email_domain?` from Task 1.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Write the test**

Add this context inside the existing `describe '#perform' do` block in `spec/services/website_branding_service_spec.rb`. Note the surrounding `before` block already stubs `https://example.com`; this context uses a different email so that stub is irrelevant.

```ruby
    context 'when the email is from a free mailbox provider' do
      let(:email) { 'someone@gmail.com' }

      it 'returns nil without fetching the provider homepage' do
        request = stub_request(:get, 'https://gmail.com')

        expect(described_class.new(email).perform).to be_nil
        expect(request).not_to have_been_requested
      end

      it 'skips the fetch regardless of the domain casing' do
        request = stub_request(:get, 'https://hotmail.com.br')

        expect(described_class.new('someone@HOTMAIL.COM.BR').perform).to be_nil
        expect(request).not_to have_been_requested
      end
    end
```

- [ ] **Step 2: Run the test**

Run: `bundle exec rspec spec/services/website_branding_service_spec.rb`
Expected: PASS, including the pre-existing examples.

- [ ] **Step 3: Prove the test can fail**

Temporarily comment out the guard line in `app/services/website_branding_service.rb`:

```ruby
  def perform
    # return nil if generic_email_domain?(@email)

    doc = fetch_page
```

Run: `bundle exec rspec spec/services/website_branding_service_spec.rb`
Expected: FAIL — `expected no requests to have been made, but 1 was`.

Then `git checkout app/services/website_branding_service.rb` to restore.

- [ ] **Step 4: Lint**

Run: `bundle exec rubocop -a spec/services/website_branding_service_spec.rb`
Expected: no offenses.

- [ ] **Step 5: Commit**

```bash
git add spec/services/website_branding_service_spec.rb
git commit -m "test(branding): assert generic domains skip the homepage fetch"
```

---

### Task 3: Guard the Enterprise overlay

This is the one behavioural gap left. `Enterprise::WebsiteBrandingService#perform` replaces the OSS method wholesale and only calls `super` when Context.dev is disabled — so with `CONTEXT_DEV_API_KEY` set, the OSS guard never runs and a `gmail.com` address is sent to the Context.dev API.

**Files:**
- Modify: `enterprise/app/services/enterprise/website_branding_service.rb:4-12`
- Test: `spec/enterprise/services/enterprise/website_branding_service_spec.rb`

**Interfaces:**
- Consumes: `EmailHelper#generic_email_domain?` from Task 1. It is available because the overlay is prepended onto `WebsiteBrandingService`, which does `include EmailHelper`.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Write the failing test**

Add this context inside the existing `describe '#perform' do` block in `spec/enterprise/services/enterprise/website_branding_service_spec.rb`. The existing spec builds `test_klass` by prepending the overlay onto `WebsiteBrandingService`; reuse it via a local subject because the outer `subject` is bound to the outer `email`.

```ruby
    context 'when the email is from a free mailbox provider' do
      let(:generic_email) { 'someone@gmail.com' }

      before do
        create(:installation_config, name: 'CONTEXT_DEV_API_KEY', value: api_key)
      end

      it 'returns nil without calling context.dev' do
        request = stub_request(:get, endpoint).with(query: { email: generic_email })

        expect(test_klass.new(generic_email).perform).to be_nil
        expect(request).not_to have_been_requested
      end

      it 'does not fall back to scraping the provider homepage either' do
        request = stub_request(:get, 'https://gmail.com')

        expect(test_klass.new(generic_email).perform).to be_nil
        expect(request).not_to have_been_requested
      end
    end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bundle exec rspec spec/enterprise/services/enterprise/website_branding_service_spec.rb`
Expected: FAIL on the first example — `expected no requests to have been made, but 1 was`, because the overlay currently calls Context.dev unconditionally.

- [ ] **Step 3: Write the implementation**

In `enterprise/app/services/enterprise/website_branding_service.rb`, add the guard as the first line of `perform`:

```ruby
  def perform
    # The overlay replaces the OSS #perform entirely, so the guard there does not
    # protect this path — a free mailbox domain would be sent to Context.dev and
    # come back branded as Gmail/Outlook.
    return nil if generic_email_domain?(@email)
    return super unless context_dev_enabled?

    response = fetch_brand
    process_response(response)
  rescue StandardError => e
    Rails.logger.error "[WebsiteBranding] Context.dev failed: #{e.message}"
    nil
  end
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bundle exec rspec spec/enterprise/services/enterprise/website_branding_service_spec.rb`
Expected: PASS, including the pre-existing examples (they use `user@example.com`, which is not generic, so they are unaffected).

- [ ] **Step 5: Lint**

Run: `bundle exec rubocop -a enterprise/app/services/enterprise/website_branding_service.rb spec/enterprise/services/enterprise/website_branding_service_spec.rb`
Expected: no offenses.

- [ ] **Step 6: Commit**

```bash
git add enterprise/app/services/enterprise/website_branding_service.rb spec/enterprise/services/enterprise/website_branding_service_spec.rb
git commit -m "fix(enterprise): skip context.dev enrichment for generic email domains"
```

---

### Task 4: Cover the AccountBuilder name fallback

`AccountBuilder#account_name` now returns `@account_name.presence || user_full_name`. Without a test, nothing stops someone restoring `@account_name || ''` and bringing back "Name can't be blank" at signup.

**Files:**
- Test: `spec/builders/account_builder_spec.rb`

**Interfaces:**
- Consumes: nothing.
- Produces: nothing consumed by later tasks. Task 5 exercises the same fallback through the v2 controller.

- [ ] **Step 1: Write the test**

Add this context inside the existing `describe '#perform' do` block in `spec/builders/account_builder_spec.rb`. The file's outer `before` stubs `Account::SignUpEmailValidationService` for `email`, so these examples inherit it. Build a local builder rather than reusing the outer `account_builder`, whose `account_name` is `'Test Account'`.

```ruby
    context 'when account_name is blank' do
      it 'falls back to the user full name' do
        _user, account = described_class.new(
          account_name: '',
          email: email,
          user_full_name: user_full_name,
          user_password: user_password,
          confirmed: true
        ).perform

        expect(account.name).to eq(user_full_name)
      end

      it 'falls back to the user full name when account_name is nil' do
        _user, account = described_class.new(
          account_name: nil,
          email: email,
          user_full_name: user_full_name,
          user_password: user_password,
          confirmed: true
        ).perform

        expect(account.name).to eq(user_full_name)
      end

      it 'raises when both names are blank' do
        expect do
          described_class.new(
            account_name: '',
            email: email,
            user_full_name: '',
            user_password: user_password,
            confirmed: true
          ).perform
        end.to raise_error(ActiveRecord::RecordInvalid, /Name can't be blank/)
      end
    end
```

The third example pins current behaviour deliberately: `accounts.name` is `NOT NULL` and presence-validated, so a caller that supplies neither name must fail loudly rather than silently create a nameless account. This is the repo's "let it fail loudly on a setup bug" rule.

- [ ] **Step 2: Run the test**

Run: `bundle exec rspec spec/builders/account_builder_spec.rb`
Expected: PASS, including the pre-existing examples.

- [ ] **Step 3: Prove the test can fail**

Temporarily restore the old implementation in `app/builders/account_builder.rb`:

```ruby
  def account_name
    @account_name || ''
  end
```

Run: `bundle exec rspec spec/builders/account_builder_spec.rb`
Expected: FAIL on the first two examples with `ActiveRecord::RecordInvalid: Validation failed: Name can't be blank`.

Then `git checkout app/builders/account_builder.rb` to restore.

- [ ] **Step 4: Lint**

Run: `bundle exec rubocop -a spec/builders/account_builder_spec.rb`
Expected: no offenses.

- [ ] **Step 5: Commit**

```bash
git add spec/builders/account_builder_spec.rb
git commit -m "test(account_builder): cover blank account name fallback"
```

---

### Task 5: Cover the Google OAuth signup path

`create_account_for_user` now calls `account_name_from_email`, which returns `nil` for a generic domain instead of `extract_domain_without_tld`. Nothing tests it.

Note on reachability: this path is only blocked for Gmail if the installation has
`gmail.com` in the `BLOCKED_EMAIL_DOMAINS` config, which defaults to empty. The existing
"blocks personal accounts signup" examples stub `Account::SignUpEmailValidationService`
and therefore prove only that the controller handles the raise, not that Gmail is
rejected by default. So the new branch is genuinely reachable.

**Files:**
- Test: `spec/controllers/devise/omniauth_callbacks_controller_spec.rb`

**Interfaces:**
- Consumes: `EmailHelper#generic_email_domain?` from Task 1.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Write the test**

Add this example after the existing `it 'allows signup'` example in
`spec/controllers/devise/omniauth_callbacks_controller_spec.rb`. It mirrors that
example's setup — `set_omniauth_config` with a generic address, the builder stubbed —
and asserts the constructor argument. The existing example already asserts
`account_name: 'example'` for `test@example.com`, so this is the negative case.

```ruby
    it 'leaves the account name blank for generic email domains' do
      with_modified_env ENABLE_ACCOUNT_SIGNUP: 'true', FRONTEND_URL: 'http://www.example.com' do
        set_omniauth_config('personal@gmail.com')
        allow(email_validation_service).to receive(:perform).and_return(true)
        allow(AccountBuilder).to receive(:new).and_return(account_builder)
        allow(account_builder).to receive(:perform).and_return(user_double)

        get '/omniauth/google_oauth2/callback'

        expect(AccountBuilder).to have_received(:new).with(hash_including(account_name: nil, user_full_name: 'test'))
      end
    end
```

- [ ] **Step 2: Run the test**

Run: `bundle exec rspec spec/controllers/devise/omniauth_callbacks_controller_spec.rb`
Expected: PASS, including the pre-existing examples — `test@example.com` is not generic, so the `account_name: 'example'` assertion at line 45 is unaffected.

- [ ] **Step 3: Prove the test can fail**

Temporarily revert `app/controllers/devise_overrides/omniauth_callbacks_controller.rb` to derive unconditionally:

```ruby
      account_name: extract_domain_without_tld(auth_hash['info']['email']),
```

Run: `bundle exec rspec spec/controllers/devise/omniauth_callbacks_controller_spec.rb`
Expected: FAIL — the builder receives `account_name: 'gmail'`.

Then `git checkout app/controllers/devise_overrides/omniauth_callbacks_controller.rb` to restore.

- [ ] **Step 4: Lint**

Run: `bundle exec rubocop -a spec/controllers/devise/omniauth_callbacks_controller_spec.rb`
Expected: no offenses.

- [ ] **Step 5: Commit**

```bash
git add spec/controllers/devise/omniauth_callbacks_controller_spec.rb
git commit -m "test(oauth): cover blank account name for generic email domains"
```

---

### Task 6: Make the v2 signup endpoint pass a name

`Api::V2::AccountsController#create` passes neither `account_name` nor `user_full_name` to `AccountBuilder`, so it always reaches `Account.create!(name: '')` and raises. `account_params` already permits both keys, and the route is live at `config/routes.rb:518`.

The existing spec hides this: it stubs `AccountBuilder` entirely, so the real builder never runs. It also asserts the constructor arguments with an exact hash, which this change breaks — that assertion must be updated in the same task.

**Files:**
- Modify: `app/controllers/api/v2/accounts_controller.rb:16-22`
- Test: `spec/controllers/api/v2/accounts_controller_spec.rb`

**Interfaces:**
- Consumes: `AccountBuilder#account_name` fallback from Task 4.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Write the failing test**

Add this context to `spec/controllers/api/v2/accounts_controller_spec.rb`, inside `describe 'POST /api/v2/accounts' do` and after the existing `context 'when posting to accounts with correct parameters'`. Unlike every other example in the file, this one must **not** stub `AccountBuilder` — the whole point is exercising the real one.

```ruby
    context 'when the builder actually runs' do
      it 'creates the account using the user full name when no account name is given' do
        with_modified_env ENABLE_ACCOUNT_SIGNUP: 'true' do
          post api_v2_accounts_url,
               params: { email: email, user_full_name: 'Pedro Kajiya', password: 'Password1!' },
               as: :json

          expect(response).to have_http_status(:success)
          expect(Account.last.name).to eq('Pedro Kajiya')
        end
      end

      it 'prefers an explicit account name over the user full name' do
        with_modified_env ENABLE_ACCOUNT_SIGNUP: 'true' do
          post api_v2_accounts_url,
               params: { email: email, account_name: 'Acme Inc', user_full_name: 'Pedro Kajiya', password: 'Password1!' },
               as: :json

          expect(response).to have_http_status(:success)
          expect(Account.last.name).to eq('Acme Inc')
        end
      end
    end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bundle exec rspec spec/controllers/api/v2/accounts_controller_spec.rb`
Expected: FAIL on both new examples — the controller drops the params, so the builder raises `ActiveRecord::RecordInvalid: Validation failed: Name can't be blank`.

- [ ] **Step 3: Write the implementation**

In `app/controllers/api/v2/accounts_controller.rb`, forward the two name params:

```ruby
  def create
    @user, @account = AccountBuilder.new(
      account_name: account_params[:account_name],
      user_full_name: account_params[:user_full_name],
      email: account_params[:email],
      user_password: account_params[:password],
      locale: account_params[:locale],
      user: current_user
    ).perform
```

- [ ] **Step 4: Update the existing argument assertion**

The first example in the file asserts the constructor arguments exactly:

```ruby
        expect(AccountBuilder).to have_received(:new).with(params.except(:password).merge(user_password: params[:password]))
```

With two new keys this no longer matches. Replace that line with an assertion that names the keys explicitly, so a future change to the argument list is visible rather than silently absorbed:

```ruby
        expect(AccountBuilder).to have_received(:new).with(
          account_name: nil,
          user_full_name: nil,
          email: email,
          user_password: 'Password1!',
          locale: nil,
          user: nil
        )
```

- [ ] **Step 5: Run the whole file to verify it passes**

Run: `bundle exec rspec spec/controllers/api/v2/accounts_controller_spec.rb`
Expected: PASS, all examples.

Also run the Enterprise sibling, which prepends onto this controller and may assert on the same call:

Run: `bundle exec rspec spec/enterprise/controllers/enterprise/api/v2/accounts_controller_spec.rb`
Expected: PASS. If it fails on an argument matcher, update it the same way as Step 4.

- [ ] **Step 6: Lint**

Run: `bundle exec rubocop -a app/controllers/api/v2/accounts_controller.rb spec/controllers/api/v2/accounts_controller_spec.rb`
Expected: no offenses.

- [ ] **Step 7: Commit**

```bash
git add app/controllers/api/v2/accounts_controller.rb spec/controllers/api/v2/accounts_controller_spec.rb
git commit -m "fix(api): forward account and user names from v2 signup"
```

---

### Task 7: Full suite and PR update

**Files:**
- Modify: none (PR description only)

**Interfaces:**
- Consumes: everything above.
- Produces: nothing.

- [ ] **Step 1: Run every touched spec**

```bash
bundle exec rspec \
  spec/helpers/email_helper_spec.rb \
  spec/services/website_branding_service_spec.rb \
  spec/enterprise/services/enterprise/website_branding_service_spec.rb \
  spec/builders/account_builder_spec.rb \
  spec/controllers/api/v2/accounts_controller_spec.rb \
  spec/controllers/api/v1/accounts_controller_spec.rb
```

Expected: all green. `spec/controllers/api/v1/accounts_controller_spec.rb` is included because `ensure_account_name` and the enrichment enqueue live there and were reasoned about, even though no file in it changed.

- [ ] **Step 2: Run the JS suite for the touched areas**

```bash
npx vitest run \
  app/javascript/v3/helpers/specs/AuthHelper.spec.js \
  app/javascript/dashboard/routes/dashboard/onboarding/specs
```

Expected: all green. The onboarding specs cover `useAccountEnrichment` and `useDetectedChannels`; the `Index.vue` change (ref + InlineInput) has no spec of its own, so watch for a snapshot or mount failure here.

- [ ] **Step 3: Lint everything**

```bash
bundle exec rubocop -a
pnpm eslint:fix
```

Expected: rubocop clean; eslint 0 errors (the repo has ~414 pre-existing warnings — warnings are fine, errors are not).

- [ ] **Step 4: Push**

```bash
git push origin fix/generic-email-account-name
```

- [ ] **Step 5: Update the PR description**

PR #9 currently describes only the first commit. Rewrite the body to cover the whole change: the four entry points, the `AccountBuilder` contract fix, the Enterprise overlay, and the v2 endpoint. State explicitly what is out of scope — no backfill of accounts already named "Gmail"/"Outlook", no signup-screen domain validation, no portal slug changes.

Write the body to a scratch file first, then:

```bash
gh pr edit 9 --repo fabersoftbr/chatwoot --body-file /tmp/pr9-body.md
```

`gh` resolves the default repo to `upstream` (chatwoot/chatwoot) in this checkout, which
is why `--repo fabersoftbr/chatwoot` is required — without it the command fails with
"No commits between main and ...".
