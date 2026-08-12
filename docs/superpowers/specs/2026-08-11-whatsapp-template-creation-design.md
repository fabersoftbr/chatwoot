# Criação de templates de WhatsApp pelo Chatwoot

Data: 2026-08-11
Status: aprovado, pronto para plano de implementação

## Problema

O Chatwoot só lê templates de mensagem da WhatsApp Business API. `sync_templates`
busca a lista da Meta (`GET /{waba_id}/message_templates`) no `after_create` do
canal e a cada 3h via `Channels::Whatsapp::TemplatesSyncSchedulerJob`. Não existe
caminho de escrita: para criar um template o usuário precisa sair para o Business
Manager da Meta.

A Graph API suporta escrita (`POST /{waba_id}/message_templates`) desde que o
token tenha o escopo `whatsapp_business_management`. Este fork tem os dois escopos
(`whatsapp_business_messaging` e `whatsapp_business_management`).

## Escopo da v1

Dentro:

- Criar template com componente `BODY` e variáveis `{{1}}..{{n}}` + exemplos
- Listar templates (reusa dados já sincronizados)
- Excluir template
- Provedor WhatsApp Cloud apenas

Fora (v2+):

- Componentes `HEADER`, `FOOTER` e `BUTTONS`
- Header de mídia (exige upload resumable na Meta para obter o handle)
- Edição de template existente (`POST /{template_id}`)
- Provedor 360dialog (`POST /v1/configs/templates`, formato próprio)

## Arquitetura

Passthrough puro. O Chatwoot não persiste template algum: a fonte da verdade
continua sendo a coluna jsonb `message_templates` do canal, preenchida por
`sync_templates`. Sem migração, sem sincronização bidirecional, sem drift entre
banco local e Meta.

Fluxo de criação:

```
POST /api/v1/accounts/:account_id/channels/whatsapp_templates
  → WhatsappTemplatesController
     → autoriza (InboxPolicy#update?, administrador)
     → Whatsapp::TemplateBuilder monta os components
     → Channel::Whatsapp#create_template (delegate)
        → Whatsapp::Providers::WhatsappCloudService#create_template
           → POST graph.facebook.com/v20.0/{waba_id}/message_templates
     → em caso de sucesso, sync_templates inline
  → 200 com a lista atualizada, ou 422 com o erro da Meta
```

Alternativas descartadas:

- **Tabela `whatsapp_templates` própria.** Daria rascunho local e histórico de
  rejeição, ao custo de migração, sync bidirecional e do bug clássico de template
  removido na Meta que sobrevive no banco. Não vale para a v1.
- **Criação assíncrona por job com polling.** A Meta responde na hora com
  `PENDING`; o polling só adiciona complexidade.

## Backend

### `Whatsapp::Providers::BaseService`

Dois stubs novos seguindo o padrão dos vizinhos:

```ruby
def create_template(_params)
  raise 'Overwrite this method in child class'
end

def delete_template(_name)
  raise 'Overwrite this method in child class'
end
```

### `Whatsapp::Providers::WhatsappCloudService`

```ruby
def create_template(params)
  response = HTTParty.post("#{template_account_path}/message_templates",
                           headers: api_headers, body: params.to_json)
  handle_template_response(response)
end

def delete_template(name)
  response = HTTParty.delete("#{template_account_path}/message_templates?name=#{CGI.escape(name)}",
                             headers: api_headers)
  handle_template_response(response)
end
```

`handle_template_response` devolve `[success_boolean, parsed_body]`. **Não pode
usar `process_response`** (`whatsapp_cloud_service.rb:114`): aquele método loga o
erro e devolve `nil`, o que apagaria a mensagem da Meta que o usuário precisa ver.

`business_account_path` está fixado em `v14.0`. Criação de template exige `v16.0`
ou superior. Adicionar um `template_account_path` em `v20.0` usado só pelos
métodos de template, deixando `business_account_path` e `phone_id_path` intactos
para não regredir envio de mensagem nem `sync_templates`.

### `Whatsapp::TemplateBuilder`

Recebe params planos do controller e devolve o payload da Meta. Concentra a única
lógica não trivial da feature:

- extrai as variáveis `{{n}}` do corpo
- rejeita sequência com buraco (`{{1}}` e `{{3}}` sem `{{2}}`)
- rejeita quantidade de exemplos diferente da quantidade de variáveis
- valida o nome contra `^[a-z0-9_]+$`
- monta `components` com `example.body_text` quando há variáveis

Payload resultante:

```json
{
  "name": "boas_vindas",
  "language": "pt_BR",
  "category": "UTILITY",
  "components": [
    { "type": "BODY",
      "text": "Olá {{1}}, seu pedido {{2}} foi enviado.",
      "example": { "body_text": [["Pedro", "1234"]] } }
  ]
}
```

### `Channel::Whatsapp`

```ruby
delegate :create_template, :delete_template, to: :provider_service
```

Após criação ou exclusão bem-sucedida o controller chama `sync_templates` inline,
para a resposta já conter o template novo com status `PENDING`.

### `Api::V1::Accounts::Channels::WhatsappTemplatesController`

Rotas dentro do `namespace :channels` existente (`config/routes.rb:90`):

```ruby
resources :whatsapp_templates, only: [:create, :destroy]
```

Sem `index`: a lista já chega ao front pelo serializer da inbox. Em `destroy`, o
`:id` da rota é o **nome** do template (a Meta exclui por nome, não por id);
nomes casam `^[a-z0-9_]+$`, então são seguros na URL.

Responsabilidades:

1. Achar a inbox por `params[:inbox_id]` no escopo de `Current.account`
2. `authorize @inbox, :update?` — reusa `InboxPolicy`, que já exige administrador.
   Nenhuma policy nova.
3. Rejeitar com 422 se o canal não for `Channel::Whatsapp` com provider
   `whatsapp_cloud`
4. Passar os params pelo `TemplateBuilder`; erro de validação vira 422
5. Chamar o canal; erro da Meta vira 422 com a mensagem original

Params aceitos: `inbox_id`, `name`, `language`, `category`, `body`, `examples[]`.

### Erros

A mensagem de erro da Meta sobe crua para o usuário (ex.: `Template name already
exists`), sem tradução. Traduzir esconderia o motivo real e viraria ticket de
suporte.

## Frontend

1. **`app/javascript/dashboard/api/channel/whatsappTemplates.js`** — segue
   `twilioChannel.js`: `ApiClient('channels/whatsapp_templates', { accountScoped: true })`
   com `create(payload)` e `delete({ inboxId, name })`.
2. **`settingsPage/WhatsappTemplatesPage.vue`** — irmão de `ConfigurationPage.vue`.
   Lista lendo o getter existente `inboxes/getWhatsAppTemplates`, sem estado novo
   no store. Colunas: nome, idioma, categoria, badge de status (`APPROVED` verde,
   `PENDING` âmbar, `REJECTED` vermelho) e botão excluir.
3. **`WhatsappTemplateForm.vue`** — modal com nome (lowercase forçado,
   `^[a-z0-9_]+$`), idioma (select), categoria (UTILITY / MARKETING /
   AUTHENTICATION) e textarea do corpo. Ao digitar `{{1}}`, `{{2}}`, aparece um
   campo de exemplo por variável — exemplo ausente é a causa mais comum de
   rejeição pela Meta.
4. **Aba em `Settings.vue`** — mesmo padrão dos blocos condicionais já existentes
   no arquivo, gated por `isAWhatsAppCloudChannel`. 360dialog e Twilio não veem a
   aba.
5. **Pós-criação** — re-fetch da inbox; o backend já rodou `sync_templates`, então
   o template aparece como `PENDING`. Toast informa que a aprovação da Meta leva
   de minutos a 24h.
6. **Exclusão** — modal de confirmação simples, no padrão do resto do Chatwoot.
   Excluir template não afeta histórico de conversa.
7. **i18n** — chaves novas em `WHATSAPP_TEMPLATES.SETTINGS.*`, nos arquivos `en` e
   `pt_BR`.

## Testes

- **`spec/services/whatsapp/template_builder_spec.rb`** — extração de `{{n}}`,
  sequência com buraco, contagem de exemplos divergente, nome inválido, payload
  final com e sem variáveis.
- **`spec/services/whatsapp/providers/whatsapp_cloud_service_spec.rb`** — dois
  casos novos com webmock: resposta 200 e resposta 400 da Meta.
- **`spec/controllers/api/v1/accounts/channels/whatsapp_templates_controller_spec.rb`**
  — agente recebe 403, administrador cria com sucesso, canal 360dialog recebe 422,
  erro da Meta vira 422 com a mensagem original.

Sem teste de componente Vue: o formulário não tem regra própria, toda a validação
vive no builder.

## Pré-requisito operacional

O token do canal precisa do escopo `whatsapp_business_management`. Verificação:

```bash
curl "https://graph.facebook.com/v20.0/debug_token?input_token=$TK&access_token=$TK"
```

Sem esse escopo a Meta responde 403 e a feature inteira não funciona.
