# WhatsApp Template Creation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Permitir que um administrador crie e exclua templates de mensagem do WhatsApp direto do Chatwoot, sem sair para o Business Manager da Meta.

**Architecture:** Passthrough puro. O Chatwoot não persiste template algum — a fonte da verdade continua sendo a coluna jsonb `message_templates` do canal, preenchida por `sync_templates`. O controller monta o payload da Meta via um builder testável, chama a Graph API através do provider service e re-sincroniza a lista logo em seguida.

**Tech Stack:** Ruby on Rails 7, RSpec + WebMock, HTTParty, Vue 3 (Options API), Vuex, Vite.

## Global Constraints

- Provedor suportado: **apenas** `whatsapp_cloud`. `Whatsapp360DialogService` herda o stub que levanta erro; a UI esconde a aba.
- Componentes suportados: **apenas** `BODY` com variáveis `{{1}}..{{n}}`. Nada de `HEADER`, `FOOTER` ou `BUTTONS`.
- Operações: criar, listar (dados já sincronizados) e excluir. **Sem edição.**
- Versão da Graph API para endpoints de template: `v20.0`. **Não alterar** `phone_id_path` (`v13.0`) nem `business_account_path` (`v14.0`) — mexer neles regride envio de mensagem e `sync_templates`.
- Mensagem de erro da Meta sobe **crua** para o usuário, sem tradução.
- Autorização: reusa `InboxPolicy#update?` (administrador). **Nenhuma policy nova.**
- Nome de template válido: `^[a-z0-9_]+$`.
- Categorias válidas: `UTILITY`, `MARKETING`, `AUTHENTICATION`.
- Toda string visível ao usuário passa por i18n, em `en` e `pt_BR`.

## Pré-requisito operacional

O token do canal precisa do escopo `whatsapp_business_management`. Sem ele a Meta responde 403 e nada funciona:

```bash
curl "https://graph.facebook.com/v20.0/debug_token?input_token=$TK&access_token=$TK"
```

## File Structure

| Arquivo | Responsabilidade |
|---|---|
| `app/services/whatsapp/template_builder.rb` | **Criar.** Valida entrada e monta o payload da Meta. Única lógica não trivial. |
| `app/services/whatsapp/providers/base_service.rb` | **Modificar.** Dois stubs novos. |
| `app/services/whatsapp/providers/whatsapp_cloud_service.rb` | **Modificar.** Chamadas HTTP de criar/excluir template. |
| `app/models/channel/whatsapp.rb` | **Modificar.** Dois `delegate`. |
| `app/controllers/api/v1/accounts/channels/whatsapp_templates_controller.rb` | **Criar.** Autorização, orquestração, tradução de erro para 422. |
| `config/routes.rb` | **Modificar.** Duas rotas. |
| `app/javascript/dashboard/api/channel/whatsappTemplates.js` | **Criar.** Cliente HTTP. |
| `app/javascript/dashboard/i18n/locale/{en,pt_BR}/whatsappTemplates.json` | **Modificar.** Chaves da nova tela. |
| `.../inbox/settingsPage/WhatsappTemplatesPage.vue` | **Criar.** Lista + exclusão. |
| `.../inbox/components/WhatsappTemplateForm.vue` | **Criar.** Modal de criação. |
| `.../inbox/Settings.vue` | **Modificar.** Registra a aba. |

Ordem de execução: backend de baixo para cima (builder → provider → model → controller), depois frontend.

---

### Task 1: `Whatsapp::TemplateBuilder`

Objeto que recebe params planos e devolve o payload da Meta. Não faz I/O.

**Files:**
- Create: `app/services/whatsapp/template_builder.rb`
- Test: `spec/services/whatsapp/template_builder_spec.rb`

**Interfaces:**
- Consumes: nada.
- Produces: `Whatsapp::TemplateBuilder.new(name:, language:, category:, body:, examples:).perform` → `Hash` pronto para `to_json`. Levanta `Whatsapp::TemplateBuilder::ValidationError` com mensagem legível. `examples` é opcional e default `[]`.

- [ ] **Step 1: Write the failing test**

Criar `spec/services/whatsapp/template_builder_spec.rb`:

```ruby
require 'rails_helper'

describe Whatsapp::TemplateBuilder do
  def build(overrides = {})
    described_class.new(**{
      name: 'boas_vindas',
      language: 'pt_BR',
      category: 'UTILITY',
      body: 'Olá, tudo bem?',
      examples: []
    }.merge(overrides))
  end

  describe '#perform' do
    it 'builds a payload without variables' do
      expect(build.perform).to eq(
        {
          name: 'boas_vindas',
          language: 'pt_BR',
          category: 'UTILITY',
          components: [{ type: 'BODY', text: 'Olá, tudo bem?' }]
        }
      )
    end

    it 'builds a payload with variables and examples' do
      payload = build(
        body: 'Olá {{1}}, pedido {{2}} enviado.',
        examples: %w[Pedro 1234]
      ).perform

      expect(payload[:components]).to eq(
        [{
          type: 'BODY',
          text: 'Olá {{1}}, pedido {{2}} enviado.',
          example: { body_text: [%w[Pedro 1234]] }
        }]
      )
    end

    it 'rejects an invalid name' do
      expect { build(name: 'Boas Vindas').perform }
        .to raise_error(described_class::ValidationError, /name/i)
    end

    it 'rejects an unknown category' do
      expect { build(category: 'SHIPPING').perform }
        .to raise_error(described_class::ValidationError, /category/i)
    end

    it 'rejects a blank body' do
      expect { build(body: '  ').perform }
        .to raise_error(described_class::ValidationError, /body/i)
    end

    it 'rejects a gap in the variable sequence' do
      expect { build(body: 'Oi {{1}} e {{3}}', examples: %w[a b]).perform }
        .to raise_error(described_class::ValidationError, /sequence/i)
    end

    it 'rejects a variable count that does not match the examples' do
      expect { build(body: 'Oi {{1}} e {{2}}', examples: %w[a]).perform }
        .to raise_error(described_class::ValidationError, /example/i)
    end

    it 'rejects a blank example' do
      expect { build(body: 'Oi {{1}}', examples: ['  ']).perform }
        .to raise_error(described_class::ValidationError, /example/i)
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/services/whatsapp/template_builder_spec.rb`
Expected: FAIL com `uninitialized constant Whatsapp::TemplateBuilder`

