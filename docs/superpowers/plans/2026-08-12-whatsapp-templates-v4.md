# WhatsApp Template Creation (v4.16.2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let an administrator create and delete WhatsApp message templates from the inbox settings, instead of leaving Chatwoot for Meta's Business Manager.

**Architecture:** Pure passthrough. Chatwoot persists no template of its own — the source of truth stays the `channel_whatsapp.message_templates` jsonb column, which `sync_templates` already fills from Meta. Creation POSTs to the same `{business_account_path}/message_templates` endpoint that `sync_templates` reads from, then re-runs `sync_templates` inline so the response already carries the new `PENDING` template. No migration, no second store, no drift.

**Tech Stack:** Ruby 3.4.4, Rails 7.1, RSpec + WebMock (no VCR); Vue 3 Options API (this corner of the codebase is Options API, not `<script setup>`), Vuex, vue-i18n, Vitest, `@vue/test-utils`.

**Source design:** `docs/superpowers/specs/2026-08-11-whatsapp-template-creation-design.md` (approved). This plan supersedes the older `2026-08-11-whatsapp-template-creation.md` plan, which was written against Chatwoot 3.14 and is wrong in three ways: it pins Graph API `v20.0` (expires 2026-09-24), it assumes template creation must be written from scratch (it must not — see Global Constraints), and its route shape does not match v4.

## Global Constraints

- Work happens on branch `main` in `/Users/fabersoft03/Documents/GitHub/chatwoot-v4`. Never commit to `develop`.
- Backend commands run in the container `cw-v4-rails-1`, repo mounted at `/app`:
  `docker exec -w /app -e RAILS_ENV=test cw-v4-rails-1 bundle exec <cmd>`
- **Before the first backend command of a task**, run `docker exec -w /app cw-v4-rails-1 bundle lock --add-platform aarch64-linux`. The container is ARM and the committed `Gemfile.lock` has no ARM platform line, so bundler fails without it. **`Gemfile.lock` must NOT be committed** — run `git checkout -- Gemfile.lock` before every `git commit`. It is a local-container concession, not a source change.
- Frontend commands run on the host from the repo root: `TZ=UTC pnpm vitest run <paths>`.
- **Do not invent an API version constant.** `business_account_path` already reads `GlobalConfigService.load('WHATSAPP_API_VERSION', 'v22.0')` (`app/services/whatsapp/providers/whatsapp_cloud_service.rb:121`). Template creation requires Graph API v16.0 or newer; the shared default satisfies it. Every new Graph call goes through `business_account_path`.
- **Do not write template-creation HTTP from scratch.** `Whatsapp::CsatTemplateService#send_template_creation_request` (`app/services/whatsapp/csat_template_service.rb:98`) already POSTs `{name, language, category, components}` to `{business_account_path}/message_templates` and works in production. New provider methods mirror its HTTP shape. Do NOT modify `CsatTemplateService` itself — CSAT template creation is live and must not regress.
- **Do not use `process_response`** (`base_service.rb:34`) for template calls. It expects a `message` record and returns `nil` on failure after logging, which would swallow the Meta error text the user needs to see.
- Cloud provider only. `Whatsapp360DialogService` uses a different API (`/configs/templates`, `D360-API-KEY`); the controller rejects non-`whatsapp_cloud` channels with 422.
- **Authorization is administrator-level.** Use `authorize @inbox, :update?` (`InboxPolicy#update?`, `app/policies/inbox_policy.rb:45`, which requires `administrator?`). Do NOT copy `InboxCsatTemplatesController`'s `authorize @inbox, :show?` — that is agent-level, and an agent must not be able to create or delete templates on the account's Meta WABA.
- New user-facing strings live in `en` and `pt_BR` only.
- There are 18 pre-existing spec failures in this tree (12 in `spec/services/whatsapp/incoming_message_service_spec.rb`, 6 in `spec/enterprise/models/inbox_spec.rb`). They fail on `main` without any of this work. Do not try to fix them; do not count them as your breakage. Verify against them by running the specs this plan names, not the whole suite.

## File Structure

**Create:**
- `app/services/whatsapp/template_builder.rb` — pure params → Meta payload, all validation
- `app/controllers/api/v1/accounts/inboxes/whatsapp_templates_controller.rb` — create + destroy
- `spec/services/whatsapp/template_builder_spec.rb`
- `spec/controllers/api/v1/accounts/inboxes/whatsapp_templates_controller_spec.rb`
- `app/javascript/dashboard/api/channel/whatsappTemplates.js` — API client
- `app/javascript/dashboard/routes/dashboard/settings/inbox/settingsPage/WhatsappTemplatesPage.vue` — list + delete
- `app/javascript/dashboard/routes/dashboard/settings/inbox/components/WhatsappTemplateForm.vue` — creation form
- specs for both components under `.../specs/`
- `app/javascript/dashboard/i18n/locale/{en,pt_BR}/whatsappTemplates.json`

**Modify:**
- `app/services/whatsapp/providers/base_service.rb` — two abstract stubs
- `app/services/whatsapp/providers/whatsapp_cloud_service.rb` — `create_template`, `delete_template`
- `app/models/channel/whatsapp.rb:123` — extend the existing `delegate`
- `config/routes.rb` — nested resource in the `resources :inboxes` member block
- `app/javascript/dashboard/routes/dashboard/settings/inbox/Settings.vue` — tab + page
- `app/javascript/dashboard/i18n/locale/{en,pt_BR}/inboxMgmt.json` — tab label
- `app/javascript/dashboard/i18n/locale/{en,pt_BR}/index.js` — register the new json

---

## Task 1: `Whatsapp::TemplateBuilder`

The only genuinely new logic in this feature. Pure Ruby, no HTTP, no Rails — so it is testable in isolation and every rejection path is cheap to cover.

**Files:**
- Create: `app/services/whatsapp/template_builder.rb`
- Test: `spec/services/whatsapp/template_builder_spec.rb`

