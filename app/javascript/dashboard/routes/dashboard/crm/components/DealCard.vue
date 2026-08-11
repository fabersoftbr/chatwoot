<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import { formatDealValue, isOverdue } from '../helpers/position';

const props = defineProps({
  deal: { type: Object, required: true },
});

defineEmits(['click']);

const { t } = useI18n();

const TEMPERATURE_ICON = { hot: '🔥', warm: '🌡️', cold: '❄️' };

const formattedValue = computed(() =>
  formatDealValue(props.deal.value_cents, props.deal.currency)
);
const overdue = computed(() => isOverdue(props.deal));
</script>

<template>
  <button
    class="flex flex-col w-full gap-1 p-3 text-left border rounded-lg bg-white dark:bg-slate-800 border-slate-100 dark:border-slate-700 hover:border-woot-400"
    @click="$emit('click', deal)"
  >
    <div class="flex items-start justify-between w-full gap-2">
      <span class="text-sm font-medium text-slate-900 dark:text-slate-100">
        {{ deal.title }}
      </span>
      <span :title="t(`CRM.TEMPERATURE.${deal.temperature.toUpperCase()}`)">
        {{ TEMPERATURE_ICON[deal.temperature] }}
      </span>
    </div>

    <span class="text-xs text-slate-600 dark:text-slate-400">
      {{ deal.contact.name }}
    </span>

    <div class="flex items-center justify-between w-full gap-2 mt-1">
      <span class="text-xs font-medium text-slate-800 dark:text-slate-200">
        {{ formattedValue || t('CRM.CARD.NO_VALUE') }}
      </span>
      <Avatar
        v-if="deal.assignee"
        :name="deal.assignee.name"
        :src="deal.assignee.thumbnail"
        :size="20"
      />
    </div>

    <span
      v-if="overdue"
      class="px-1.5 py-0.5 mt-1 text-xs rounded bg-red-50 text-red-700 dark:bg-red-900 dark:text-red-100"
    >
      {{ t('CRM.CARD.OVERDUE') }} · {{ deal.next_action }}
    </span>
  </button>
</template>