- [ ] **Step 3: Write minimal implementation**

Criar `app/services/whatsapp/template_builder.rb`:

```ruby
class Whatsapp::TemplateBuilder
  class ValidationError < StandardError; end

  NAME_REGEX = /\A[a-z0-9_]+\z/
  VARIABLE_REGEX = /\{\{(\d+)\}\}/
  CATEGORIES = %w[UTILITY MARKETING AUTHENTICATION].freeze

  def initialize(name:, language:, category:, body:, examples: [])
    @name = name.to_s.strip
    @language = language.to_s.strip
    @category = category.to_s.strip.upcase
    @body = body.to_s
    @examples = Array(examples).map(&:to_s)
  end

  def perform
    validate!
    { name: @name, language: @language, category: @category, components: [body_component] }
  end

  private

  def validate!
    raise ValidationError, 'Template name must match [a-z0-9_]' unless @name.match?(NAME_REGEX)
    raise ValidationError, 'Language is required' if @language.blank?
    raise ValidationError, "Category must be one of #{CATEGORIES.join(', ')}" unless CATEGORIES.include?(@category)
    raise ValidationError, 'Body is required' if @body.strip.blank?

    validate_variables!
  end

  def validate_variables!
    return if variables.empty? && @examples.empty?

    raise ValidationError, 'Variables must form the sequence {{1}}..{{n}} without gaps' unless variables == (1..variables.size).to_a
    raise ValidationError, 'One example is required per variable' unless @examples.size == variables.size
    raise ValidationError, 'Examples cannot be blank' if @examples.any?(&:blank?)
  end

  def variables
    @variables ||= @body.scan(VARIABLE_REGEX).flatten.map(&:to_i).uniq.sort
  end

  def body_component
    component = { type: 'BODY', text: @body }
    return component if variables.empty?

    component.merge(example: { body_text: [@examples] })
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/services/whatsapp/template_builder_spec.rb`
Expected: PASS, 8 examples, 0 failures

- [ ] **Step 5: Rubocop**

Run: `bundle exec rubocop app/services/whatsapp/template_builder.rb spec/services/whatsapp/template_builder_spec.rb`
Expected: no offenses. Se reclamar de tamanho de classe/método, extrair a validação para métodos menores — não desabilitar cop.

- [ ] **Step 6: Commit**

```bash
git add app/services/whatsapp/template_builder.rb spec/services/whatsapp/template_builder_spec.rb
git commit -m "feat: add whatsapp template payload builder"
```

---

### Task 2: Provider — criar e excluir template na Graph API

**Files:**
- Modify: `app/services/whatsapp/providers/base_service.rb`
- Modify: `app/services/whatsapp/providers/whatsapp_cloud_service.rb`
- Modify: `app/models/channel/whatsapp.rb`
- Test: `spec/services/whatsapp/providers/whatsapp_cloud_service_spec.rb`

**Interfaces:**
- Consumes: nada da Task 1 (o builder é chamado pelo controller, não pelo provider).
- Produces:
  - `Channel::Whatsapp#create_template(payload_hash)` → `[Boolean, Hash|String]`. Em sucesso, `[true, corpo_parseado]`; em falha, `[false, mensagem_de_erro_da_meta]`.
  - `Channel::Whatsapp#delete_template(name_string)` → mesma tupla.

- [ ] **Step 1: Write the failing test**

Adicionar ao final de `spec/services/whatsapp/providers/whatsapp_cloud_service_spec.rb`, **antes** do `end` final:

```ruby
  describe '#create_template' do
    let(:payload) do
      { name: 'boas_vindas', language: 'pt_BR', category: 'UTILITY',
        components: [{ type: 'BODY', text: 'Olá' }] }
    end

    it 'returns true and the parsed body when Meta accepts it' do
      stub_request(:post, 'https://graph.facebook.com/v20.0/123456789/message_templates')
        .with(body: payload.to_json)
        .to_return(status: 200, body: { id: '111', status: 'PENDING' }.to_json, headers: response_headers)

      ok, result = service.create_template(payload)

      expect(ok).to be(true)
      expect(result['status']).to eq('PENDING')
    end

    it 'returns false and the Meta error message when it rejects' do
      stub_request(:post, 'https://graph.facebook.com/v20.0/123456789/message_templates')
        .to_return(
          status: 400,
          body: { error: { message: 'Template name already exists' } }.to_json,
          headers: response_headers
        )

      ok, result = service.create_template(payload)

      expect(ok).to be(false)
      expect(result).to eq('Template name already exists')
    end
  end

  describe '#delete_template' do
    it 'returns true when Meta deletes it' do
      stub_request(:delete, 'https://graph.facebook.com/v20.0/123456789/message_templates?name=boas_vindas')
        .to_return(status: 200, body: { success: true }.to_json, headers: response_headers)

      ok, = service.delete_template('boas_vindas')

      expect(ok).to be(true)
    end
  end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/services/whatsapp/providers/whatsapp_cloud_service_spec.rb -e '#create_template'`