**Interfaces:**
- Produces: `Whatsapp::TemplateBuilder.new(name:, language:, category:, body:, examples: []).build` → returns the Meta payload Hash. Raises `Whatsapp::TemplateBuilder::InvalidTemplateError` with a human-readable message on any validation failure. Task 3's controller rescues that error class and renders 422.

- [ ] **Step 1: Write the failing test**

Create `spec/services/whatsapp/template_builder_spec.rb`:

```ruby
require 'rails_helper'

describe Whatsapp::TemplateBuilder do
  def build(overrides = {})
    described_class.new(**{ name: 'boas_vindas', language: 'pt_BR', category: 'UTILITY',
                            body: 'Olá, tudo bem?', examples: [] }.merge(overrides)).build
  end

  describe '#build' do
    it 'builds a payload with a BODY component when there are no variables' do
      expect(build).to eq(
        name: 'boas_vindas',
        language: 'pt_BR',
        category: 'UTILITY',
        components: [{ type: 'BODY', text: 'Olá, tudo bem?' }]
      )
    end

    it 'attaches example.body_text when the body has variables' do
      payload = build(body: 'Olá {{1}}, pedido {{2}} enviado.', examples: %w[Pedro 1234])

      expect(payload[:components]).to eq(
        [{ type: 'BODY',
           text: 'Olá {{1}}, pedido {{2}} enviado.',
           example: { body_text: [%w[Pedro 1234]] } }]
      )
    end

    it 'accepts a variable used more than once, counting it once' do
      payload = build(body: 'Oi {{1}}, confirma {{1}}?', examples: ['Ana'])

      expect(payload[:components].first[:example]).to eq(body_text: [['Ana']])
    end

    it 'rejects a variable sequence with a hole' do
      expect { build(body: 'Oi {{1}} e {{3}}', examples: %w[a b]) }
        .to raise_error(described_class::InvalidTemplateError, /sequence/i)
    end

    it 'rejects a sequence that does not start at 1' do
      expect { build(body: 'Oi {{2}}', examples: ['a']) }
        .to raise_error(described_class::InvalidTemplateError, /sequence/i)
    end

    it 'rejects when the example count does not match the variable count' do
      expect { build(body: 'Oi {{1}} e {{2}}', examples: ['só um']) }
        .to raise_error(described_class::InvalidTemplateError, /example/i)
    end

    it 'rejects a blank example' do
      expect { build(body: 'Oi {{1}}', examples: ['  ']) }
        .to raise_error(described_class::InvalidTemplateError, /example/i)
    end

    it 'rejects a name that is not lowercase alphanumeric or underscore' do
      expect { build(name: 'Boas Vindas') }
        .to raise_error(described_class::InvalidTemplateError, /name/i)
    end

    it 'rejects a name longer than 512 characters' do
      expect { build(name: "a#{'b' * 512}") }
        .to raise_error(described_class::InvalidTemplateError, /name/i)
    end

    it 'rejects a category Meta does not accept' do
      expect { build(category: 'PROMOTIONAL') }
        .to raise_error(described_class::InvalidTemplateError, /category/i)
    end

    it 'rejects a blank body' do
      expect { build(body: '   ') }
        .to raise_error(described_class::InvalidTemplateError, /body/i)
    end

    it 'rejects a blank language' do
      expect { build(language: '') }
        .to raise_error(described_class::InvalidTemplateError, /language/i)
    end
  end
end
```

- [ ] **Step 2: Run the test and watch it fail**

```bash
docker exec -w /app cw-v4-rails-1 bundle lock --add-platform aarch64-linux
docker exec -w /app -e RAILS_ENV=test cw-v4-rails-1 bundle exec rspec spec/services/whatsapp/template_builder_spec.rb
```

Expected: FAIL — `uninitialized constant Whatsapp::TemplateBuilder`.

- [ ] **Step 3: Write the implementation**

Create `app/services/whatsapp/template_builder.rb`:

```ruby
# Turns the flat params the dashboard sends into the `components` payload Meta's
# Graph API expects, and rejects everything Meta would reject — a rejected
# template costs the user a round trip through Meta's review queue, so it is
# cheaper to refuse it here with a readable reason.
class Whatsapp::TemplateBuilder
  InvalidTemplateError = Class.new(StandardError)

  CATEGORIES = %w[UTILITY MARKETING AUTHENTICATION].freeze
  NAME_FORMAT = /\A[a-z0-9_]+\z/
  NAME_MAX_LENGTH = 512
  VARIABLE_PATTERN = /\{\{(\d+)\}\}/

  def initialize(name:, language:, category:, body:, examples: [])
    @name = name.to_s.strip
    @language = language.to_s.strip
    @category = category.to_s.strip.upcase
    @body = body.to_s
    @examples = Array(examples).map(&:to_s)
  end

  def build
    validate_name!
    validate_language!
    validate_category!
    validate_body!
    validate_variables!

    { name: @name, language: @language, category: @category, components: [body_component] }
  end

  private

  # Ordered, de-duplicated variable indexes: "{{1}} e {{1}} e {{2}}" -> [1, 2]
  def variable_indexes
    @variable_indexes ||= @body.scan(VARIABLE_PATTERN).flatten.map(&:to_i).uniq.sort
  end

  def validate_name!
    raise InvalidTemplateError, 'Template name is required' if @name.blank?
    raise InvalidTemplateError, "Template name must be #{NAME_MAX_LENGTH} characters or fewer" if @name.length > NAME_MAX_LENGTH
    return if @name.match?(NAME_FORMAT)

    raise InvalidTemplateError, 'Template name may only contain lowercase letters, numbers and underscores'
  end

  def validate_language!
    raise InvalidTemplateError, 'Template language is required' if @language.blank?
  end

  def validate_category!
    return if CATEGORIES.include?(@category)

    raise InvalidTemplateError, "Template category must be one of: #{CATEGORIES.join(', ')}"
  end

  def validate_body!
    raise InvalidTemplateError, 'Template body is required' if @body.strip.blank?
  end

  def validate_variables!
    return if variable_indexes.empty? && @examples.empty?

    # Meta requires {{1}}..{{n}} with no gaps; a hole makes the template unusable.
    unless variable_indexes == (1..variable_indexes.length).to_a
      raise InvalidTemplateError, 'Template variables must form the sequence {{1}}, {{2}}, ... with no gaps'
    end

    if @examples.length != variable_indexes.length
      raise InvalidTemplateError, "Expected #{variable_indexes.length} example value(s), got #{@examples.length}"
    end

    return if @examples.none? { |example| example.strip.blank? }

    raise InvalidTemplateError, 'Every variable needs a non-blank example value'
  end

  def body_component
    component = { type: 'BODY', text: @body }
    component[:example] = { body_text: [@examples] } if variable_indexes.any?
    component
  end
end
```

