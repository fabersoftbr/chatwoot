<script setup>
import { reactive, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';
import { useMapGetter } from 'dashboard/composables/store';
import { INBOX_TYPES } from 'dashboard/helper/inbox';

import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import TagMultiSelectComboBox from 'dashboard/components-next/combobox/TagMultiSelectComboBox.vue';
import CadenceStepFields from './CadenceStepFields.vue';

const emit = defineEmits(['submit', 'cancel']);

const { t } = useI18n();

const uiFlags = useMapGetter('cadences/getUIFlags');
const labels = useMapGetter('labels/getLabels');
const inboxes = useMapGetter('inboxes/getCadenceInboxes');
const getFilteredWhatsAppTemplates = useMapGetter(
  'inboxes/getFilteredWhatsAppTemplates'
);

const emptyStep = () => ({
  delay_days: 0,
  send_hour: '',
  send_minute: 0,
  weekday: '',
  content: '',
  template_name: '',
});

const state = reactive({
  title: '',
  inboxId: null,
  selectedAudience: [],
  steps: [emptyStep()],
});

const v$ = useVuelidate(
  {
    title: { required, minLength: minLength(1) },
    inboxId: { required },
    selectedAudience: { required },
  },
  state
);

const isCreating = computed(() => uiFlags.value.isCreating);

const mapToOptions = (items, valueKey, labelKey) =>
  items?.map(item => ({ value: item[valueKey], label: item[labelKey] })) ?? [];

const audienceList = computed(() => mapToOptions(labels.value, 'id', 'title'));
const inboxOptions = computed(() => mapToOptions(inboxes.value, 'id', 'name'));

const selectedInbox = computed(() =>
  inboxes.value?.find(inbox => inbox.id === state.inboxId)
);

// WhatsApp Cloud always sends outside Meta's 24 hour window, where only an approved template is
// accepted. Evolution has no window and no templates, so its steps are free text.
const isTemplateChannel = computed(
  () => selectedInbox.value?.channel_type === INBOX_TYPES.WHATSAPP
);

const templateOptions = computed(() => {
  if (!state.inboxId || !isTemplateChannel.value) return [];
  return getFilteredWhatsAppTemplates
    .value(state.inboxId)
    .filter(template => template.status?.toUpperCase() === 'APPROVED')
    .map(template => ({
      value: template.name,
      label: `${template.name} (${template.language || 'en'})`,
      template,
    }));
});

const hasCompleteSteps = computed(() =>
  state.steps.every(step =>
    isTemplateChannel.value ? step.template_name : step.content?.trim()
  )
);

const isSubmitDisabled = computed(
  () => v$.value.$invalid || !hasCompleteSteps.value
);

const updateStep = (index, step) => {
  state.steps.splice(index, 1, step);
};

const addStep = () => state.steps.push(emptyStep());
const removeStep = index => state.steps.splice(index, 1);

// Changing channel changes what a step may carry, so the half-written ones would not survive.
watch(
  () => state.inboxId,
  () => {
    state.steps = [emptyStep()];
  }
);

const buildStep = step => {
  const built = {
    delay_days: Number(step.delay_days) || 0,
    send_minute: Number(step.send_minute) || 0,
  };
  if (step.send_hour !== '' && step.send_hour !== null) {
    built.send_hour = Number(step.send_hour);
  }
  if (step.weekday !== '' && step.weekday !== null) {
    built.weekday = Number(step.weekday);
  }
  if (isTemplateChannel.value) {
    const option = templateOptions.value.find(
      item => item.value === step.template_name
    );
    built.template_params = {
      name: option?.template?.name,
      namespace: option?.template?.namespace,
      category: option?.template?.category,
      language: option?.template?.language,
      processed_params: { body: {} },
    };
  } else {
    built.content = step.content;
  }
  return built;
};

const handleSubmit = async () => {
  if (!(await v$.value.$validate())) return;

  emit('submit', {
    title: state.title,
    inbox_id: state.inboxId,
    audience: state.selectedAudience.map(id => ({ id, type: 'Label' })),
    steps: state.steps.map(buildStep),
  });
};
</script>

<template>
  <form class="flex flex-col gap-4" @submit.prevent="handleSubmit">
    <Input
      v-model="state.title"
      :label="t('CADENCE.FORM.TITLE.LABEL')"
      :placeholder="t('CADENCE.FORM.TITLE.PLACEHOLDER')"
    />

    <div class="flex flex-col gap-1">
      <label class="text-sm font-medium text-n-slate-12">
        {{ t('CADENCE.FORM.INBOX.LABEL') }}
      </label>
      <ComboBox
        v-model="state.inboxId"
        :options="inboxOptions"
        :placeholder="t('CADENCE.FORM.INBOX.PLACEHOLDER')"
      />
      <span v-if="selectedInbox" class="text-xs text-n-slate-11">
        {{
          isTemplateChannel
            ? t('CADENCE.FORM.INBOX.TEMPLATE_ONLY')
            : t('CADENCE.FORM.INBOX.FREE_TEXT')
        }}
      </span>
    </div>

    <div class="flex flex-col gap-1">
      <label class="text-sm font-medium text-n-slate-12">
        {{ t('CADENCE.FORM.AUDIENCE.LABEL') }}
      </label>
      <TagMultiSelectComboBox
        v-model="state.selectedAudience"
        :options="audienceList"
        :label="t('CADENCE.FORM.AUDIENCE.LABEL')"
        :placeholder="t('CADENCE.FORM.AUDIENCE.PLACEHOLDER')"
      />
      <span class="text-xs text-n-slate-11">
        {{ t('CADENCE.FORM.AUDIENCE.INFO') }}
      </span>
    </div>

    <div v-if="state.inboxId" class="flex flex-col gap-3">
      <span class="text-sm font-medium text-n-slate-12">
        {{ t('CADENCE.FORM.STEPS_TITLE') }}
      </span>
      <CadenceStepFields
        v-for="(step, index) in state.steps"
        :key="index"
        :step="step"
        :index="index"
        :is-template-channel="isTemplateChannel"
        :template-options="templateOptions"
        :can-remove="state.steps.length > 1"
        @update="updateStep(index, $event)"
        @remove="removeStep(index)"
      />
      <Button
        faded
        slate
        sm
        type="button"
        icon="i-lucide-plus"
        :label="t('CADENCE.FORM.ADD_STEP')"
        @click="addStep"
      />
    </div>

    <div class="flex items-center justify-between w-full gap-3">
      <Button
        variant="faded"
        color="slate"
        type="button"
        :label="t('CADENCE.FORM.BUTTONS.CANCEL')"
        class="w-full"
        @click="emit('cancel')"
      />
      <Button
        :label="t('CADENCE.FORM.BUTTONS.CREATE')"
        class="w-full"
        type="submit"
        :is-loading="isCreating"
        :disabled="isCreating || isSubmitDisabled"
      />
    </div>
  </form>
</template>
