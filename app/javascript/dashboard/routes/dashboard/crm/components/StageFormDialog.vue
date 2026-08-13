<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import { STAGE_COLORS, DEFAULT_STAGE_COLOR } from '../helpers/colors';

const emit = defineEmits(['save']);

const { t } = useI18n();

const dialogRef = ref(null);
const editingId = ref(null);
const name = ref('');
const color = ref(DEFAULT_STAGE_COLOR);

const open = (stage = null) => {
  editingId.value = stage?.id ?? null;
  name.value = stage?.name ?? '';
  color.value = stage?.color ?? DEFAULT_STAGE_COLOR;
  dialogRef.value.open();
};

const onConfirm = () => {
  if (!name.value.trim()) return;
  emit('save', {
    id: editingId.value,
    name: name.value.trim(),
    color: color.value,
  });
  dialogRef.value.close();
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="sm"
    :title="editingId ? t('CRM.STAGES.EDIT_STAGE') : t('CRM.STAGES.NEW_STAGE')"
    :confirm-button-label="t('CRM.STAGES.SAVE')"
    :cancel-button-label="t('CRM.STAGES.CANCEL')"
    :disable-confirm-button="!name.trim()"
    @confirm="onConfirm"
  >
    <div class="flex flex-col gap-4">
      <div class="flex flex-col gap-1">
        <label class="text-sm font-medium text-n-slate-12" for="stage-name">
          {{ t('CRM.STAGES.NAME') }}
        </label>
        <input
          id="stage-name"
          v-model="name"
          type="text"
          class="w-full !mb-0"
        />
      </div>

      <div class="flex flex-col gap-2">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('CRM.STAGES.COLOR') }}
        </span>
        <div class="flex flex-wrap gap-2">
          <button
            v-for="option in STAGE_COLORS"
            :key="option"
            type="button"
            class="w-8 h-8 rounded-full outline-offset-2"
            :class="
              option === color ? 'outline outline-2 outline-n-slate-11' : ''
            "
            :style="{ backgroundColor: option }"
            :aria-label="option"
            @click="color = option"
          />
        </div>
      </div>
    </div>
  </Dialog>
</template>