- [ ] **Step 4: Run the test and watch it pass**

```bash
docker exec -w /app -e RAILS_ENV=test cw-v4-rails-1 bundle exec rspec spec/services/whatsapp/template_builder_spec.rb
```

Expected: PASS, 12 examples, 0 failures.

- [ ] **Step 5: Rubocop and commit**

```bash
docker exec -w /app cw-v4-rails-1 bundle exec rubocop app/services/whatsapp/template_builder.rb spec/services/whatsapp/template_builder_spec.rb -a
git checkout -- Gemfile.lock
git add app/services/whatsapp/template_builder.rb spec/services/whatsapp/template_builder_spec.rb
git commit -m "feat: add a WhatsApp template payload builder"
```

---

## Task 2: Provider methods

**Files:**
- Modify: `app/services/whatsapp/providers/base_service.rb` (add two stubs beside the existing ones at `:14-32`)
- Modify: `app/services/whatsapp/providers/whatsapp_cloud_service.rb` (add two public methods near `create_csat_template` at `:79`)
- Modify: `app/models/channel/whatsapp.rb:123` (extend the existing `delegate`)
- Test: `spec/services/whatsapp/providers/whatsapp_cloud_service_spec.rb` (append a describe block)

**Interfaces:**
- Consumes: nothing from Task 1 — the payload arrives already built.
- Produces:
  - `WhatsappCloudService#create_template(payload)` → `{ success: Boolean, body: Hash|String }`
  - `WhatsappCloudService#delete_template(name)` → `{ success: Boolean, body: Hash|String }`
  - Both reachable as `channel.create_template(...)` / `channel.delete_template(...)` via the model delegate. Task 3's controller calls the model, not the service.

- [ ] **Step 1: Write the failing test**

Append to `spec/services/whatsapp/providers/whatsapp_cloud_service_spec.rb`, inside the outer `describe`:

```ruby
  describe '#create_template' do
    let(:payload) do
      { name: 'boas_vindas', language: 'pt_BR', category: 'UTILITY',
        components: [{ type: 'BODY', text: 'Olá' }] }
    end

    it 'posts the payload to the business account templates endpoint and reports success' do
      stub_request(:post, 'https://graph.facebook.com/v22.0/123456789/message_templates')
        .with(body: payload.to_json,
              headers: { 'Authorization' => 'Bearer test_key', 'Content-Type' => 'application/json' })
        .to_return(status: 200, body: { id: '999', status: 'PENDING' }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      result = service.create_template(payload)

      expect(result[:success]).to be(true)
      expect(result[:body]['id']).to eq('999')
    end

    it 'surfaces the Meta error body verbatim instead of swallowing it' do
      stub_request(:post, 'https://graph.facebook.com/v22.0/123456789/message_templates')
        .to_return(status: 400,
                   body: { error: { message: 'Template name already exists', code: 100 } }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      result = service.create_template(payload)

      expect(result[:success]).to be(false)
      expect(result[:body].dig('error', 'message')).to eq('Template name already exists')
    end
  end

  describe '#delete_template' do
    it 'deletes by name and reports success' do
      stub_request(:delete, 'https://graph.facebook.com/v22.0/123456789/message_templates?name=boas_vindas')
        .with(headers: { 'Authorization' => 'Bearer test_key' })
        .to_return(status: 200, body: { success: true }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      expect(service.delete_template('boas_vindas')[:success]).to be(true)
    end

    it 'escapes the template name in the query string' do
      stub_request(:delete, 'https://graph.facebook.com/v22.0/123456789/message_templates?name=a%20b')
        .to_return(status: 200, body: {}.to_json, headers: { 'Content-Type' => 'application/json' })

      service.delete_template('a b')

      expect(WebMock).to have_requested(:delete, 'https://graph.facebook.com/v22.0/123456789/message_templates?name=a%20b')
    end
  end
```

Note: `service` and the `whatsapp_channel` factory already exist at the top of that spec file — read it before appending and reuse them rather than redefining. The factory sets `api_key: 'test_key'` and `business_account_id: '123456789'`, which is why the stub URLs read that way.

- [ ] **Step 2: Run the test and watch it fail**

```bash
docker exec -w /app cw-v4-rails-1 bundle lock --add-platform aarch64-linux
docker exec -w /app -e RAILS_ENV=test cw-v4-rails-1 bundle exec rspec spec/services/whatsapp/providers/whatsapp_cloud_service_spec.rb -e create_template -e delete_template
```

Expected: FAIL — `undefined method 'create_template'`.

- [ ] **Step 3: Add the abstract stubs to the base service**

In `app/services/whatsapp/providers/base_service.rb`, after `send_template` (`:18`):

```ruby
  def create_template(_payload)
    raise 'Overwrite this method in child class'
  end

  def delete_template(_name)
    raise 'Overwrite this method in child class'
  end
```

- [ ] **Step 4: Implement in the cloud service**

In `app/services/whatsapp/providers/whatsapp_cloud_service.rb`, after `get_template_status` (`:88-90`):

