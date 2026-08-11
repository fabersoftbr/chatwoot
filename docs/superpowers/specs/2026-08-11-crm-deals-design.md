# Camada de vendas (Deals) no Chatwoot — design

Data: 2026-08-11
Base: Chatwoot 3.14.1, branch `develop`

## Problema

O Chatwoot hoje registra conversas e contatos, mas não registra **negociação**. Não existe funil, estágio, valor, temperatura nem trilha de ações comerciais. Um agente que vende pelo WhatsApp não tem onde responder "quantos negócios estão em contrato enviado" nem "por que esse cliente parou de responder".

O que já existe e será reusado: `Contact` (com `contact_type` visitor/lead/customer), `Note`, `CustomAttributeDefinition`, `Label`, `CustomFilter`, sistema de feature flags, políticas Pundit, store Vuex.

O que **não** existe: funil, estágios, kanban, timeline de atividades comerciais.

## Objetivo

Entregar uma camada de CRM de vendas dentro do Chatwoot: kanban de funil com estágios configuráveis, negócios com valor e temperatura, histórico de ações automático e manual, e presença do negócio no lugar onde o agente já trabalha — o painel da conversa.

## Decisões travadas

| Decisão | Escolha | Motivo |
|---|---|---|
| Modelagem | Entidade `Deal` separada do contato | Um cliente tem N negócios ao longo do tempo (recompra, upsell). Estágio no contato quebra no segundo negócio. |
| Estágios | Configuráveis por conta, **um** funil | Todo cliente quer renomear coluna. Múltiplos funis é YAGNI até existir demanda real. |
| Histórico | Automático + manual, tabela única | Evento de sistema responde "onde travou"; registro manual cobre ligação e reunião, que acontecem fora do chat. |
| Escopo v1 | Kanban + painel do negócio + settings de estágios + deals na conversa + próxima ação + aba no contato | Relatório de funil precisa de dado acumulado; fica pra v2. |

## Arquitetura

Feature de **core** (MIT), não enterprise. Segue o padrão de `macros`/`campaigns` de ponta a ponta:

```
app/models/deal.rb, deal_stage.rb, deal_activity.rb
app/policies/deal_policy.rb, deal_stage_policy.rb
app/controllers/api/v1/accounts/deals_controller.rb
                                 deal_stages_controller.rb
                                 deals/activities_controller.rb
app/views/api/v1/accounts/deals/*.json.jbuilder
app/javascript/dashboard/api/deals.js, dealStages.js
app/javascript/dashboard/store/modules/deals.js, dealStages.js
app/javascript/dashboard/routes/dashboard/crm/**
```

Feature flag nova: **`deals`** em `config/features.yml`, `enabled: false` (liga por conta).

> A flag `crm` já existe e gateia o item **Contatos** do menu (`primaryMenu.js:32`, `useGoToCommandHotKeys.js:39`). Não reusar.

## Modelo de dados

### `deal_stages`

| coluna | tipo | notas |
|---|---|---|
| `account_id` | bigint | not null, index |
| `name` | string | not null |
| `color` | string | hex, default do tema |
| `position` | integer | not null |
| `stage_type` | integer (enum) | `open: 0, won: 1, lost: 2`, default `open` |

Índice: `(account_id, position)`.

**Estágios padrão** criados sob demanda no primeiro `GET /deal_stages` quando a conta não tem nenhum — idempotente, e já cobre contas existentes sem migration de seed:

1. Prospectado (`open`)
2. Em negociação (`open`)
3. Contrato enviado (`open`)
4. Ganho (`won`)
5. Perdido (`lost`)

### `deals`

| coluna | tipo | notas |
|---|---|---|
| `account_id` | bigint | not null |
| `contact_id` | bigint | not null |
| `deal_stage_id` | bigint | not null |
| `assignee_id` | bigint | FK `users`, nullable |
| `title` | string | not null |
| `description` | text | |
| `value_cents` | bigint | default 0 |
| `currency` | string | default `'BRL'`, por negócio |
| `temperature` | integer (enum) | `cold: 0, warm: 1, hot: 2`, default `warm` |
| `position` | integer | ordem dentro da coluna |
| `expected_close_on` | date | |
| `next_action_at` | datetime | |
| `next_action` | string | |
| `closed_at` | datetime | preenchido ao entrar em stage `won`/`lost` |
| `lost_reason` | text | |

Índices: `(account_id, deal_stage_id, position)`, `(contact_id)`, `(assignee_id)`, `(account_id, next_action_at)`.

Ganho/perdido é derivado de `deal_stage.stage_type` — **não** existe coluna `status` duplicando essa informação.

**Sem vínculo `deal ↔ conversation`.** O painel da conversa encontra os negócios pelo `contact_id` da conversa. Uma coluna `conversation_id` seria campo morto.

### `deal_activities`

| coluna | tipo | notas |
|---|---|---|
| `account_id` | bigint | not null |
| `deal_id` | bigint | not null |
| `user_id` | bigint | nullable — null = evento de sistema |
| `activity_type` | integer (enum) | ver abaixo |
| `content` | text | |
| `metadata` | jsonb | default `{}` |

Enum `activity_type`:
`stage_changed: 0, temperature_changed: 1, assigned: 2, note: 3, call: 4, meeting: 5, email: 6, created: 7`

Índice: `(deal_id, created_at DESC)`.

`metadata` guarda o antes/depois dos eventos automáticos, ex. `{"from_stage_id": 1, "to_stage_id": 2}`.

## Regras de negócio

