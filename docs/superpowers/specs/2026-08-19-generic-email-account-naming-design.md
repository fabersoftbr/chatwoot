# Nome de conta e branding a partir de e-mails genéricos

Data: 2026-08-19
Branch: `fix/generic-email-account-name` → PR #9 contra `main`

## Problema

Contas criadas no signup nascem chamadas "Gmail", "Outlook", "Hotmail". O nome sai
do domínio do e-mail, e o domínio de um provedor de caixa postal identifica o
serviço de e-mail, não a empresa que está se cadastrando.

O estrago não para no cadastro. O nome da conta semeia a inbox do web widget, o
título do widget, e o nome e o **slug** do portal do help center — este último é o
mais caro de desfazer, porque muda URL já publicada.

## Estado atual: onde o nome nasce do e-mail

| Ponto | O que faz |
|---|---|
| `app/javascript/v3/helpers/AuthHelper.js` | `capitalize(domain.split('.')[0])` → "Gmail" |
| `app/controllers/devise_overrides/omniauth_callbacks_controller.rb:84` | `extract_domain_without_tld` → "gmail" |
| `app/services/website_branding_service.rb` | faz fetch de `https://gmail.com` e extrai título, logo, cores |
| `enterprise/app/services/enterprise/website_branding_service.rb` | sobrescreve `perform` inteiro; consulta a Context.dev com o e-mail |
| `app/jobs/account/branding_enrichment_job.rb:12` | `account.name = result[:title]` — sobrescreve inclusive nome digitado |
| `app/controllers/api/v2/accounts_controller.rb` | não passa nome nenhum ao `AccountBuilder` |

E para onde ele vaza depois:

- `app/services/onboarding/web_widget_creation_service.rb:29` — `inboxes.create!(name: @account.name)`
- `app/services/onboarding/web_widget_creation_service.rb:67` — título do widget
- `enterprise/app/services/onboarding/help_center_creation_service.rb:49,119,127` — nome e slug do portal
- `enterprise/app/services/captain/llm/widget_tagline_service.rb`, `help_center_curation_service.rb`,
  `enterprise/app/services/onboarding/help_center_curator.rb` — alimentam prompts de LLM com a marca do provedor

### Três descobertas que mudam o desenho

**O overlay Enterprise anula um guard posto só no OSS.**
`Enterprise::WebsiteBrandingService#perform` substitui o método inteiro e só chama
`super` quando `CONTEXT_DEV_API_KEY` está ausente. Com a chave configurada, um guard
no `perform` do OSS nunca roda.

**`brand_info.email_provider` é dado morto hoje.**
Ele vem de `detect_email_provider`, um probe de MX, e `useDetectedChannels.js:57` o
usa para montar a linha de "conectar Gmail" no passo de inbox-setup — mas
`useDetectedChannels.js:87` filtra `channel.type !== 'email'` incondicionalmente, com
o comentário de que canais de e-mail ligam num PR futuro. O spec do arquivo documenta
o gate (`useDetectedChannels.spec.js:146`). Logo, cortar o enrichment inteiro para
domínio genérico não tira nada visível, e o service pode simplesmente devolver `nil`.

Quando o canal de e-mail for ligado, sobra uma assimetria: domínio corporativo hospedado
no Google vai sugerir Gmail, e conta `gmail.com` não vai sugerir nada. É custo aceito
aqui — carregar o campo agora seria carregar dado que ninguém lê.

**`Account.create!(name: '')` não é válido.**
`Api::V1::AccountsController#ensure_account_name` documenta que basta *um* entre
`account_name` e `user_full_name`, mas `AccountBuilder` repassa a string vazia para
um `accounts.name` que é `null: false` no schema e tem `validates :name, presence: true`
no model. O caminho nunca tinha sido exercitado porque o form sempre mandava um nome
derivado do domínio. Mandar `''` torna o caminho alcançável e o signup estoura com
"Name can't be blank".

Superfície real: `WebsiteBrandingService` tem um único chamador em produção (o job), e
o job tem um único chamador (`accounts_controller.rb:78`). O signup por Google **não**
enfileira enrichment — aquele caminho só tinha o bug do nome.

## Decisões

1. **Nome de conta para domínio genérico: o nome do usuário.** Conta vazia de verdade é
   impossível sem mexer no model, e não vale a pena. `kajiyapedro@gmail.com` vira conta
   "Kajiyapedro". Sem flag de "provisório" — o onboarding pré-preenche esse valor num
   campo editável e obrigatório, e quem quiser corrige ali.
2. **Sem backfill.** Contas já gravadas como "Gmail" ficam como estão. O objetivo aqui é
   estancar para contas novas; renomear as antigas não conserta a inbox e o slug do
   portal que já saíram delas.
3. **`Api::V2::AccountsController` entra no PR.** É a mesma classe de bug — chamador
   violando o contrato do `AccountBuilder`.

## Desenho

### 1. Uma regra, um lugar

`EmailHelper` ganha `GENERIC_EMAIL_DOMAINS` e `generic_email_domain?(email)`. É onde já
mora `extract_domain_without_tld` e já é incluído pelo controller do OAuth.