```ruby
  # Deliberately not routed through `process_response`: that helper is for
  # message sends and returns nil after logging, which would hide the Meta
  # error text the dashboard needs to show verbatim.
  def create_template(payload)
    response = HTTParty.post("#{business_account_path}/message_templates", headers: api_headers, body: payload.to_json)
    template_response(response)
  end

  def delete_template(name)
    response = HTTParty.delete("#{business_account_path}/message_templates?name=#{CGI.escape(name)}", headers: api_headers)
    template_response(response)
  end
```

and in the `private` section:

```ruby
  def template_response(response)
    { success: response.success?, body: response.parsed_response }
  end
```

If rubocop reports `Metrics/ClassLength` on this file, do NOT add a `rubocop:disable`. Move `create_template`, `delete_template` and `template_response` into a small module — `app/services/whatsapp/providers/concerns/template_management.rb` — and `include` it. Report that you did so.

- [ ] **Step 5: Delegate from the channel model**

In `app/models/channel/whatsapp.rb:123`, extend the existing delegate line:

```ruby
  delegate :sync_templates, :create_template, :delete_template, to: :provider_service
```

- [ ] **Step 6: Run the test and watch it pass**

```bash
docker exec -w /app -e RAILS_ENV=test cw-v4-rails-1 bundle exec rspec spec/services/whatsapp/providers/ spec/models/channel/whatsapp_spec.rb
```

Expected: PASS.

- [ ] **Step 7: Rubocop and commit**

```bash
docker exec -w /app cw-v4-rails-1 bundle exec rubocop app/services/whatsapp/providers app/models/channel/whatsapp.rb -a
git checkout -- Gemfile.lock
git add app/services/whatsapp/providers app/models/channel/whatsapp.rb spec/services/whatsapp/providers
git commit -m "feat: add WhatsApp template create and delete to the cloud provider"
```

---

## Task 3: Controller and routes

**Files:**
- Create: `app/controllers/api/v1/accounts/inboxes/whatsapp_templates_controller.rb`
- Modify: `config/routes.rb` (inside the `resources :inboxes` member block that ends at the `resource :csat_template` line — read it first, it is around `:289-311`)
- Test: `spec/controllers/api/v1/accounts/inboxes/whatsapp_templates_controller_spec.rb`

**Interfaces:**
- Consumes: `Whatsapp::TemplateBuilder` (Task 1), `channel.create_template` / `channel.delete_template` (Task 2).
- Produces: `POST /api/v1/accounts/:account_id/inboxes/:inbox_id/whatsapp_templates` and `DELETE /api/v1/accounts/:account_id/inboxes/:inbox_id/whatsapp_templates/:name`. Both return `{ message_templates: [...] }` on success — the refreshed list Task 5's page renders.

- [ ] **Step 1: Add the routes**

In `config/routes.rb`, immediately after the `resource :csat_template ... end` block and still inside `resources :inboxes do`:

```ruby
            resources :whatsapp_templates, only: [:create, :destroy], param: :name, module: :inboxes
```

`param: :name` makes the destroy segment `params[:name]` — Meta deletes templates by name, not by id, and names match `\A[a-z0-9_]+\z` so they are URL-safe.

- [ ] **Step 2: Write the failing test**

Create `spec/controllers/api/v1/accounts/inboxes/whatsapp_templates_controller_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe 'WhatsApp Templates API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:whatsapp_channel) do
    create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud',
                              validate_provider_config: false, sync_templates: false)
  end
  let(:inbox) { whatsapp_channel.inbox }
  let(:valid_params) do
    { name: 'boas_vindas', language: 'pt_BR', category: 'UTILITY',
      body: 'Olá {{1}}', examples: ['Pedro'] }
  end

  describe 'POST /api/v1/accounts/{account.id}/inboxes/{inbox.id}/whatsapp_templates' do
    context 'when unauthenticated' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/whatsapp_templates", params: valid_params
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when the user is an agent' do
      it 'returns forbidden — templates are an administrator action' do
        post "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/whatsapp_templates",
             params: valid_params, headers: agent.create_new_auth_token

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when the user is an administrator' do
      it 'creates the template and returns the refreshed list' do
        allow_any_instance_of(Channel::Whatsapp).to receive(:create_template)
          .and_return({ success: true, body: { 'id' => '999' } })
        allow_any_instance_of(Channel::Whatsapp).to receive(:sync_templates)
        whatsapp_channel.update!(message_templates: [{ 'name' => 'boas_vindas', 'status' => 'PENDING' }])

        post "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/whatsapp_templates",
             params: valid_params, headers: administrator.create_new_auth_token

        expect(response).to have_http_status(:created)
        expect(response.parsed_body['message_templates'].first['name']).to eq('boas_vindas')
      end

      it 'passes the built payload to the channel' do
        expect_any_instance_of(Channel::Whatsapp).to receive(:create_template).with(
          hash_including(name: 'boas_vindas', language: 'pt_BR', category: 'UTILITY')
        ).and_return({ success: true, body: {} })
        allow_any_instance_of(Channel::Whatsapp).to receive(:sync_templates)

        post "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/whatsapp_templates",
             params: valid_params, headers: administrator.create_new_auth_token
      end

      it 'returns 422 with the builder message when the params are invalid' do
        post "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/whatsapp_templates",
             params: valid_params.merge(body: 'Olá {{1}} e {{3}}', examples: %w[a b]),
             headers: administrator.create_new_auth_token

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to match(/sequence/i)
      end

      it 'returns 422 with the Meta error message verbatim' do
        allow_any_instance_of(Channel::Whatsapp).to receive(:create_template).and_return(
          { success: false, body: { 'error' => { 'message' => 'Template name already exists' } } }
        )

        post "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/whatsapp_templates",
             params: valid_params, headers: administrator.create_new_auth_token

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to eq('Template name already exists')
      end

      it 'does not sync templates when creation failed' do
        allow_any_instance_of(Channel::Whatsapp).to receive(:create_template)
          .and_return({ success: false, body: {} })
        expect_any_instance_of(Channel::Whatsapp).not_to receive(:sync_templates)

        post "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/whatsapp_templates",
             params: valid_params, headers: administrator.create_new_auth_token
      end
    end

    context 'when the channel is not WhatsApp Cloud' do
      let(:other_inbox) { create(:channel_twilio_sms, account: account).inbox }

      it 'returns 422' do
        post "/api/v1/accounts/#{account.id}/inboxes/#{other_inbox.id}/whatsapp_templates",
             params: valid_params, headers: administrator.create_new_auth_token

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'DELETE /api/v1/accounts/{account.id}/inboxes/{inbox.id}/whatsapp_templates/{name}' do
    it 'returns forbidden for an agent' do
      delete "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/whatsapp_templates/boas_vindas",
             headers: agent.create_new_auth_token

      expect(response).to have_http_status(:forbidden)
    end

    it 'deletes the template and returns the refreshed list for an administrator' do
      expect_any_instance_of(Channel::Whatsapp).to receive(:delete_template)
        .with('boas_vindas').and_return({ success: true, body: {} })
      allow_any_instance_of(Channel::Whatsapp).to receive(:sync_templates)

      delete "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/whatsapp_templates/boas_vindas",
             headers: administrator.create_new_auth_token

      expect(response).to have_http_status(:ok)
    end

    it 'returns 422 with the Meta error when deletion fails' do
      allow_any_instance_of(Channel::Whatsapp).to receive(:delete_template).and_return(
        { success: false, body: { 'error' => { 'message' => 'Template not found' } } }
      )

      delete "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/whatsapp_templates/boas_vindas",
             headers: administrator.create_new_auth_token

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to eq('Template not found')
    end
  end
end
```