1. Mover card = atualizar `deal_stage_id` + `position`. O `after_update_commit` do `Deal` grava sozinho `stage_changed`, `temperature_changed` e `assigned` quando os campos correspondentes mudam. O agente nunca escreve esses eventos à mão.
2. Entrar em estágio `won` ou `lost` → `closed_at = Time.current`. Sair de volta para um estágio `open` → `closed_at = nil`.
3. `lost_reason` é **obrigatório** quando o estágio destino é `lost`. A UI abre um modal pedindo o motivo antes de confirmar o drop; se o usuário cancelar, o card volta pra coluna de origem.
4. `next_action_at` no passado com negócio aberto (`stage_type == open`) = card destacado no kanban e alcançável pelo filtro `overdue`.
5. Reordenação: `position` é inteiro, recalculado apenas na(s) coluna(s) afetada(s) dentro de uma transação.
   `# ponytail: reindex O(n) por coluna; migrar pra rank fracionário se uma coluna passar de ~500 cards`
6. Permissões — `DealPolicy` espelha `ContactPolicy`: `agent` e `administrator` leem, criam e editam; `destroy` só `administrator`. `DealStagePolicy`: leitura para todos, escrita só `administrator`.

## API

Todas sob `/api/v1/accounts/:account_id`, dentro do bloco autenticado de `config/routes.rb`.

| Verbo | Rota | Notas |
|---|---|---|
| GET | `/deals/board` | Um request: estágios + os 25 primeiros negócios de cada coluna + contagem e soma de valor por coluna. É o que o kanban carrega. |
| GET | `/deals` | Paginado. Filtros: `stage_id`, `assignee_id`, `temperature`, `q`, `overdue`, `page`. Serve o scroll infinito por coluna. |
| POST | `/deals` | |
| GET/PATCH/DELETE | `/deals/:id` | |
| PATCH | `/deals/:id/move` | `{stage_id, position, lost_reason?}` — endpoint dedicado ao drag. |
| GET/POST | `/deals/:id/activities` | POST só aceita tipos manuais: `note`, `call`, `meeting`, `email`. |
| GET | `/contacts/:id/deals` | Alimenta a sidebar da conversa e a aba do contato. |
| GET/POST | `/deal_stages` | |
| PATCH/DELETE | `/deal_stages/:id` | admin |
| PATCH | `/deal_stages/reorder` | `{stage_ids: [...]}`, admin |

Apagar um estágio que ainda tem negócios retorna `422` com a contagem; a UI pede pra onde mover os negócios primeiro.

## Telas

### 1. Kanban — `/app/accounts/:accountId/crm`
Colunas = estágios, via `vuedraggable` (`^4.1.0`, já instalado — zero dependência nova).

- Cabeçalho da coluna: nome, contagem, soma dos valores.
- `DealCard.vue`: nome do contato, título, valor formatado, ícone de temperatura (🔥 quente / 🌡 morno / ❄ frio), avatar do responsável, badge vermelha quando `next_action_at` venceu.
- Barra de filtros: busca, responsável, temperatura, "atrasados".
- Item novo no `primaryMenu.js` com a flag `deals`.

### 2. Painel do negócio — rota filha `/crm/:dealId`
Drawer sobre o kanban, com URL própria para ser compartilhável.

- **Detalhes**: título, valor, moeda, temperatura, responsável, previsão de fechamento, próxima ação, descrição — edição inline.
- **Histórico**: timeline de `deal_activities` (sistema e manual misturados em ordem cronológica) + botões registrar ligação / reunião / e-mail / nota.
- **Contato**: resumo do contato (nome, e-mail, telefone, atributos) + link pro perfil completo e pras conversas.

### 3. Sidebar da conversa
Bloco "Negócios": negócios abertos do contato, com estágio, temperatura, valor, botão avançar estágio e "novo negócio" já preenchido com o contato da conversa. É o que faz o CRM ser usado — o agente não troca de tela.

### 4. Aba Negócios no perfil do contato
Reusa `DealCard`; lista abertos e fechados e mostra o total ganho.

### 5. Settings › Funil
Criar, renomear, colorir, reordenar e remover estágios. Só `administrator`.

i18n: `en` e `pt_BR`.

## Testes

**RSpec**
- `spec/models/deal_spec.rb` — validações, `lost_reason` obrigatório em estágio `lost`, `closed_at` setado e limpo, atividades automáticas geradas em mudança de estágio/temperatura/responsável.
- `spec/models/deal_stage_spec.rb` — reorder, bloqueio de destroy com negócios.
- `spec/controllers/api/v1/accounts/deals_controller_spec.rb` — index com filtros, `board`, `move`, escopo por conta, autorização.
- `spec/controllers/api/v1/accounts/deal_stages_controller_spec.rb` — seed sob demanda, escrita negada pra `agent`.
- `spec/policies/deal_policy_spec.rb`.

**Vitest**
- store `deals` (actions, mutations, uiFlags) seguindo o padrão de `store/modules/specs`.
- helper de cálculo de `position` no drop.
- render de `DealCard` (estados: atrasado, ganho, sem valor).

## Fora da v1 (deliberado)

Relatório de funil, múltiplos pipelines, custom attributes de negócio, automação/macro disparada por mudança de estágio, lembrete de follow-up por e-mail, importação CSV de negócios.

Nenhum deles exige refatorar as tabelas acima: relatório e automação leem `deal_activities`; múltiplos funis entram como `pipeline_id` em `deal_stages`; custom attributes entram pelo enum `attribute_model` de `CustomAttributeDefinition`.
