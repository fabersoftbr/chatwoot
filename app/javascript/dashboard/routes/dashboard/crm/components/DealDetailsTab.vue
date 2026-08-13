<script setup>
import { onMounted, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { centsToUnits, unitsToCents } from '../helpers/position';

const props = defineProps({
  deal: { type: Object, required: true },
});

const emit = defineEmits(['update']);

const { t } = useI18n();
const store = useStore();
const pipelines = useMapGetter('pipelines/getPipelines');
const stages = useMapGetter('dealStages/getStages');
const agents = useMapGetter('agents/getAgents');

const CURRENCIES = ['BRL', 'USD', 'EUR'];

const form = reactive({
  title: props.deal.title,
  description: props.deal.description,
  temperature: props.deal.temperature,
  deal_stage_id: props.deal.deal_stage_id,
  assignee_id: props.deal.assignee_id,
  currency: props.deal.currency,
  expected_close_on: props.deal.expected_close_on,
  next_action: props.deal.next_action,
  next_action_at: props.deal.next_action_at,
});

const valueInput = ref(centsToUnits(props.deal.value_cents));
const pipelineId = ref(props.deal.pipeline_id);

const save = field => emit('update', { [field]: form[field] });
const saveValue = () =>
  emit('update', { value_cents: unitsToCents(valueInput.value) });
const saveAssignee = () =>
  emit('update', { assignee_id: form.assignee_id || null });

const loadStages = async id => {
  pipelineId.value = id;
  await store.dispatch('dealStages/get', { pipelineId: id });
  // The selection may have moved on to another pipeline while this dispatch
  // was in flight — tell the caller whether it's still current.
  return pipelineId.value === id;
};

const changePipeline = async id => {
  const isCurrent = await loadStages(id);
  if (!isCurrent) return;
  form.deal_stage_id = stages.value[0]?.id ?? null;
  save('deal_stage_id');
};

watch(
  () => props.deal,
  deal => {
    Object.assign(form, deal);
    valueInput.value = centsToUnits(deal.value_cents);
    if (deal.pipeline_id !== pipelineId.value) loadStages(deal.pipeline_id);
  }
);

onMounted(() => {
  if (!agents.value.length) {
    store.dispatch('agents/get');
  }
  if (!pipelines.value.length) store.dispatch('pipelines/get');
  loadStages(props.deal.pipeline_id);
});
</script>

<template>
  <div class="flex flex-col gap-3 p-4">
    <label class="text-xs text-n-slate-11">{{ t('CRM.FORM.TITLE') }}</label>
    <input
      v-model="form.title"
      type="text"
      class="w-full !mb-0"
      @blur="save('title')"
    />

    <label class="text-xs text-n-slate-11">{{ t('CRM.PIPELINE.LABEL') }}</label>
    <select
      class="w-full !mb-0"
      :value="pipelineId"
      :aria-label="t('CRM.PIPELINE.LABEL')"
      @change="changePipeline(Number($event.target.value))"
    >
      <option
        v-for="pipeline in pipelines"
        :key="pipeline.id"
        :value="pipeline.id"
      >
        {{ pipeline.name }}
      </option>
    </select>

    <label class="text-xs text-n-slate-11">{{ t('CRM.FORM.STAGE') }}</label>
    <select
      v-model="form.deal_stage_id"
      class="w-full !mb-0"
      @change="save('deal_stage_id')"
    >
      <option v-for="stage in stages" :key="stage.id" :value="stage.id">
        {{ stage.name }}
      </option>
    </select>

    <label class="text-xs text-n-slate-11">{{ t('CRM.FORM.ASSIGNEE') }}</label>
    <select
      v-model="form.assignee_id"
      class="w-full !mb-0"
      :aria-label="t('CRM.FORM.ASSIGNEE')"
      @change="saveAssignee"
    >
      <option value="" />
      <option v-for="agent in agents" :key="agent.id" :value="agent.id">
        {{ agent.name }}
      </option>
    </select>

    <label class="text-xs text-n-slate-11">{{ t('CRM.FORM.CURRENCY') }}</label>
    <select
      v-model="form.currency"
      class="w-full !mb-0"
      :aria-label="t('CRM.FORM.CURRENCY')"
      @change="save('currency')"
    >
      <option v-for="currency in CURRENCIES" :key="currency" :value="currency">
        {{ currency }}
      </option>
    </select>

    <label class="text-xs text-n-slate-11">{{ t('CRM.FORM.VALUE') }}</label>
    <input
      v-model.number="valueInput"
      type="number"
      min="0"
      class="w-full !mb-0"
      @blur="saveValue"
    />

    <label class="text-xs text-n-slate-11">{{
      t('CRM.FORM.TEMPERATURE')
    }}</label>
    <select
      v-model="form.temperature"
      class="w-full !mb-0"
      @change="save('temperature')"
    >
      <option value="hot">{{ t('CRM.TEMPERATURE.HOT') }}</option>
      <option value="warm">{{ t('CRM.TEMPERATURE.WARM') }}</option>
      <option value="cold">{{ t('CRM.TEMPERATURE.COLD') }}</option>
    </select>

    <label class="text-xs text-n-slate-11">{{
      t('CRM.FORM.EXPECTED_CLOSE_ON')
    }}</label>
    <input
      v-model="form.expected_close_on"
      type="date"
      class="w-full !mb-0"
      @change="save('expected_close_on')"
    />

    <label class="text-xs text-n-slate-11">{{
      t('CRM.FORM.NEXT_ACTION')
    }}</label>
    <input
      v-model="form.next_action"
      type="text"
      class="w-full !mb-0"
      @blur="save('next_action')"
    />

    <label class="text-xs text-n-slate-11">{{
      t('CRM.FORM.NEXT_ACTION_AT')
    }}</label>
    <input
      v-model="form.next_action_at"
      type="datetime-local"
      class="w-full !mb-0"
      @change="save('next_action_at')"
    />

    <label class="text-xs text-n-slate-11">{{
      t('CRM.FORM.DESCRIPTION')
    }}</label>
    <textarea
      v-model="form.description"
      rows="4"
      class="w-full !mb-0 !h-auto"
      @blur="save('description')"
    />
  </div>
</template>