- [ ] **Step 3: Run the test and watch it fail**

```bash
docker exec -w /app cw-v4-rails-1 bundle lock --add-platform aarch64-linux
docker exec -w /app -e RAILS_ENV=test cw-v4-rails-1 bundle exec rspec spec/controllers/api/v1/accounts/inboxes/whatsapp_templates_controller_spec.rb
```

Expected: FAIL — routing error / uninitialized constant.

- [ ] **Step 4: Write the controller**

Create `app/controllers/api/v1/accounts/inboxes/whatsapp_templates_controller.rb`:

```ruby
class Api::V1::Accounts::Inboxes::WhatsappTemplatesController < Api::V1::Accounts::BaseController
  before_action :fetch_inbox
  before_action :validate_whatsapp_cloud_channel

  def create
    payload = Whatsapp::TemplateBuilder.new(**template_params.to_h.symbolize_keys).build
    result = @inbox.channel.create_template(payload)
    return render_meta_error(result) unless result[:success]

    @inbox.channel.sync_templates
    render json: { message_templates: @inbox.channel.reload.message_templates }, status: :created
  rescue Whatsapp::TemplateBuilder::InvalidTemplateError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    result = @inbox.channel.delete_template(params[:name])
    return render_meta_error(result) unless result[:success]

    @inbox.channel.sync_templates
    render json: { message_templates: @inbox.channel.reload.message_templates }, status: :ok
  end

  private

  def fetch_inbox
    @inbox = Current.account.inboxes.find(params[:inbox_id])
    # Administrator-level on purpose: these calls write to the account's Meta WABA.
    authorize @inbox, :update?
  end

  def validate_whatsapp_cloud_channel
    return if @inbox.channel.is_a?(Channel::Whatsapp) && @inbox.channel.provider == 'whatsapp_cloud'

    render json: { error: 'Template management is only available for WhatsApp Cloud channels' },
           status: :unprocessable_entity
  end

  def template_params
    params.permit(:name, :language, :category, :body, examples: [])
  end

  # Meta's own wording is the most useful thing we can show; translating it
  # would hide the real reason and turn every rejection into a support ticket.
  def render_meta_error(result)
    body = result[:body]
    message = body.is_a?(Hash) ? body.dig('error', 'message') : nil
    render json: { error: message || 'Template request failed', details: body }, status: :unprocessable_entity
  end
end
```

- [ ] **Step 5: Run the test and watch it pass**

```bash
docker exec -w /app -e RAILS_ENV=test cw-v4-rails-1 bundle exec rspec spec/controllers/api/v1/accounts/inboxes/whatsapp_templates_controller_spec.rb
```

Expected: PASS.

If the agent case returns 401 rather than 403, check that `authorize` runs — Pundit raises `NotAuthorizedError` which `BaseController` renders as 403. Do not weaken the assertion to make it pass; a wrong status here is the difference between "agents cannot touch the WABA" and "we thought they could not".

- [ ] **Step 6: Rubocop and commit**

```bash
docker exec -w /app cw-v4-rails-1 bundle exec rubocop app/controllers/api/v1/accounts/inboxes config/routes.rb -a
git checkout -- Gemfile.lock
git add app/controllers/api/v1/accounts/inboxes config/routes.rb spec/controllers/api/v1/accounts/inboxes
git commit -m "feat: add the WhatsApp templates API endpoint"
```

---

## Task 4: Frontend API client and translations

**Files:**
- Create: `app/javascript/dashboard/api/channel/whatsappTemplates.js`
- Create: `app/javascript/dashboard/i18n/locale/en/whatsappTemplates.json`, `.../pt_BR/whatsappTemplates.json`
- Modify: `app/javascript/dashboard/i18n/locale/en/index.js`, `.../pt_BR/index.js`
- Modify: `app/javascript/dashboard/i18n/locale/en/inboxMgmt.json`, `.../pt_BR/inboxMgmt.json` (tab label)

**Interfaces:**
- Produces: default-exported client with `create(inboxId, payload)` and `delete(inboxId, name)`, both returning the axios promise. Task 5's components call exactly these two.

- [ ] **Step 1: Write the API client**

Read `app/javascript/dashboard/api/inboxes.js` first to confirm the `ApiClient` base-URL idiom in v4, then create `app/javascript/dashboard/api/channel/whatsappTemplates.js`:

```javascript
/* global axios */
import ApiClient from '../ApiClient';

// Templates are nested under an inbox because every call writes to that
// inbox's Meta WABA, and the controller authorizes on the inbox.
class WhatsappTemplates extends ApiClient {
  constructor() {
    super('inboxes', { accountScoped: true });
  }

  create(inboxId, payload) {
    return axios.post(`${this.url}/${inboxId}/whatsapp_templates`, payload);
  }

  delete(inboxId, name) {
    return axios.delete(`${this.url}/${inboxId}/whatsapp_templates/${name}`);
  }
}

export default new WhatsappTemplates();
```

- [ ] **Step 2: Add the English strings**

Create `app/javascript/dashboard/i18n/locale/en/whatsappTemplates.json`:

```json
{
  "WHATSAPP_TEMPLATES": {
    "TITLE": "Message templates",
    "SUBTITLE": "Create and remove the templates this inbox can send. Meta reviews every new template.",
    "EMPTY": "No templates yet.",
    "ADD": "New template",
    "TABLE": {
      "NAME": "Name",
      "LANGUAGE": "Language",
      "CATEGORY": "Category",
      "STATUS": "Status",
      "ACTIONS": "Actions"
    },
    "FORM": {
      "TITLE": "New template",
      "NAME": "Name",
      "NAME_PLACEHOLDER": "order_shipped",
      "NAME_HINT": "Lowercase letters, numbers and underscores only.",
      "LANGUAGE": "Language",
      "CATEGORY": "Category",
      "BODY": "Body",
      "BODY_PLACEHOLDER": "Hi {{1}}, your order {{2}} has shipped.",
      "BODY_HINT": "Use {{1}}, {{2}} for variables. Each one needs an example.",
      "EXAMPLE_LABEL": "Example for {{'{{'}}%{index}{{'}}'}}",
      "SUBMIT": "Create template",
      "CANCEL": "Cancel",
      "PENDING_NOTICE": "Meta usually reviews templates within minutes, but it can take up to 24 hours."
    },
    "DELETE": {
      "BUTTON": "Delete",
      "CONFIRM_TITLE": "Delete this template?",
      "CONFIRM_MESSAGE": "The template will be removed from Meta. Past conversations are not affected.",
      "CONFIRM_YES": "Yes, delete it",
      "CONFIRM_NO": "Cancel"
    },
    "API": {
      "CREATE_SUCCESS": "Template submitted. Meta is reviewing it.",
      "DELETE_SUCCESS": "Template deleted.",
      "ERROR": "Something went wrong. Please try again."
    }
  }
}
```

- [ ] **Step 3: Add the Portuguese strings**

Create `app/javascript/dashboard/i18n/locale/pt_BR/whatsappTemplates.json` with the same key structure and these values:

```json
{
  "WHATSAPP_TEMPLATES": {
    "TITLE": "Modelos de mensagem",
    "SUBTITLE": "Crie e remova os modelos que esta caixa de entrada pode enviar. A Meta revisa cada modelo novo.",
    "EMPTY": "Nenhum modelo ainda.",
    "ADD": "Novo modelo",
    "TABLE": {
      "NAME": "Nome",
      "LANGUAGE": "Idioma",
      "CATEGORY": "Categoria",
      "STATUS": "Status",
      "ACTIONS": "Ações"
    },
    "FORM": {
      "TITLE": "Novo modelo",
      "NAME": "Nome",
      "NAME_PLACEHOLDER": "pedido_enviado",
      "NAME_HINT": "Somente letras minúsculas, números e underscore.",
      "LANGUAGE": "Idioma",
      "CATEGORY": "Categoria",
      "BODY": "Corpo",
      "BODY_PLACEHOLDER": "Olá {{1}}, seu pedido {{2}} foi enviado.",
      "BODY_HINT": "Use {{1}}, {{2}} para variáveis. Cada uma precisa de um exemplo.",
      "EXAMPLE_LABEL": "Exemplo para {{'{{'}}%{index}{{'}}'}}",
      "SUBMIT": "Criar modelo",
      "CANCEL": "Cancelar",
      "PENDING_NOTICE": "A Meta costuma revisar em minutos, mas pode levar até 24 horas."
    },
    "DELETE": {
      "BUTTON": "Excluir",
      "CONFIRM_TITLE": "Excluir este modelo?",
      "CONFIRM_MESSAGE": "O modelo será removido da Meta. Conversas antigas não são afetadas.",
      "CONFIRM_YES": "Sim, excluir",
      "CONFIRM_NO": "Cancelar"
    },
    "API": {
      "CREATE_SUCCESS": "Modelo enviado. A Meta está revisando.",
      "DELETE_SUCCESS": "Modelo excluído.",
      "ERROR": "Algo deu errado. Tente novamente."
    }
  }
}
```

- [ ] **Step 4: Register the files and add the tab label**

In `app/javascript/dashboard/i18n/locale/en/index.js` and the `pt_BR` sibling, import `whatsappTemplates.json` and spread it exactly the way the neighbouring json files are spread — read the file and match its existing style.

In both `inboxMgmt.json` files, add to the `INBOX_MGMT.TABS` object:
- `en`: `"WHATSAPP_TEMPLATES": "Templates"`
- `pt_BR`: `"WHATSAPP_TEMPLATES": "Modelos"`

- [ ] **Step 5: Verify the JSON parses and the keys resolve**

```bash
node -e "for (const l of ['en','pt_BR']) { const j = require('./app/javascript/dashboard/i18n/locale/'+l+'/whatsappTemplates.json'); if (!j.WHATSAPP_TEMPLATES.FORM.SUBMIT) throw new Error(l); } console.log('json ok')"
TZ=UTC pnpm vitest run app/javascript/dashboard/i18n
```