Expected: FAIL com `undefined method 'create_template'`

- [ ] **Step 3: Add the stubs to the base service**

Em `app/services/whatsapp/providers/base_service.rb`, logo abaixo do método `sync_template`:

```ruby
  def create_template(_params)
    raise 'Overwrite this method in child class'
  end

  def delete_template(_name)
    raise 'Overwrite this method in child class'
  end
```

Atualizar também o comentário do topo do arquivo, acrescentando duas linhas à lista:

```ruby
# - Implement `create_template` method in your child class.
# - Implement `delete_template` method in your child class.
```

- [ ] **Step 4: Implement in the cloud service**

Em `app/services/whatsapp/providers/whatsapp_cloud_service.rb`, adicionar a constante como primeira linha do corpo da classe:

```ruby
  TEMPLATE_API_VERSION = 'v20.0'.freeze
```

Inserir os métodos públicos logo **depois** de `sync_templates` e **antes** de `fetch_whatsapp_templates`:

```ruby
  def create_template(params)
    response = HTTParty.post(
      "#{template_account_path}/message_templates",
      headers: api_headers,
      body: params.to_json
    )
    handle_template_response(response)
  end

  def delete_template(name)
    response = HTTParty.delete(
      "#{template_account_path}/message_templates?name=#{CGI.escape(name)}",
      headers: api_headers
    )
    handle_template_response(response)
  end

  def template_account_path
    "#{api_base_path}/#{TEMPLATE_API_VERSION}/#{whatsapp_channel.provider_config['business_account_id']}"
  end

  # Diferente de process_response, este método preserva a mensagem de erro da Meta
  # para que ela chegue ao usuário.
  def handle_template_response(response)
    return [true, response.parsed_response] if response.success?

    Rails.logger.error response.body
    body = response.parsed_response
    error_message = body.is_a?(Hash) ? body.dig('error', 'message') : nil
    [false, error_message.presence || 'Unknown error from WhatsApp']
  end
```

A guarda `body.is_a?(Hash)` existe porque a Meta às vezes responde HTML em erro de gateway — sem ela, `dig` levanta `NoMethodError` e o usuário recebe 500 em vez de 422.

**Não alterar** `business_account_path` nem `phone_id_path`.

- [ ] **Step 5: Run test to verify it passes**

Run: `bundle exec rspec spec/services/whatsapp/providers/whatsapp_cloud_service_spec.rb`
Expected: PASS, incluindo os testes que já existiam.

- [ ] **Step 6: Delegate from the channel model**

Em `app/models/channel/whatsapp.rb`, ao lado dos delegates que já existem (`send_template`, `sync_templates`):

```ruby
  delegate :create_template, to: :provider_service
  delegate :delete_template, to: :provider_service
```

- [ ] **Step 7: Run the whatsapp suite**

Run: `bundle exec rspec spec/services/whatsapp spec/models/channel/whatsapp_spec.rb`
Expected: PASS, 0 failures

- [ ] **Step 8: Rubocop + commit**

```bash
bundle exec rubocop app/services/whatsapp app/models/channel/whatsapp.rb
git add app/services/whatsapp app/models/channel/whatsapp.rb spec/services/whatsapp
git commit -m "feat: create and delete whatsapp templates via the cloud api"
```

---

### Task 3: Endpoint da API

**Files:**
- Create: `app/controllers/api/v1/accounts/channels/whatsapp_templates_controller.rb`
- Modify: `config/routes.rb` (bloco `namespace :channels`, hoje com só `resource :twilio_channel`)
- Test: `spec/controllers/api/v1/accounts/channels/whatsapp_templates_controller_spec.rb`

**Interfaces:**
- Consumes: `Whatsapp::TemplateBuilder` (Task 1), `Channel::Whatsapp#create_template` / `#delete_template` (Task 2).
- Produces: rotas `api_v1_account_channels_whatsapp_templates_path(account)` (POST) e `api_v1_account_channels_whatsapp_template_path(account, name)` (DELETE). Resposta de sucesso: `{ payload: [...message_templates] }`. Resposta de erro: `{ error: "mensagem" }` com status 422.

- [ ] **Step 1: Add the routes**

Em `config/routes.rb`, dentro do `namespace :channels` existente:

```ruby
          namespace :channels do
            resource :twilio_channel, only: [:create]
            resources :whatsapp_templates, only: [:create, :destroy]
          end
```

O `:id` do `destroy` é o **nome** do template — a Meta exclui por nome, e nomes casam `^[a-z0-9_]+$`, então são seguros na URL sem escaping extra.

- [ ] **Step 2: Write the failing test**