A lista fica duplicada em `AuthHelper.js` porque o signup decide o nome antes de existir
requisição. São 21 domínios estáveis; um mecanismo de compartilhamento custaria mais que
a duplicata.

Domínios: gmail.com, googlemail.com, outlook.com, outlook.com.br, hotmail.com,
hotmail.com.br, live.com, msn.com, yahoo.com, yahoo.com.br, icloud.com, me.com, aol.com,
proton.me, protonmail.com, uol.com.br, bol.com.br, terra.com.br, ig.com.br, globo.com,
r7.com.

### 2. Enrichment não roda para domínio genérico

Os dois `perform` retornam `nil` cedo, sem requisição nenhuma para fora — nem o scrape
do OSS nem a chamada à Context.dev do EE.

O guard fica no topo de `WebsiteBrandingService#perform` **e** no topo de
`Enterprise::WebsiteBrandingService#perform`. Duas linhas no overlay, seguindo a
convenção dele.

Foi considerado extrair um template method para ter um guard só, mas o `perform` do EE
tem rescue próprio e monta um hash com chaves que o OSS não tem (`industries`, `stock`,
`is_nsfw`). Como o fork replaya commits sobre árvores novas do upstream, churn em
`enterprise/` vira dor de merge que não se paga aqui.

Consequências, todas desejadas:

- `branding_enrichment_job:5` recebe `nil`, loga e sai antes de tocar em `account.name`
- `brand_info` nunca é gravado, então widget e portal caem no fallback `@account.name`
  e nenhum logo do provedor entra na conta

### 3. Nome da conta

- `AuthHelper.getCredentialsFromEmail` devolve `accountName: ''` para domínio genérico;
  `fullName` não muda
- `omniauth_callbacks_controller` deixa `account_name` nil para domínio genérico
- `AccountBuilder#account_name` passa a ser `@account_name.presence || user_full_name`,
  honrando o contrato que `ensure_account_name` documenta — vale para os quatro
  chamadores do builder
- `Api::V2::AccountsController#create` repassa `account_params[:account_name]` e
  `account_params[:user_full_name]`, ambos já permitidos em `account_params`

### 4. Onboarding

`accountName` deixa de ser `computed` read-only e vira `ref` semeado do `currentAccount`,
com watch para o nome que chega quando o enrichment termina (ActionCable
`account.enrichment_completed`), sem sobrescrever o que o usuário já digitou. Renderiza
como `InlineInput` no lugar do `<span>`, com o logo ao lado. Ganha `required` em
`validationRules` e `animate-shake` no mesmo padrão do campo `website`. String nova só em
`en.json`.

## Estado da implementação

Já commitado no branch (`2639584ad`, `c4b1bceee`), antes deste desenho existir:

- `EmailHelper` com a lista e o predicado
- `AuthHelper.js` e seu spec
- `omniauth_callbacks_controller` deixando `account_name` nil
- `AccountBuilder#account_name` com o fallback
- Onboarding `Index.vue` com `InlineInput`, `required` e a string em `en.json`
- Guard `return nil` no `WebsiteBrandingService#perform` do OSS

Falta:

1. Mesmo guard no topo de `Enterprise::WebsiteBrandingService#perform`
2. `Api::V2::AccountsController#create` repassando `account_name`/`user_full_name`
3. Todos os specs listados abaixo

## Fora de escopo

- Backfill das contas já gravadas como "Gmail"/"Outlook"
- Validação de domínio na tela de signup
- Renomear inbox e portal existentes; mudar slug de portal
- Qualquer mexida em SMTP ou entrega de e-mail

## Testes

JavaScript:

- `app/javascript/v3/helpers/specs/AuthHelper.spec.js` — domínio genérico devolve
  `accountName` vazio, com caso de caixa mista (`Hotmail.com.BR`); domínio corporativo
  segue capitalizando. **Já escrito, passando.**

Ruby:

- `spec/helpers/email_helper_spec.rb` — `generic_email_domain?` com caixa mista, espaço
  em volta e subdomínio (`mail.gmail.com` não é genérico)
- `spec/services/website_branding_service_spec.rb` — domínio genérico devolve `nil` e
  **não** chama `SafeFetch`
- `spec/enterprise/services/enterprise/website_branding_service_spec.rb` — mesma coisa
  com Context.dev habilitado: nenhuma requisição sai para o endpoint
- `spec/builders/account_builder_spec.rb` — `account_name` vazio com `user_full_name`
  presente cria conta com o nome do usuário
- `spec/controllers/api/v2/accounts_controller_spec.rb` — o spec atual casa os argumentos
  do `AccountBuilder` de forma exata (`params.except(:password).merge(...)`), então
  precisa ser atualizado junto. Ele também stuba o builder inteiro, e é por isso que o
  `Account.create!(name: '')` nunca apareceu no CI; o caso novo não pode stubar o builder

## Risco conhecido de verificação

Não há toolchain Ruby nesta máquina: rbenv ausente, `/usr/bin/ruby` é 2.6, falta bundler
2.5.16. Os specs Ruby serão escritos sem execução local e quem verifica é o CI. O mesmo
vale para `bundle exec rubocop -a`, exigido pelo CLAUDE.md antes de commitar. Para
verificar localmente antes do merge:
`rbenv install $(cat .ruby-version) && bundle install`.