Expected: `json ok`, and the i18n specs stay green (they check key parity between locales — if they fail, the two files' key sets differ).

- [ ] **Step 6: Commit**

```bash
git add app/javascript/dashboard/api/channel/whatsappTemplates.js app/javascript/dashboard/i18n
git commit -m "feat: add the WhatsApp templates api client and translations"
```

---

## Task 5: The settings tab

**Files:**
- Create: `app/javascript/dashboard/routes/dashboard/settings/inbox/components/WhatsappTemplateForm.vue`
- Create: `app/javascript/dashboard/routes/dashboard/settings/inbox/settingsPage/WhatsappTemplatesPage.vue`
- Create: `.../inbox/components/specs/WhatsappTemplateForm.spec.js`, `.../inbox/settingsPage/specs/WhatsappTemplatesPage.spec.js`
- Modify: `app/javascript/dashboard/routes/dashboard/settings/inbox/Settings.vue`

**Interfaces:**
- Consumes: `whatsappTemplates` client from Task 4; the endpoints from Task 3.
- Produces: a `whatsapp-templates` tab visible only on WhatsApp Cloud inboxes.

**Reference implementation:** two of these files exist, written against 3.14, at tag `archive/3.14-whatsapp-templates`. Read them first — they are a starting point, not a drop-in:

```bash
git show archive/3.14-whatsapp-templates:app/javascript/dashboard/routes/dashboard/settings/inbox/components/WhatsappTemplateForm.vue
git show archive/3.14-whatsapp-templates:app/javascript/dashboard/routes/dashboard/settings/inbox/settingsPage/WhatsappTemplatesPage.vue
```

Three things in them are now wrong and MUST change: the API client call shape (Task 4 changed it to inbox-nested), the i18n key root (`WHATSAPP_TEMPLATES.SETTINGS.*` → `WHATSAPP_TEMPLATES.*`), and any 3.14-only component import. Report every adaptation you make.

- [ ] **Step 1: Read the v4 neighbours before writing anything**

Read `settingsPage/ConfigurationPage.vue` and `settingsPage/CustomerSatisfactionPage.vue`. They are the two closest siblings — match how they take the `inbox` prop, how they show a loading state, and how they raise alerts (`useAlert`). Note the pattern in your report.

- [ ] **Step 2: Write the list page spec**

Create `.../settingsPage/specs/WhatsappTemplatesPage.spec.js`:

```javascript
import { shallowMount } from '@vue/test-utils';
import WhatsappTemplatesPage from '../WhatsappTemplatesPage.vue';

const inbox = {
  id: 7,
  message_templates: [
    { name: 'boas_vindas', language: 'pt_BR', category: 'UTILITY', status: 'APPROVED' },
    { name: 'pedido', language: 'pt_BR', category: 'UTILITY', status: 'PENDING' },
  ],
};

const mountPage = (props = {}) =>
  shallowMount(WhatsappTemplatesPage, {
    props: { inbox, ...props },
    global: { stubs: { WhatsappTemplateForm: true } },
  });

describe('WhatsappTemplatesPage', () => {
  it('renders a row per template', () => {
    expect(mountPage().findAll('tbody tr')).toHaveLength(2);
  });

  it('renders the empty state when the inbox has no templates', () => {
    const wrapper = mountPage({ inbox: { id: 7, message_templates: [] } });
    expect(wrapper.text()).toContain('No templates yet');
  });

  it('tolerates the empty-hash default the column ships with', () => {
    // channel_whatsapp.message_templates defaults to {} but is written as an array.
    const wrapper = mountPage({ inbox: { id: 7, message_templates: {} } });
    expect(wrapper.text()).toContain('No templates yet');
  });
});
```

That third case is not hypothetical — `db/schema.rb:684` declares the column `jsonb, default: {}` while every writer stores an Array. A page that assumes Array crashes on a channel that has never synced.

- [ ] **Step 3: Run it and watch it fail, then write the page**

```bash
TZ=UTC pnpm vitest run app/javascript/dashboard/routes/dashboard/settings/inbox/settingsPage/specs/WhatsappTemplatesPage.spec.js
```

Expected: FAIL — file does not exist.

Then write `WhatsappTemplatesPage.vue`: a table over `templates` (a computed that coerces the prop to an array — `Array.isArray(x) ? x : []`), a status badge, a delete button per row that opens a confirm dialog and calls `whatsappTemplates.delete(inbox.id, name)`, and the `WhatsappTemplateForm` behind an "add" button. On success, emit so the parent refetches the inbox; raise `useAlert` with `API.DELETE_SUCCESS` or the server's `error` string.

- [ ] **Step 4: Write the form spec**

Create `.../components/specs/WhatsappTemplateForm.spec.js`:

```javascript
import { shallowMount } from '@vue/test-utils';
import WhatsappTemplateForm from '../WhatsappTemplateForm.vue';

const mountForm = () => shallowMount(WhatsappTemplateForm, { props: { inboxId: 7 } });

describe('WhatsappTemplateForm', () => {
  it('renders one example field per variable in the body', async () => {
    const wrapper = mountForm();
    await wrapper.find('textarea').setValue('Olá {{1}}, pedido {{2}}');

    expect(wrapper.findAll('[data-testid="example-input"]')).toHaveLength(2);
  });

  it('counts a repeated variable once', async () => {
    const wrapper = mountForm();
    await wrapper.find('textarea').setValue('Oi {{1}}, confirma {{1}}?');

    expect(wrapper.findAll('[data-testid="example-input"]')).toHaveLength(1);
  });

  it('renders no example field when the body has no variables', async () => {
    const wrapper = mountForm();
    await wrapper.find('textarea').setValue('Olá, tudo bem?');

    expect(wrapper.findAll('[data-testid="example-input"]')).toHaveLength(0);
  });

  it('forces the name to lowercase', async () => {
    const wrapper = mountForm();
    await wrapper.find('input[data-testid="template-name"]').setValue('Boas Vindas');

    expect(wrapper.vm.name).toBe('boas vindas');
  });
});
```

- [ ] **Step 5: Run it, watch it fail, then write the form**

The variable-to-example-field derivation is the whole point of this component: a missing example is the most common reason Meta rejects a template. Derive the fields with a computed over the body using `/\{\{(\d+)\}\}/g`, de-duplicated and sorted, exactly like `TemplateBuilder#variable_indexes` does server-side. Give the example inputs `data-testid="example-input"` and the name input `data-testid="template-name"`.

- [ ] **Step 6: Mount the tab in `Settings.vue`**

Read `Settings.vue` first. In the `tabs()` computed (around `:169-275`), append after the `calls-configuration` block:

```javascript
      if (this.isAWhatsAppCloudChannel) {
        visibleToAllChannelTabs = [
          ...visibleToAllChannelTabs,
          {
            key: 'whatsapp-templates',
            name: this.$t('INBOX_MGMT.TABS.WHATSAPP_TEMPLATES'),
          },
        ];
      }
```

In the template block, beside the other `selectedTabKey` branches (around `:627-644` of the rendered template):

```html
        <div v-if="selectedTabKey === 'whatsapp-templates'">
          <WhatsappTemplatesPage :inbox="inbox" />
        </div>
```

and register the import + `components` entry the way `WhatsappCallingPage` is registered (`:25`, `:54`).

- [ ] **Step 7: Verify**

```bash
TZ=UTC pnpm vitest run app/javascript/dashboard/routes/dashboard/settings/inbox
pnpm eslint app/javascript/dashboard/routes/dashboard/settings/inbox app/javascript/dashboard/api/channel/whatsappTemplates.js --fix
```

Expected: all green, eslint 0 errors.

- [ ] **Step 8: Commit**

```bash
git add app/javascript/dashboard/routes/dashboard/settings/inbox
git commit -m "feat: create and delete WhatsApp templates from the inbox settings"
```

---

## Task 6: Sweep

- [ ] **Step 1: Backend**

```bash
docker exec -w /app cw-v4-rails-1 bundle lock --add-platform aarch64-linux
docker exec -w /app -e RAILS_ENV=test cw-v4-rails-1 bundle exec rspec \
  spec/services/whatsapp/template_builder_spec.rb \
  spec/services/whatsapp/providers/ \
  spec/services/whatsapp/csat_template_service_spec.rb \
  spec/models/channel/whatsapp_spec.rb \
  spec/controllers/api/v1/accounts/inboxes/whatsapp_templates_controller_spec.rb \
  spec/jobs/channels/whatsapp/
git checkout -- Gemfile.lock
```

Expected: 0 failures. `csat_template_service_spec.rb` is in that list on purpose — it is the regression check that generalising the provider did not disturb live CSAT template creation.

- [ ] **Step 2: Full frontend suite**

`TZ=UTC pnpm vitest run` — the whole repo, so a broken shared file shows up.

- [ ] **Step 3: Linters**

```bash
docker exec -w /app cw-v4-rails-1 bundle lock --add-platform aarch64-linux
docker exec -w /app cw-v4-rails-1 bundle exec rubocop app/services/whatsapp app/controllers/api/v1/accounts/inboxes app/models/channel/whatsapp.rb config/routes.rb
git checkout -- Gemfile.lock
pnpm eslint app/javascript/dashboard/routes/dashboard/settings/inbox app/javascript/dashboard/api/channel/whatsappTemplates.js
```

Report exact error and warning counts.

- [ ] **Step 4: Production build**

`NODE_OPTIONS=--max-old-space-size=8192 pnpm vite build` — the default heap is not enough in this repo.

- [ ] **Step 5: Report what a human still has to do**

This feature cannot be fully verified without a real Meta WABA. Write the click-through list explicitly: create a template with no variables, create one with two variables, create one with a duplicate name (expect Meta's own error text on screen), delete a template, confirm an agent account does not see the tab's actions succeed, and confirm the tab is absent on a 360dialog and a Twilio inbox.

---

## Self-Review

**Spec coverage.** Design §Backend → Tasks 1-3 (`TemplateBuilder`, provider methods + delegate, controller + routes). Design §Frontend → Tasks 4-5 (client, i18n, list page, form, tab). Design §Testes → the spec steps in Tasks 1, 2, 3, 5, gathered in Task 6. Design §Erros ("Meta's message reaches the user untranslated") → Task 3 Step 4 `render_meta_error` plus its two specs. Design §Pré-requisito operacional (the `whatsapp_business_management` scope) → confirmed present on this account before planning; no task needed.

Two design items are deliberately dropped and are NOT gaps: `POST /{waba_id}/message_templates` was specified against Graph `v20.0`, which expires 2026-09-24 — replaced by the shared `WHATSAPP_API_VERSION` config throughout. And the design's "add `create_template`/`delete_template` to `BaseService` and `WhatsappCloudService` from scratch" was written without knowing `CsatTemplateService` already does this HTTP; Task 2 mirrors that proven shape instead.

**Placeholder scan.** Every code step carries real code. Task 5 Steps 3 and 5 describe components in prose rather than shipping full SFCs — deliberate: the reference implementations exist at `archive/3.14-whatsapp-templates` and are cited with the exact commands to read them plus the three named adaptations, and both components' behavioural contracts are pinned by the specs in Steps 2 and 4, which ARE written out in full.

**Type consistency.** `create_template`/`delete_template` return `{ success:, body: }` in Task 2 and are consumed as `result[:success]` / `result[:body]` in Task 3. `TemplateBuilder#build` returns the payload Hash and raises `InvalidTemplateError` in Task 1; Task 3 rescues exactly that constant. The client's `create(inboxId, payload)` / `delete(inboxId, name)` in Task 4 match the routes in Task 3 Step 1 and the calls in Task 5. Tab key `whatsapp-templates` and i18n key `INBOX_MGMT.TABS.WHATSAPP_TEMPLATES` agree between Task 4 Step 4 and Task 5 Step 6.

**Known risk this plan does not remove.** No Meta WABA is reachable from this environment, so every Graph call is WebMock-stubbed. The stubs encode what Meta's docs say it returns, not what it actually returns for this account. First contact with the real API is Task 6 Step 5, by a human.
