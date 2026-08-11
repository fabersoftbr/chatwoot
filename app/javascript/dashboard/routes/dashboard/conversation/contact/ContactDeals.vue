<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { formatDealValue } from 'dashboard/routes/dashboard/crm/helpers/position';
import DealFormDialog from 'dashboard/routes/dashboard/crm/components/DealFormDialog.vue';

const props = defineProps({
  contactId: { type: Number, required: true },
});

const { t } = useI18n();
const store = useStore();

const deals = ref([]);
const dealFormRef = ref(null);
// `deals/getStages` is the module DealFormDialog (rendered below) also
// reads for its stage dropdown, so this is the one module we populate and
// consume here — `dealStages/get` writes into a different, unrelated store.
const stages = useMapGetter('deals/getStages');

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

const openDeals = computed(() => {
  const openStageIds = stages.value
    .filter(stage => stage.stage_type === 'open')
    .map(stage => stage.id);

  return deals.value.filter(deal => openStageIds.includes(deal.deal_stage_id));
});

const stageName = deal =>
  stages.value.find(stage => stage.id === deal.deal_stage_id)?.name ?? '';

const nextStageId = deal => {
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

    <div
      v-for="deal in openDeals"
      :key="deal.id"
      class="flex flex-col gap-1 p-2 rounded bg-slate-25 dark:bg-slate-900"
    >
      <span class="text-sm">{{ deal.title }}</span>
      <span class="text-xs text-slate-500">
        {{ stageName(deal) }} ·
        {{ t(`CRM.TEMPERATURE.${deal.temperature.toUpperCase()}`) }} ·
        {{ formatDealValue(deal.value_cents, deal.currency) }}
      </span>
      <button
        v-if="nextStageId(deal)"
        class="self-start text-xs text-woot-600"
        @click="advance(deal)"
      >
        &gt; {{ nextStageName(deal) }}
      </button>
    </div>

    <p v-if="!openDeals.length" class="text-xs text-slate-400">
      {{ t('CRM.CONTACT_PANEL.EMPTY') }}
    </p>

    <DealFormDialog ref="dealFormRef" :contact-id="contactId" @created="load" />
  </div>
</template>
