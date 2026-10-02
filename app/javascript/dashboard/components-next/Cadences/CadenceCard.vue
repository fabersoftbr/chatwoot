<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  cadence: { type: Object, required: true },
});

const emit = defineEmits(['toggle', 'delete']);

const { t } = useI18n();

const activeCount = computed(
  () => props.cadence.enrollment_counts?.active ?? 0
);
const stepCount = computed(() => props.cadence.steps?.length ?? 0);
</script>

<template>
  <div class="flex items-center justify-between gap-4 p-4 border rounded-lg border-n-weak">
    <div class="flex flex-col gap-1 min-w-0">
      <span class="text-sm font-medium truncate text-n-slate-12">
        {{ cadence.title }}
      </span>
      <span class="text-xs text-n-slate-11">
        {{
          t('CADENCE.CARD.SUMMARY', {
            steps: stepCount,
            inbox: cadence.inbox?.name,
            active: activeCount,
          })
        }}
      </span>
    </div>
    <div class="flex items-center flex-shrink-0 gap-2">
      <span
        class="text-xs"
        :class="cadence.enabled ? 'text-n-teal-11' : 'text-n-slate-11'"
      >
        {{ cadence.enabled ? t('CADENCE.CARD.ON') : t('CADENCE.CARD.OFF') }}
      </span>
      <Button
        faded
        slate
        xs
        type="button"
        :label="cadence.enabled ? t('CADENCE.CARD.PAUSE') : t('CADENCE.CARD.RESUME')"
        @click="emit('toggle', cadence)"
      />
      <Button
        faded
        ruby
        xs
        type="button"
        icon="i-lucide-trash-2"
        :label="t('CADENCE.CARD.DELETE')"
        @click="emit('delete', cadence)"
      />
    </div>
  </div>
</template>