Criar `spec/controllers/api/v1/accounts/channels/whatsapp_templates_controller_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe 'Whatsapp Templates API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:channel) do
    create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud',
                              validate_provider_config: false, sync_templates: false)
  end
  let(:inbox) { channel.inbox }
  let(:params) do
    {
      inbox_id: inbox.id,
      name: 'boas_vindas',
      language: 'pt_BR',
      category: 'UTILITY',
      body: 'Olá {{1}}',
      examples: ['Pedro']
    }
  end

  describe 'POST /api/v1/accounts/{account.id}/channels/whatsapp_templates' do
    context 'when unauthenticated' do
      it 'returns unauthorized' do
        post api_v1_account_channels_whatsapp_templates_path(account), params: params
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when the user is an agent' do
      it 'returns forbidden' do
        post api_v1_account_channels_whatsapp_templates_path(account),
             params: params, headers: agent.create_new_auth_token
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when the user is an administrator' do
      it 'creates the template and returns the refreshed list' do
        allow_any_instance_of(Channel::Whatsapp).to receive(:create_template).and_return([true, { 'id' => '1' }])
        allow_any_instance_of(Channel::Whatsapp).to receive(:sync_templates).and_return(true)

        post api_v1_account_channels_whatsapp_templates_path(account),
             params: params, headers: admin.create_new_auth_token

        expect(response).to have_http_status(:success)
        expect(response.parsed_body['payload']).to be_an(Array)
      end

      it 'returns the Meta error message untouched' do
        allow_any_instance_of(Channel::Whatsapp).to receive(:create_template)
          .and_return([false, 'Template name already exists'])

        post api_v1_account_channels_whatsapp_templates_path(account),
             params: params, headers: admin.create_new_auth_token

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to eq('Template name already exists')
      end

      it 'returns a validation error for a bad template name' do
        post api_v1_account_channels_whatsapp_templates_path(account),
             params: params.merge(name: 'Boas Vindas'), headers: admin.create_new_auth_token

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to match(/name/i)
      end

      it 'rejects a non-cloud whatsapp channel' do
        dialog_channel = create(:channel_whatsapp, account: account, provider: 'default',
                                                   validate_provider_config: false, sync_templates: false)

        post api_v1_account_channels_whatsapp_templates_path(account),
             params: params.merge(inbox_id: dialog_channel.inbox.id),
             headers: admin.create_new_auth_token

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'DELETE /api/v1/accounts/{account.id}/channels/whatsapp_templates/{name}' do
    it 'deletes the template' do
      allow_any_instance_of(Channel::Whatsapp).to receive(:delete_template).and_return([true, { 'success' => true }])
      allow_any_instance_of(Channel::Whatsapp).to receive(:sync_templates).and_return(true)

      delete api_v1_account_channels_whatsapp_template_path(account, 'boas_vindas'),
             params: { inbox_id: inbox.id }, headers: admin.create_new_auth_token

      expect(response).to have_http_status(:success)
    end
  end
end
```

- [ ] **Step 3: Run test to verify it fails**

Run: `bundle exec rspec spec/controllers/api/v1/accounts/channels/whatsapp_templates_controller_spec.rb`
Expected: FAIL com `uninitialized constant Api::V1::Accounts::Channels::WhatsappTemplatesController`

- [ ] **Step 4: Write the controller**

Criar `app/controllers/api/v1/accounts/channels/whatsapp_templates_controller.rb`:

```ruby
class Api::V1::Accounts::Channels::WhatsappTemplatesController < Api::V1::Accounts::BaseController
  before_action :fetch_inbox
  before_action :authorize_request
  before_action :ensure_whatsapp_cloud_channel

  def create
    payload = Whatsapp::TemplateBuilder.new(**builder_params).perform
    success, result = channel.create_template(payload)
    return render_template_error(result) unless success

    render_templates
  rescue Whatsapp::TemplateBuilder::ValidationError => e
    render_template_error(e.message)
  end

  def destroy
    success, result = channel.delete_template(params[:id])
    return render_template_error(result) unless success

    render_templates
  end

  private

  def fetch_inbox
    @inbox = Current.account.inboxes.find(params[:inbox_id])
  end

  def authorize_request
    authorize @inbox, :update?
  end

  def ensure_whatsapp_cloud_channel
    return if channel.is_a?(Channel::Whatsapp) && channel.provider == 'whatsapp_cloud'

    render_template_error('Template management is only available for WhatsApp Cloud channels')
  end

  def channel
    @inbox.channel
  end

  def builder_params
    params.permit(:name, :language, :category, :body, examples: []).to_h.symbolize_keys
  end

  def render_templates
    channel.sync_templates
    render json: { payload: channel.reload.message_templates }
  end

  def render_template_error(message)
    render json: { error: message }, status: :unprocessable_entity
  end
end
```

`permit` omite chaves não enviadas, então uma requisição sem `examples` não produz `examples: nil` no splat — a chave some e o default `[]` do builder vale. Nenhum tratamento extra necessário.

- [ ] **Step 5: Run test to verify it passes**

Run: `bundle exec rspec spec/controllers/api/v1/accounts/channels/whatsapp_templates_controller_spec.rb`
Expected: PASS, 7 examples, 0 failures

Se o teste do agente devolver 401 em vez de 403, conferir que `authorize @inbox, :update?` vem **depois** de `fetch_inbox` na ordem dos `before_action`.

- [ ] **Step 6: Rubocop + commit**

```bash
bundle exec rubocop app/controllers/api/v1/accounts/channels config/routes.rb
git add app/controllers/api/v1/accounts/channels config/routes.rb spec/controllers/api/v1/accounts/channels
git commit -m "feat: add whatsapp template management endpoint"
```

---

### Task 4: Cliente de API e traduções

Tarefa pequena, sem teste próprio — é configuração consumida pela Task 5.

**Files:**
- Create: `app/javascript/dashboard/api/channel/whatsappTemplates.js`
- Modify: `app/javascript/dashboard/i18n/locale/en/whatsappTemplates.json`
- Modify: `app/javascript/dashboard/i18n/locale/pt_BR/whatsappTemplates.json`

