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

const total = computed(() =>
  formatDealValue(
    props.deals.reduce((sum, deal) => sum + deal.value_cents, 0),
    props.deals[0]?.currency || 'BRL'
  )
);

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
        <span class="text-slate-500">{{ deals.length }}</span>
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
