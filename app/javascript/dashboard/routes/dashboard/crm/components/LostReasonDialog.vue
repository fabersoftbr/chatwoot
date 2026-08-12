<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useEventListener } from '@vueuse/core';

const emit = defineEmits(['confirm', 'cancel']);

const { t } = useI18n();
const isOpen = ref(false);
const reason = ref('');

const open = () => {
  reason.value = '';
  isOpen.value = true;
};

const confirm = () => {
  if (!reason.value.trim()) return;
  isOpen.value = false;
  emit('confirm', reason.value.trim());
};

const cancel = () => {
  isOpen.value = false;
  emit('cancel');
};

useEventListener(document, 'keydown', e => {
  if (isOpen.value && e.key === 'Escape') cancel();
});

defineExpose({ open });
</script>

<template>
  <div>
    <div
      v-if="isOpen"
      role="dialog"
      aria-modal="true"
      :aria-label="t('CRM.LOST_DIALOG.TITLE')"
      class="fixed inset-0 z-50 flex items-center justify-center bg-black/40"
    >
      <div class="w-96 p-5 rounded-lg bg-n-alpha-3 backdrop-blur-[100px]">
        <h3 class="mb-3 text-base font-medium">
          {{ t('CRM.LOST_DIALOG.TITLE') }}
        </h3>
        <textarea
          v-model="reason"
          rows="3"
          class="w-full !mb-0"
          :placeholder="t('CRM.LOST_DIALOG.PLACEHOLDER')"
        />
        <div class="flex justify-end gap-2 mt-4">
          <button class="px-3 py-1.5 text-sm" @click="cancel">
            {{ t('CRM.LOST_DIALOG.CANCEL') }}
          </button>
          <button
            class="px-3 py-1.5 text-sm text-white rounded bg-red-600 disabled:opacity-50"
            :disabled="!reason.trim()"
            @click="confirm"
          >
            {{ t('CRM.LOST_DIALOG.CONFIRM') }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