**Interfaces:**
- Consumes: rotas da Task 3.
- Produces: `WhatsappTemplatesAPI.create(payload)` e `WhatsappTemplatesAPI.remove({ inboxId, name })`, ambos devolvendo a promise do axios cuja `response.data.payload` é a lista de templates atualizada.

- [ ] **Step 1: Write the API client**

Criar `app/javascript/dashboard/api/channel/whatsappTemplates.js`:

```js
/* global axios */
import ApiClient from '../ApiClient';

class WhatsappTemplates extends ApiClient {
  constructor() {
    super('channels/whatsapp_templates', { accountScoped: true });
  }

  remove({ inboxId, name }) {
    return axios.delete(`${this.url}/${name}`, {
      params: { inbox_id: inboxId },
    });
  }
}

export default new WhatsappTemplates();
```

`create` vem do `ApiClient` base e não precisa ser reescrito. `remove` existe porque o `delete` do base não aceita query params, e o backend precisa do `inbox_id`.

- [ ] **Step 2: Add the English strings**

Em `app/javascript/dashboard/i18n/locale/en/whatsappTemplates.json`, dentro do objeto `WHATSAPP_TEMPLATES`, ao lado de `MODAL`, `PICKER` e `PARSER` (indentação de 4 espaços, igual ao resto do arquivo):

```json
        "SETTINGS": {
            "TITLE": "Message templates",
            "SUBTITLE": "Templates are created here and approved by Meta. Approval takes from a few minutes up to 24 hours.",
            "NEW_TEMPLATE": "New template",
            "EMPTY": "No templates yet. Create the first one.",
            "TABLE": {
                "NAME": "Name",
                "LANGUAGE": "Language",
                "CATEGORY": "Category",
                "STATUS": "Status",
                "ACTIONS": "Actions"
            },
            "DELETE": {
                "BUTTON": "Delete",
                "CONFIRM_TITLE": "Delete template",
                "CONFIRM_MESSAGE": "Are you sure you want to delete {name}? This cannot be undone.",
                "CONFIRM_YES": "Yes, delete",
                "CONFIRM_NO": "Cancel",
                "SUCCESS": "Template deleted"
            },
            "FORM": {
                "TITLE": "New template",
                "NAME": {
                    "LABEL": "Name",
                    "PLACEHOLDER": "order_shipped",
                    "HELP": "Lowercase letters, numbers and underscores only.",
                    "ERROR": "Use only lowercase letters, numbers and underscores."
                },
                "LANGUAGE": { "LABEL": "Language" },
                "CATEGORY": { "LABEL": "Category" },
                "BODY": {
                    "LABEL": "Body",
                    "PLACEHOLDER": "Hi {{1}}, your order {{2}} has shipped.",
                    "HELP": "Use {{1}}, {{2}} for variables.",
                    "ERROR": "Body is required."
                },
                "EXAMPLES": {
                    "LABEL": "Variable examples",
                    "HELP": "Meta rejects templates without an example for every variable.",
                    "PLACEHOLDER": "Example for {variable}"
                },
                "SUBMIT": "Create template",
                "CANCEL": "Cancel",
                "SUCCESS": "Template submitted. Meta review is pending."
            }
        }
```

- [ ] **Step 3: Add the Portuguese strings**

Mesma estrutura em `app/javascript/dashboard/i18n/locale/pt_BR/whatsappTemplates.json`, com os mesmos caminhos de chave e os valores traduzidos:

```json
        "SETTINGS": {
            "TITLE": "Modelos de mensagem",
            "SUBTITLE": "Os modelos são criados aqui e aprovados pela Meta. A aprovação leva de alguns minutos a 24 horas.",
            "NEW_TEMPLATE": "Novo modelo",
            "EMPTY": "Nenhum modelo ainda. Crie o primeiro.",
            "TABLE": {
                "NAME": "Nome",
                "LANGUAGE": "Idioma",
                "CATEGORY": "Categoria",
                "STATUS": "Status",
                "ACTIONS": "Ações"
            },
            "DELETE": {
                "BUTTON": "Excluir",
                "CONFIRM_TITLE": "Excluir modelo",
                "CONFIRM_MESSAGE": "Tem certeza que deseja excluir {name}? Esta ação não pode ser desfeita.",
                "CONFIRM_YES": "Sim, excluir",
                "CONFIRM_NO": "Cancelar",
                "SUCCESS": "Modelo excluído"
            },
            "FORM": {
                "TITLE": "Novo modelo",
                "NAME": {
                    "LABEL": "Nome",
                    "PLACEHOLDER": "pedido_enviado",
                    "HELP": "Apenas letras minúsculas, números e sublinhado.",
                    "ERROR": "Use apenas letras minúsculas, números e sublinhado."
                },
                "LANGUAGE": { "LABEL": "Idioma" },
                "CATEGORY": { "LABEL": "Categoria" },
                "BODY": {
                    "LABEL": "Corpo",
                    "PLACEHOLDER": "Olá {{1}}, seu pedido {{2}} foi enviado.",
                    "HELP": "Use {{1}}, {{2}} para variáveis.",
                    "ERROR": "O corpo é obrigatório."
                },
                "EXAMPLES": {
                    "LABEL": "Exemplos das variáveis",
                    "HELP": "A Meta rejeita modelos sem exemplo para cada variável.",
                    "PLACEHOLDER": "Exemplo para {variable}"
                },
                "SUBMIT": "Criar modelo",
                "CANCEL": "Cancelar",
                "SUCCESS": "Modelo enviado. Aguardando revisão da Meta."
            }
        }
```

- [ ] **Step 4: Verify the JSON parses and the keys exist**

