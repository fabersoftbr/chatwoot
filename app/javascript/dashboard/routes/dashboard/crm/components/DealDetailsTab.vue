<script setup>
import { reactive, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';

const props = defineProps({
  deal: { type: Object, required: true },
});

const emit = defineEmits(['update']);

const { t } = useI18n();
const stages = useMapGetter('deals/getStages');

const form = reactive({
  title: props.deal.title,
  description: props.deal.description,
  value_cents: props.deal.value_cents,
  temperature: props.deal.temperature,
  deal_stage_id: props.deal.deal_stage_id,
  expected_close_on: props.deal.expected_close_on,
  next_action: props.deal.next_action,
  next_action_at: props.deal.next_action_at,
});

watch(
  () => props.deal,
  deal => Object.assign(form, deal)
);

const save = field => emit('update', { [field]: form[field] });
</script>

<template>
  <div class="flex flex-col gap-3 p-4">
    <label class="text-xs text-slate-500">{{ t('CRM.FORM.TITLE') }}</label>
    <input v-model="form.title" class="input" @blur="save('title')" />

    <label class="text-xs text-slate-500">{{ t('CRM.FORM.STAGE') }}</label>
    <select
      v-model="form.deal_stage_id"
      class="input"
      @change="save('deal_stage_id')"
    >
      <option v-for="stage in stages" :key="stage.id" :value="stage.id">
        {{ stage.name }}
      </option>
    </select>

    <label class="text-xs text-slate-500">{{ t('CRM.FORM.VALUE') }}</label>
    <input
      v-model.number="form.value_cents"
      type="number"
      min="0"
      class="input"
      @blur="save('value_cents')"
    />

    <label class="text-xs text-slate-500">{{
      t('CRM.FORM.TEMPERATURE')
    }}</label>
    <select
      v-model="form.temperature"
      class="input"
      @change="save('temperature')"
    >
      <option value="hot">{{ t('CRM.TEMPERATURE.HOT') }}</option>
      <option value="warm">{{ t('CRM.TEMPERATURE.WARM') }}</option>
      <option value="cold">{{ t('CRM.TEMPERATURE.COLD') }}</option>
    </select>

    <label class="text-xs text-slate-500">{{
      t('CRM.FORM.EXPECTED_CLOSE_ON')
    }}</label>
    <input
      v-model="form.expected_close_on"
      type="date"
      class="input"
      @change="save('expected_close_on')"
    />

    <label class="text-xs text-slate-500">{{
      t('CRM.FORM.NEXT_ACTION')
    }}</label>
    <input
      v-model="form.next_action"
      class="input"
      @blur="save('next_action')"
    />

    <label class="text-xs text-slate-500">{{
      t('CRM.FORM.NEXT_ACTION_AT')
    }}</label>
    <input
      v-model="form.next_action_at"
      type="datetime-local"
      class="input"
      @change="save('next_action_at')"
    />

    <label class="text-xs text-slate-500">{{
      t('CRM.FORM.DESCRIPTION')
    }}</label>
    <textarea
      v-model="form.description"
      rows="4"
      class="input"
      @blur="save('description')"
    />
  </div>
</template>

<style scoped>
.input {
  @apply w-full p-2 text-sm border rounded border-slate-200 dark:border-slate-600 dark:bg-slate-900;
}
</style>
