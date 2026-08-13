<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const emit = defineEmits(['changed']);

const { t } = useI18n();
const store = useStore();

const pipelines = useMapGetter('pipelines/getPipelines');

const dialogRef = ref(null);
const newName = ref('');

const open = () => {
  newName.value = '';
  dialogRef.value.open();
};

const notifyChange = () => emit('changed');

const rename = pipeline =>
  store
    .dispatch('pipelines/update', { id: pipeline.id, name: pipeline.name })
    .then(notifyChange)
    .catch(error => useAlert(error.message));

const remove = pipeline =>
  store
    .dispatch('pipelines/delete', pipeline.id)
    .then(notifyChange)
    .catch(error => useAlert(error.message));

const create = () => {
  if (!newName.value.trim()) return;

  store
    .dispatch('pipelines/create', {
      name: newName.value.trim(),
      position: pipelines.value.length,
    })
    .then(() => {
      newName.value = '';
      notifyChange();
    })
    .catch(error => useAlert(error.message));
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="md"
    :title="t('CRM.PIPELINE.MANAGE')"
    :show-confirm-button="false"
    :show-cancel-button="false"
  >
    <div class="flex flex-col gap-2">
      <div
        v-for="pipeline in pipelines"
        :key="pipeline.id"
        data-testid="pipeline-row"
        class="flex items-center gap-3 px-2 py-2 rounded-lg hover:bg-n-alpha-1"
      >
        <input
          v-model="pipeline.name"
          type="text"
          class="grow !mb-0 bg-transparent text-sm"
          :aria-label="t('CRM.PIPELINE.NAME')"
          @blur="rename(pipeline)"
        />
        <button
          class="p-1 text-n-ruby-11"
          :aria-label="t('CRM.PIPELINE.DELETE')"
          @click="remove(pipeline)"
        >
          <Icon icon="i-lucide-trash-2" class="size-4" />
        </button>
      </div>

      <div class="flex gap-2 mt-2">
        <input
          v-model="newName"
          type="text"
          class="grow !mb-0 text-sm"
          :aria-label="t('CRM.PIPELINE.NEW')"
          :placeholder="t('CRM.PIPELINE.PLACEHOLDER')"
          @keyup.enter="create"
        />
        <button
          class="px-3 text-sm text-white rounded bg-woot-500 disabled:opacity-50"
          :disabled="!newName.trim()"
          @click="create"
        >
          {{ t('CRM.PIPELINE.NEW') }}
        </button>
      </div>
    </div>
  </Dialog>
</template>