Run:
```bash
node -e "['en','pt_BR'].forEach(l => { const j = require('./app/javascript/dashboard/i18n/locale/'+l+'/whatsappTemplates.json'); if (!j.WHATSAPP_TEMPLATES.SETTINGS.FORM.SUBMIT) throw new Error('missing key in '+l); }); console.log('ok')"
```
Expected: `ok`

- [ ] **Step 5: Commit**

```bash
git add app/javascript/dashboard/api/channel/whatsappTemplates.js app/javascript/dashboard/i18n/locale/en/whatsappTemplates.json app/javascript/dashboard/i18n/locale/pt_BR/whatsappTemplates.json
git commit -m "feat: add whatsapp templates api client and translations"
```

---

### Task 5: Tela de templates na configuração da inbox

**Files:**
- Create: `app/javascript/dashboard/routes/dashboard/settings/inbox/settingsPage/WhatsappTemplatesPage.vue`
- Create: `app/javascript/dashboard/routes/dashboard/settings/inbox/components/WhatsappTemplateForm.vue`
- Modify: `app/javascript/dashboard/routes/dashboard/settings/inbox/Settings.vue`
- Modify: `app/javascript/dashboard/i18n/locale/en/inboxMgmt.json`
- Modify: `app/javascript/dashboard/i18n/locale/pt_BR/inboxMgmt.json`

**Interfaces:**
- Consumes: `WhatsappTemplatesAPI` (Task 4), getter `inboxes/getWhatsAppTemplates` e action `inboxes/get`, ambos já existentes.
- Produces: nada consumido por tarefas posteriores.

- [ ] **Step 1: Add the tab label to i18n**

Em `app/javascript/dashboard/i18n/locale/en/inboxMgmt.json`, dentro de `INBOX_MGMT.TABS`, ao lado de `SETTINGS` e `COLLABORATORS`:

```json
"WHATSAPP_TEMPLATES": "Templates",
```

E em `pt_BR/inboxMgmt.json`, na mesma posição:

```json
"WHATSAPP_TEMPLATES": "Modelos",
```

- [ ] **Step 2: Write the creation form component**

Criar `app/javascript/dashboard/routes/dashboard/settings/inbox/components/WhatsappTemplateForm.vue`:

```vue
<script>
const NAME_REGEX = /^[a-z0-9_]+$/;
const VARIABLE_REGEX = /\{\{(\d+)\}\}/g;

export default {
  props: {
    isSubmitting: {
      type: Boolean,
      default: false,
    },
  },
  emits: ['submit', 'cancel'],
  data() {
    return {
      name: '',
      language: 'pt_BR',
      category: 'UTILITY',
      body: '',
      examples: {},
      categories: ['UTILITY', 'MARKETING', 'AUTHENTICATION'],
      languages: ['pt_BR', 'en_US', 'es_ES'],
    };
  },
  computed: {
    variables() {
      const found = [...this.body.matchAll(VARIABLE_REGEX)].map(match =>
        Number(match[1])
      );
      return [...new Set(found)].sort((a, b) => a - b);
    },
    hasValidSequence() {
      return this.variables.every((value, index) => value === index + 1);
    },
    isNameValid() {
      return NAME_REGEX.test(this.name);
    },
    isValid() {
      return (
        this.isNameValid &&
        this.body.trim() !== '' &&
        this.hasValidSequence &&
        this.variables.every(index => (this.examples[index] || '').trim())
      );
    },
  },
  methods: {
    onNameInput(event) {
      this.name = event.target.value.toLowerCase();
    },
    onSubmit() {
      if (!this.isValid) return;
      this.$emit('submit', {
        name: this.name,
        language: this.language,
        category: this.category,
        body: this.body,
        examples: this.variables.map(index => this.examples[index]),
      });
    },
  },
};
</script>

<template>
  <form class="flex flex-col gap-4" @submit.prevent="onSubmit">
    <label :class="{ error: name && !isNameValid }">
      {{ $t('WHATSAPP_TEMPLATES.SETTINGS.FORM.NAME.LABEL') }}
      <input
        :value="name"
        type="text"
        :placeholder="$t('WHATSAPP_TEMPLATES.SETTINGS.FORM.NAME.PLACEHOLDER')"
        @input="onNameInput"
      />
      <span v-if="name && !isNameValid" class="message">
        {{ $t('WHATSAPP_TEMPLATES.SETTINGS.FORM.NAME.ERROR') }}
      </span>
      <span v-else class="text-xs text-slate-600 dark:text-slate-400">
        {{ $t('WHATSAPP_TEMPLATES.SETTINGS.FORM.NAME.HELP') }}
      </span>
    </label>

    <label>
      {{ $t('WHATSAPP_TEMPLATES.SETTINGS.FORM.LANGUAGE.LABEL') }}
      <select v-model="language">
        <option v-for="item in languages" :key="item" :value="item">
          {{ item }}
        </option>
      </select>
    </label>

    <label>
      {{ $t('WHATSAPP_TEMPLATES.SETTINGS.FORM.CATEGORY.LABEL') }}
      <select v-model="category">
        <option v-for="item in categories" :key="item" :value="item">
          {{ item }}
        </option>
      </select>
    </label>

    <label>
      {{ $t('WHATSAPP_TEMPLATES.SETTINGS.FORM.BODY.LABEL') }}
      <textarea
        v-model="body"
        rows="4"
        :placeholder="$t('WHATSAPP_TEMPLATES.SETTINGS.FORM.BODY.PLACEHOLDER')"
      />
      <span class="text-xs text-slate-600 dark:text-slate-400">
        {{ $t('WHATSAPP_TEMPLATES.SETTINGS.FORM.BODY.HELP') }}
      </span>
    </label>

    <div v-if="variables.length" class="flex flex-col gap-2">
      <span class="text-sm font-medium">
        {{ $t('WHATSAPP_TEMPLATES.SETTINGS.FORM.EXAMPLES.LABEL') }}
      </span>
      <label v-for="index in variables" :key="index">
        <input
          v-model="examples[index]"
          type="text"
          :placeholder="
            $t('WHATSAPP_TEMPLATES.SETTINGS.FORM.EXAMPLES.PLACEHOLDER', {
              variable: `{{${index}}}`,
            })
          "
        />
      </label>
      <span class="text-xs text-slate-600 dark:text-slate-400">
        {{ $t('WHATSAPP_TEMPLATES.SETTINGS.FORM.EXAMPLES.HELP') }}
      </span>
    </div>

    <div class="flex gap-2 justify-end">
      <woot-button variant="clear" @click.prevent="$emit('cancel')">
        {{ $t('WHATSAPP_TEMPLATES.SETTINGS.FORM.CANCEL') }}
      </woot-button>
      <woot-button
        type="submit"
        :is-loading="isSubmitting"
        :is-disabled="!isValid || isSubmitting"
      >
        {{ $t('WHATSAPP_TEMPLATES.SETTINGS.FORM.SUBMIT') }}
      </woot-button>
    </div>
  </form>
</template>
```

