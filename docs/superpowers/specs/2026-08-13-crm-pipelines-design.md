# CRM: múltiplas pipelines e gestão de etapas

Data: 2026-08-13

## Problema

O CRM já tem deals, etapas e board kanban, mas as etapas (`deal_stages`) são uma
lista única por conta. Não há como manter mais de um funil, e a gestão de etapas
vive numa tela crua em Settings.

Este design adiciona pipelines (funis isolados, cada um com suas próprias etapas)
e move a gestão de etapas para um modal acessível a partir do board.

## Decisões

| Questão | Decisão |
| --- | --- |
| O que é uma pipeline | Funil isolado, com etapas próprias. O board mostra um funil por vez. |
| Pipeline do deal | Derivada da etapa. `deals` não ganha coluna. |
| Quem gerencia | Administrador e agente. |
| Onde gerenciar etapas | Modal a partir do board. A tela em Settings é removida. |
| Dados existentes | Migração cria "Funil padrão" por conta e move as etapas atuais para ele. |
| Mover deal entre funis | Sim, pelo seletor de funil no formulário/drawer do deal. |
| Excluir funil com deals | Bloqueado, com erro 422 — mesma regra que etapa com deals já usa. |
| Ganho/Perdido | Todo funil novo nasce com as etapas padrão, incluindo Ganho e Perdido. Não pode ficar sem elas. |

## Modelo de dados

Nova tabela `pipelines`:

- `account_id` (bigint, not null)
- `name` (string, not null)
- `position` (integer, not null, default 0)
- timestamps
- índice `[account_id, position]`

`deal_stages` ganha `pipeline_id` (bigint, not null) com índice
`[pipeline_id, position]`. O índice `[account_id, position]` é removido, já que a
ordenação passa a ser por funil.

`deals` não muda. A pipeline de um deal é a pipeline da sua etapa.

### Migração

Uma migration, três passos:

1. cria `pipelines`;
2. adiciona `deal_stages.pipeline_id` permitindo nulo e faz o backfill: para cada
   conta que já tem etapas, cria a pipeline `"Funil padrão"` e aponta as etapas
   dessa conta para ela;
3. aplica `change_column_null(:deal_stages, :pipeline_id, false)`, cria o índice
   novo e remove o antigo.

O backfill é idempotente por conta e roda em transação. Conta sem etapas não gera
nada — o funil padrão nasce na primeira visita ao board.

### Models

`Pipeline`:

- `belongs_to :account`
- `has_many :deal_stages, dependent: :destroy`
- valida presença de `name`
- `after_create` semeia `DealStage::DEFAULT_STAGES` — é o que garante Ganho e
  Perdido em todo funil novo
- `Pipeline.seed_default(account)` substitui `DealStage.seed_defaults(account)`:
  cria o funil padrão sob lock de conta se a conta ainda não tiver nenhum

`DealStage`:

- `belongs_to :pipeline`
- não pode ser excluída se for a última etapa `won` ou a última `lost` do seu
  funil (soma-se à regra que já existe: etapa com deals não é excluída)

`Deal` não muda. Mover um deal entre funis é movê-lo para uma etapa de outro
funil; `move_to!` e `associations_belong_to_account` já cobrem isso.

## API

Rotas novas em `config/routes.rb`, dentro do escopo de conta:

```ruby
resources :pipelines, only: [:index, :create, :update, :destroy]
```

`Api::V1::Accounts::PipelinesController`:

- `index` — funis da conta, ordenados por `position`. Chama
  `Pipeline.seed_default(Current.account)` para garantir pelo menos um.
- `create` / `update` — `name` e `position`.
- `destroy` — se existir qualquer deal nas etapas do funil, responde 422 com
  `{ error:, deals_count: }`, no mesmo formato de `deal_stages#destroy`. Sem
  deals, apaga o funil e suas etapas.

`Api::V1::Accounts::DealStagesController` continua no nível da conta:

- `index` passa a exigir `pipeline_id` e retorna só as etapas daquele funil;
- `create` passa a exigir `pipeline_id`;
- `reorder` restringe a reordenação às etapas do funil informado.

`Api::V1::Accounts::DealsController#board` aceita `pipeline_id`. Sem o parâmetro,
usa o primeiro funil da conta.

`PipelinePolicy` (novo) e `DealStagePolicy` (existente): `create`, `update`,
`destroy` e `reorder` liberados para administrador e agente. O escopo de conta
continua vindo de `ApplicationPolicy`.

Views jbuilder: `_pipeline.json.jbuilder` e as views de index/show/create/update
do controller novo, espelhando o que `deal_stages` já tem.

## Frontend

Arquivos novos:

- `dashboard/api/pipelines.js` e `dashboard/store/modules/pipelines.js`,
  espelhando `dealStages`
- `crm/components/PipelineManagerDialog.vue`
- `crm/components/StageManagerDialog.vue`
- `crm/components/StageFormDialog.vue`

`DealsBoardPage.vue`:

- header ganha seletor de funil e botão "Gerenciar etapas"
- o funil selecionado vive na query da rota (`?pipeline_id=`): o link é
  compartilhável e sobrevive a refresh, sem estado novo em localStorage
- trocar de funil redispara `deals/fetchBoard` com o `pipeline_id`

`PipelineManagerDialog.vue`: lista de funis com renomear e excluir, mais "Novo
funil".

`StageManagerDialog.vue`: lista de etapas com bolinha de cor, nome, contador de
deals, setas de ordem, lápis e lixeira, e rodapé "+ Nova etapa". As setas chamam
`dealStages/reorder` trocando dois ids na lista. O lápis abre
`StageFormDialog.vue`: campo Nome mais paleta fixa de dez cores em bolinhas, com
Cancelar e Salvar.

A paleta fixa substitui o `<input type="color">` de hoje e vira uma constante
compartilhada com `DealColumn`.

Os dois modais usam `components-next/dialog/Dialog.vue` e as actions de store que
já existem — o CRUD de etapa é reembalado, não reescrito.

`DealFormDialog.vue` e `DealDetailsTab.vue` ganham um seletor de funil acima do
seletor de etapa; trocar o funil recarrega as etapas daquele funil. É por aí que
um deal muda de pipeline, e a mudança de etapa já é registrada por
`DealActivityLoggable`.

Removidos: `settings/dealStages/Index.vue`, `settings/dealStages/dealStages.routes.js`,
o spec correspondente e a entrada em `settings.routes.js`.

## i18n

`CRM.PIPELINE.*` e `CRM.STAGES.*` entram em `en/crm.json`; `CRM.SETTINGS.*` migra
para `CRM.STAGES.*`. `pt_BR/crm.json` é atualizado junto, porque o repo já mantém
essa cópia. Demais idiomas seguem por Crowdin.

## Riscos

O único ponto sem volta é a migração. O backfill roda em transação e é idempotente
por conta.

Se alguém apaga uma etapa enquanto outra pessoa tem o board aberto, o drag falha
com erro. É o comportamento de hoje; nada novo é adicionado para tratá-lo.

## Fora de escopo

- Pipeline amarrada a inbox ou time, e roteamento automático de deals
- Arquivamento de funil (a exclusão é bloqueada, não há estado arquivado)
- Relatórios por funil
