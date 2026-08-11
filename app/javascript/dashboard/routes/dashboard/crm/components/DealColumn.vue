<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import draggable from 'vuedraggable';
import DealCard from './DealCard.vue';
import { formatDealValue } from '../helpers/position';

const props = defineProps({
  stage: { type: Object, required: true },
  deals: { type: Array, default: () => [] },
});

const emit = defineEmits(['move', 'select']);

const { t } = useI18n();

// The board caps each column at 25 loaded deals, so `props.deals` can be a
// partial view. `stage.deals_count` / `stage.deals_value_cents` come from
// the server and reflect every deal in the stage, loaded or not.
const dealsCount = computed(
  () => props.stage.deals_count ?? props.deals.length
);

// ponytail: currency is assumed uniform per account/stage — mixed-currency
// columns aren't summed server-side yet, so this only guards against
// mislabeling with a currency that isn't actually shared by the loaded
// cards. Upgrade path: a currency breakdown from the board endpoint.
const total = computed(() => {
  const currencies = new Set(props.deals.map(deal => deal.currency));
  const currency = currencies.size === 1 ? [...currencies][0] : 'BRL';
  return formatDealValue(props.stage.deals_value_cents ?? 0, currency);
});

// vuedraggable mutates the bound list; we ignore the mutation and let the store
// re-render from the server response instead.
const list = computed({
  get: () => props.deals,
  set: () => {},
});

const onDrop = event => {
  const change = event.added || event.moved;
  if (!change) return;

  emit('move', {
    dealId: change.element.id,
    stageId: props.stage.id,
    position: change.newIndex,
  });
};
</script>

<template>
  <div
    class="flex flex-col w-72 shrink-0 h-full rounded-lg bg-slate-25 dark:bg-slate-900"
  >
    <div class="flex items-center justify-between gap-2 px-3 py-2">
      <span class="flex items-center gap-2 text-sm font-medium">
        <span
          class="w-2 h-2 rounded-full"
          :style="{ backgroundColor: stage.color }"
        />
        {{ stage.name }}
        <span class="text-slate-500">{{ dealsCount }}</span>
      </span>
      <span class="text-xs text-slate-500">{{ total }}</span>
    </div>

    <draggable
      v-model="list"
      group="deals"
      item-key="id"
      class="flex flex-col gap-2 px-2 pb-4 overflow-y-auto grow"
      @change="onDrop"
    >
      <template #item="{ element }">
        <DealCard :deal="element" @click="emit('select', element)" />
      </template>
    </draggable>

    <p v-if="!deals.length" class="px-3 pb-3 text-xs text-slate-400">
      {{ t('CRM.EMPTY_STAGE') }}
    </p>
  </div>
</template>