- [ ] **Step 3: Write the list page**

Criar `app/javascript/dashboard/routes/dashboard/settings/inbox/settingsPage/WhatsappTemplatesPage.vue`:

```vue
<script>
import { useAlert } from 'dashboard/composables';
import WhatsappTemplatesAPI from 'dashboard/api/channel/whatsappTemplates';
import WhatsappTemplateForm from '../components/WhatsappTemplateForm.vue';

export default {
  components: { WhatsappTemplateForm },
  props: {
    inbox: {
      type: Object,
      default: () => ({}),
    },
  },
  data() {
    return {
      showForm: false,
      isSubmitting: false,
      templateToDelete: null,
    };
  },
  computed: {
    templates() {
      return this.$store.getters['inboxes/getWhatsAppTemplates'](this.inbox.id);
    },
  },
  methods: {
    statusClass(status) {
      const normalized = (status || '').toLowerCase();
      if (normalized === 'approved') return 'text-green-600';
      if (normalized === 'rejected') return 'text-red-600';
      return 'text-yellow-600';
    },
    templateBody(template) {
      const component = (template.components || []).find(
        item => item.type === 'BODY'
      );
      return component ? component.text : '';
    },
    async onSubmit(payload) {
      this.isSubmitting = true;
      try {
        await WhatsappTemplatesAPI.create({
          ...payload,
          inbox_id: this.inbox.id,
        });
        await this.$store.dispatch('inboxes/get');
        this.showForm = false;
        useAlert(this.$t('WHATSAPP_TEMPLATES.SETTINGS.FORM.SUCCESS'));
      } catch (error) {
        useAlert(error?.response?.data?.error || error.message);
      } finally {
        this.isSubmitting = false;
      }
    },
    async confirmDelete() {
      const name = this.templateToDelete;
      this.templateToDelete = null;
      try {
        await WhatsappTemplatesAPI.remove({ inboxId: this.inbox.id, name });
        await this.$store.dispatch('inboxes/get');
        useAlert(this.$t('WHATSAPP_TEMPLATES.SETTINGS.DELETE.SUCCESS'));
      } catch (error) {
        useAlert(error?.response?.data?.error || error.message);
      }
    },
  },
};
</script>

<template>
  <div class="mx-8 flex flex-col gap-4">
    <div class="flex items-start justify-between gap-4">
      <div>
        <h4 class="text-base">
          {{ $t('WHATSAPP_TEMPLATES.SETTINGS.TITLE') }}
        </h4>
        <p class="text-sm text-slate-600 dark:text-slate-400">
          {{ $t('WHATSAPP_TEMPLATES.SETTINGS.SUBTITLE') }}
        </p>
      </div>
      <woot-button icon="add" @click="showForm = true">
        {{ $t('WHATSAPP_TEMPLATES.SETTINGS.NEW_TEMPLATE') }}
      </woot-button>
    </div>

    <p v-if="!templates.length" class="text-sm">
      {{ $t('WHATSAPP_TEMPLATES.SETTINGS.EMPTY') }}
    </p>

    <table v-else class="woot-table">
      <thead>
        <tr>
          <th>{{ $t('WHATSAPP_TEMPLATES.SETTINGS.TABLE.NAME') }}</th>
          <th>{{ $t('WHATSAPP_TEMPLATES.SETTINGS.TABLE.LANGUAGE') }}</th>
          <th>{{ $t('WHATSAPP_TEMPLATES.SETTINGS.TABLE.CATEGORY') }}</th>
          <th>{{ $t('WHATSAPP_TEMPLATES.SETTINGS.TABLE.STATUS') }}</th>
          <th>{{ $t('WHATSAPP_TEMPLATES.SETTINGS.TABLE.ACTIONS') }}</th>
        </tr>
      </thead>
      <tbody>
        <tr
          v-for="template in templates"
          :key="`${template.name}-${template.language}`"
        >
          <td>
            <span class="font-medium">{{ template.name }}</span>
            <p class="text-xs text-slate-600 dark:text-slate-400">
              {{ templateBody(template) }}
            </p>
          </td>
          <td>{{ template.language }}</td>
          <td>{{ template.category }}</td>
          <td :class="statusClass(template.status)">{{ template.status }}</td>
          <td>
            <woot-button
              variant="clear"
              color-scheme="alert"
              size="small"
              @click="templateToDelete = template.name"
            >
              {{ $t('WHATSAPP_TEMPLATES.SETTINGS.DELETE.BUTTON') }}
            </woot-button>
          </td>
        </tr>
      </tbody>
    </table>

    <woot-modal v-if="showForm" :show="true" :on-close="() => (showForm = false)">
      <div class="p-8">
        <h4 class="text-base mb-4">
          {{ $t('WHATSAPP_TEMPLATES.SETTINGS.FORM.TITLE') }}
        </h4>
        <WhatsappTemplateForm
          :is-submitting="isSubmitting"
          @submit="onSubmit"
          @cancel="showForm = false"
        />
      </div>
    </woot-modal>

    <woot-delete-modal
      v-if="templateToDelete"
      :show="true"
      :on-close="() => (templateToDelete = null)"
      :on-confirm="confirmDelete"
      :title="$t('WHATSAPP_TEMPLATES.SETTINGS.DELETE.CONFIRM_TITLE')"
      :message="
        $t('WHATSAPP_TEMPLATES.SETTINGS.DELETE.CONFIRM_MESSAGE', {
          name: templateToDelete,
        })
      "
      :confirm-text="$t('WHATSAPP_TEMPLATES.SETTINGS.DELETE.CONFIRM_YES')"
      :reject-text="$t('WHATSAPP_TEMPLATES.SETTINGS.DELETE.CONFIRM_NO')"
    />
  </div>
</template>
```

