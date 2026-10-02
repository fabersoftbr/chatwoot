<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import TextArea from 'next/textarea/TextArea.vue';

const props = defineProps({
  step: { type: Object, required: true },
  index: { type: Number, required: true },
  isTemplateChannel: { type: Boolean, default: false },
  templateOptions: { type: Array, default: () => [] },
  canRemove: { type: Boolean, default: true },
});

const emit = defineEmits(['update', 'remove']);

const { t } = useI18n();

// Meta counts weekdays the way Ruby's Time#wday does, 0 for Sunday, so the same number travels
// from this select into Cadence#deliver_at_for untouched.
const weekdayOptions = computed(() => [
  { value: '', label: t('CADENCE.FORM.STEP.WEEKDAY.ANY') },
  ...[0, 1, 2, 3, 4, 5, 6].map(day => ({
    value: String(day),
    label: t(`CADENCE.FORM.STEP.WEEKDAY.DAYS.${day}`),
  })),
]);

const update = (key, value) => emit('update', { ...props.step, [key]: value });
</script>

<template>
  <div class="flex flex-col gap-3 p-4 border rounded-lg border-n-weak">
    <div class="flex items-center justify-between">
      <span class="text-sm font-medium text-n-slate-12">
        {{ t('CADENCE.FORM.STEP.TITLE', { position: index + 1 }) }}
      </span>
      <Button
        v-if="canRemove"
        faded
        slate
        xs
        type="button"
        icon="i-lucide-trash-2"
        :label="t('CADENCE.FORM.STEP.REMOVE')"
        @click="emit('remove')"
      />
    </div>

    <div class="grid grid-cols-3 gap-2">
      <Input
        :model-value="step.delay_days"
        type="number"
        min="0"
        :label="t('CADENCE.FORM.STEP.DELAY_DAYS.LABEL')"
        @update:model-value="update('delay_days', $event)"
      />
      <Input
        :model-value="step.send_hour"
        type="number"
        min="0"
        max="23"
        :label="t('CADENCE.FORM.STEP.SEND_HOUR.LABEL')"
        :placeholder="t('CADENCE.FORM.STEP.SEND_HOUR.PLACEHOLDER')"
        @update:model-value="update('send_hour', $event)"
      />
      <Input
        :model-value="step.send_minute"
        type="number"
        min="0"
        max="59"
        :label="t('CADENCE.FORM.STEP.SEND_MINUTE.LABEL')"
        @update:model-value="update('send_minute', $event)"
      />
    </div>

    <div class="flex flex-col gap-1">
      <label class="text-sm font-medium text-n-slate-12">
        {{ t('CADENCE.FORM.STEP.WEEKDAY.LABEL') }}
      </label>
      <ComboBox
        :model-value="step.weekday ?? ''"
        :options="weekdayOptions"
        @update:model-value="update('weekday', $event)"
      />
    </div>

    <div v-if="isTemplateChannel" class="flex flex-col gap-1">
      <label class="text-sm font-medium text-n-slate-12">
        {{ t('CADENCE.FORM.STEP.TEMPLATE.LABEL') }}
      </label>
      <ComboBox
        :model-value="step.template_name"
        :options="templateOptions"
        :placeholder="t('CADENCE.FORM.STEP.TEMPLATE.PLACEHOLDER')"
        @update:model-value="update('template_name', $event)"
      />
      <span class="text-xs text-n-slate-11">
        {{ t('CADENCE.FORM.STEP.TEMPLATE.INFO') }}
      </span>
    </div>

    <TextArea
      v-else
      :model-value="step.content"
      :label="t('CADENCE.FORM.STEP.CONTENT.LABEL')"
      :placeholder="t('CADENCE.FORM.STEP.CONTENT.PLACEHOLDER')"
      @update:model-value="update('content', $event)"
    />
  </div>
</template>
