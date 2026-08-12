<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import { formatDealValue, isOverdue } from '../helpers/position';

const props = defineProps({
  deal: { type: Object, required: true },
  // Board columns already group cards by stage, so showing the contact name
  // per card is what tells them apart — default true keeps the kanban
  // exactly as before. A single-contact list (the conversation sidebar)
  // passes showContact: false and a stageName instead, since the contact is
  // implied by the sidebar itself and repeating it on every row is noise.
  showContact: { type: Boolean, default: true },
  stageName: { type: String, default: '' },
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
    class="flex flex-col w-full gap-1 p-3 text-left border rounded-lg bg-n-solid-2 border-n-weak hover:border-n-brand"
    @click="$emit('click', deal)"
  >
    <div class="flex items-start justify-between w-full gap-2">
      <span class="text-sm font-medium text-n-slate-12">
        {{ deal.title }}
      </span>
      <span :title="t(`CRM.TEMPERATURE.${deal.temperature.toUpperCase()}`)">
        {{ TEMPERATURE_ICON[deal.temperature] }}
      </span>
    </div>

    <span v-if="showContact" class="text-xs text-n-slate-11">
      {{ deal.contact.name }}
    </span>
    <span v-else-if="stageName" class="text-xs text-n-slate-11">
      {{ stageName }}
    </span>

    <div class="flex items-center justify-between w-full gap-2 mt-1">
      <span class="text-xs font-medium text-n-slate-12">
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
      class="px-1.5 py-0.5 mt-1 text-xs rounded bg-n-ruby-9/10 text-n-ruby-11"
    >
      {{ t('CRM.CARD.OVERDUE') }} · {{ deal.next_action }}
    </span>
  </button>
</template>