Antes de escrever, conferir a assinatura real dos modais nesta versão e copiar as props de um uso existente em vez de confiar no bloco acima:

```bash
grep -rn "woot-delete-modal" app/javascript/dashboard/routes/dashboard/settings | head -3
grep -rn "<woot-modal" app/javascript/dashboard/routes/dashboard/settings | head -3
```

- [ ] **Step 4: Register the tab in Settings.vue**

Em `app/javascript/dashboard/routes/dashboard/settings/inbox/Settings.vue`:

1. Import, junto dos outros de `settingsPage`:

```js
import WhatsappTemplatesPage from './settingsPage/WhatsappTemplatesPage.vue';
```

2. Registro em `components`:

```js
    WhatsappTemplatesPage,
```

3. No computed `tabs`, **depois** do bloco que adiciona a aba `configuration` e antes do `return visibleToAllChannelTabs;`:

```js
      if (this.isAWhatsAppCloudChannel) {
        visibleToAllChannelTabs = [
          ...visibleToAllChannelTabs,
          {
            key: 'whatsappTemplates',
            name: this.$t('INBOX_MGMT.TABS.WHATSAPP_TEMPLATES'),
          },
        ];
      }
```

4. No template, junto dos outros blocos `v-if="selectedTabKey === ..."` (perto de `selectedTabKey === 'configuration'`):

```html
    <div v-if="selectedTabKey === 'whatsappTemplates'">
      <WhatsappTemplatesPage :inbox="inbox" />
    </div>
```

`isAWhatsAppCloudChannel` já vem do `inboxMixin` (`app/javascript/shared/mixins/inboxMixin.js:77`), que este componente já usa.

- [ ] **Step 5: Lint**

Run: `pnpm eslint app/javascript/dashboard/routes/dashboard/settings/inbox app/javascript/dashboard/api/channel/whatsappTemplates.js --fix`
Expected: 0 errors. Se as dependências não estiverem instaladas no worktree, rodar `pnpm install` antes.

- [ ] **Step 6: Manual verification**

Subir o app (`overmind start -f Procfile.dev` ou `foreman start -f Procfile.dev`) e, com uma inbox WhatsApp Cloud:

1. Configurações → Caixas de entrada → a inbox → aba **Modelos** aparece
2. Criar template só com corpo, sem variável → aparece na lista como `PENDING`
3. Digitar `{{1}}` no corpo sem preencher o exemplo → botão de envio fica desabilitado
4. Criar template com nome duplicado → alerta exibe a mensagem crua da Meta
5. Abrir uma inbox 360dialog ou Twilio → aba **não** aparece
6. Excluir um template → some da lista após a confirmação

- [ ] **Step 7: Commit**

```bash
git add app/javascript/dashboard/routes/dashboard/settings/inbox app/javascript/dashboard/i18n/locale/en/inboxMgmt.json app/javascript/dashboard/i18n/locale/pt_BR/inboxMgmt.json
git commit -m "feat: manage whatsapp templates from the inbox settings"
```

---

### Task 6: Verificação final

**Files:** nenhum.

**Interfaces:**
- Consumes: tudo das Tasks 1-5.
- Produces: relatório de verificação.

- [ ] **Step 1: Run the backend suite touched by this change**

Run: `bundle exec rspec spec/services/whatsapp spec/controllers/api/v1/accounts/channels spec/models/channel/whatsapp_spec.rb`
Expected: 0 failures

- [ ] **Step 2: Rubocop on the diff**

Run: `bundle exec rubocop $(git diff --name-only origin/develop... | grep '\.rb$')`
Expected: no offenses

- [ ] **Step 3: Frontend lint on the diff**

Run: `pnpm eslint $(git diff --name-only origin/develop... | grep -E '\.(js|vue)$')`
Expected: 0 errors

- [ ] **Step 4: Report**

Relatar: comandos rodados, saída real de cada um, e qualquer item da verificação manual da Task 5 que não tenha sido executado.
