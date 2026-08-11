<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { formatDealValue } from 'dashboard/routes/dashboard/crm/helpers/position';
import DealCard from 'dashboard/routes/dashboard/crm/components/DealCard.vue';
import DealFormDialog from 'dashboard/routes/dashboard/crm/components/DealFormDialog.vue';

const props = defineProps({
  contactId: { type: Number, required: true },
});

const { t } = useI18n();
const store = useStore();
const router = useRouter();

const deals = ref([]);
const dealFormRef = ref(null);
// `deals/getStages` is the module DealFormDialog (rendered below) also
// reads for its stage dropdown, so this is the one module we populate and
// consume here — `dealStages/get` writes into a different, unrelated store.
const stages = useMapGetter('deals/getStages');
const accountId = useMapGetter('getCurrentAccountId');

const load = async () => {
  try {
    deals.value = await store.dispatch('deals/fetchByContact', props.contactId);
  } catch (error) {
    // fetchByContact rejects on API errors (via throwErrorMessage); swallow
    // it here so a transient failure doesn't surface as an unhandled
    // rejection in a sidebar that mounts on every conversation.
    deals.value = [];
  }
};

onMounted(async () => {
  if (!stages.value.length) {
    try {
      // ponytail: fetchBoard is a full board-shaped fetch (every stage plus
      // up to 25 deals per column) used here only to read stage names; the
      // guard above keeps it to once per session. Upgrade path: a
      // stages-only action on the `deals` module if this ever shows up hot.
      await store.dispatch('deals/fetchBoard', {});
    } catch (error) {
      // Same rationale as load(): don't let a failed stage fetch throw.
    }
  }
  load();
});

watch(
  () => props.contactId,
  (newId, oldId) => {
    if (newId !== oldId) load();
  }
);

const openStageIds = computed(() =>
  stages.value
    .filter(stage => stage.stage_type === 'open')
    .map(stage => stage.id)
);

const isOpenDeal = deal => openStageIds.value.includes(deal.deal_stage_id);

// Open deals first, then closed (won/lost); within each group, ascending by
// id so the order is stable across re-fetches instead of depending on
// whatever order the API happens to return.
const sortedDeals = computed(() =>
  [...deals.value].sort((a, b) => {
    const aOpen = isOpenDeal(a) ? 0 : 1;
    const bOpen = isOpenDeal(b) ? 0 : 1;
    return aOpen !== bOpen ? aOpen - bOpen : a.id - b.id;
  })
);

const nextStageId = deal => {
  // A deal must currently be in an open stage to have a "next" stage — a
  // closed deal isn't in the `ordered` (open-only) list below, so without
  // this guard `findIndex` returns -1 and `ordered[-1 + 1]` would resolve
  // to the FIRST open stage, wrongly offering to advance a closed deal.
  if (!isOpenDeal(deal)) return null;

  const ordered = stages.value.filter(stage => stage.stage_type === 'open');
  const index = ordered.findIndex(stage => stage.id === deal.deal_stage_id);
  return ordered[index + 1]?.id ?? null;
};

const nextStageName = deal =>
  stages.value.find(stage => stage.id === nextStageId(deal))?.name ?? '';

const advance = async deal => {
  const stageId = nextStageId(deal);
  if (!stageId) return;

  // Always moving to the next OPEN stage, so `deals/move` never needs a
  // `lostReason` here.
  await store.dispatch('deals/move', { id: deal.id, stageId, position: 0 });
  load();
};

const wonDeals = computed(() => {
  const wonStageIds = stages.value
    .filter(stage => stage.stage_type === 'won')
    .map(stage => stage.id);

  return deals.value.filter(deal => wonStageIds.includes(deal.deal_stage_id));
});

// wonTotal sums raw cents regardless of currency; wonCurrencies below is
// what decides whether that sum is safe to show as a single formatted
// figure (see the template).
const wonTotal = computed(() =>
  wonDeals.value.reduce((sum, deal) => sum + deal.value_cents, 0)
);

const wonCurrencies = computed(() => [
  ...new Set(wonDeals.value.map(deal => deal.currency)),
]);

// ponytail: won deals in more than one currency can't be summed into one
// honest figure, so the total is hidden rather than mislabeled with a
// single currency. Upgrade path: a per-currency subtotal list if mixed
// currencies turn out to be common.
const wonTotalCurrency = computed(() =>
  wonCurrencies.value.length === 1 ? wonCurrencies.value[0] : null
);

const openDealBoard = deal => {
  // Same router the CRM board itself uses to open the drawer for a deal
  // (see DealsBoardPage.vue's onSelect) — an in-SPA transition, not a
  // full-page reload.
  router.push({
    name: 'deal_details',
    params: { accountId: accountId.value, dealId: deal.id },
  });
};
</script>

<template>
  <div
    class="flex flex-col gap-2 p-3 border-b border-slate-100 dark:border-slate-700"
  >
    <div class="flex items-center justify-between">
      <h4 class="text-sm font-medium">{{ t('CRM.CONTACT_PANEL.TITLE') }}</h4>
      <button class="text-xs text-woot-600" @click="dealFormRef.open()">
        {{ t('CRM.CONTACT_PANEL.NEW') }}
      </button>
    </div>

    <div v-for="deal in sortedDeals" :key="deal.id" class="flex flex-col gap-1">
      <DealCard :deal="deal" @click="openDealBoard" />
      <button
        v-if="nextStageId(deal)"
        class="self-start text-xs text-woot-600"
        @click="advance(deal)"
      >
        &gt; {{ nextStageName(deal) }}
      </button>
    </div>

    <p v-if="!sortedDeals.length" class="text-xs text-slate-400">
      {{ t('CRM.CONTACT_PANEL.EMPTY') }}
    </p>

    <p
      v-if="wonTotal && wonTotalCurrency"
      class="text-xs font-medium text-slate-700 dark:text-slate-300"
    >
      {{ t('CRM.CONTACT_PANEL.TOTAL_WON') }}:
      {{ formatDealValue(wonTotal, wonTotalCurrency) }}
    </p>

    <DealFormDialog ref="dealFormRef" :contact-id="contactId" @created="load" />
  </div>
</template>
