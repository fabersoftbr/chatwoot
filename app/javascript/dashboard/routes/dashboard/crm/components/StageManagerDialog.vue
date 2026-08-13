<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import StageFormDialog from './StageFormDialog.vue';

const props = defineProps({
  pipelineId: { type: Number, default: null },
});

const emit = defineEmits(['changed']);

const { t } = useI18n();
const store = useStore();

const stages = useMapGetter('deals/getStages');

const dialogRef = ref(null);
const formRef = ref(null);

const open = () => dialogRef.value.open();

const notifyChange = () => emit('changed');

const move = (index, offset) => {
  const target = index + offset;
  if (target < 0 || target >= stages.value.length) return;

  const stageIds = stages.value.map(stage => stage.id);
  [stageIds[index], stageIds[target]] = [stageIds[target], stageIds[index]];

  store
    .dispatch('dealStages/reorder', { pipelineId: props.pipelineId, stageIds })
    .then(notifyChange)
    .catch(error => useAlert(error.message));
};

const remove = stage =>
  store
    .dispatch('dealStages/delete', stage.id)
    .then(notifyChange)
    .catch(error => useAlert(error.message || t('CRM.STAGES.DELETE_BLOCKED')));

const save = ({ id, name, color }) => {
  const action = id
    ? store.dispatch('dealStages/update', { id, name, color })
    : store.dispatch('dealStages/create', {
        pipelineId: props.pipelineId,
        name,
        color,
        position: stages.value.length,
        stage_type: 'open',
      });

  action.then(notifyChange).catch(error => useAlert(error.message));
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="md"
    :title="t('CRM.STAGES.TITLE')"
    :show-confirm-button="false"
    :show-cancel-button="false"
  >
    <div class="flex flex-col gap-2">
      <div
        v-for="(stage, index) in stages"
        :key="stage.id"
        data-testid="stage-row"
        class="flex items-center gap-3 px-2 py-2 rounded-lg hover:bg-n-alpha-1"
      >
        <span
          class="w-3 h-3 rounded-full shrink-0"
          :style="{ backgroundColor: stage.color }"
        />
        <span class="text-sm text-n-slate-12 grow">{{ stage.name }}</span>
        <span class="text-xs text-n-slate-11">{{ stage.deals_count }}</span>

        <button
          data-testid="stage-move-up"
          class="p-1 text-n-slate-11 hover:text-n-slate-12"
          :aria-label="t('CRM.STAGES.MOVE_UP')"
          @click="move(index, -1)"
        >
          <Icon icon="i-lucide-arrow-up" class="size-4" />
        </button>
        <button
          data-testid="stage-move-down"
          class="p-1 text-n-slate-11 hover:text-n-slate-12"
          :aria-label="t('CRM.STAGES.MOVE_DOWN')"
          @click="move(index, 1)"
        >
          <Icon icon="i-lucide-arrow-down" class="size-4" />
        </button>
        <button
          class="p-1 text-n-slate-11 hover:text-n-slate-12"
          :aria-label="t('CRM.STAGES.EDIT')"
          @click="formRef.open(stage)"
        >
          <Icon icon="i-lucide-pencil" class="size-4" />
        </button>
        <button
          class="p-1 text-n-ruby-11"
          :aria-label="t('CRM.STAGES.DELETE')"
          @click="remove(stage)"
        >
          <Icon icon="i-lucide-trash-2" class="size-4" />
        </button>
      </div>

      <button
        class="flex items-center justify-center gap-2 py-2 mt-2 text-sm border rounded-lg border-n-weak text-n-slate-12"
        @click="formRef.open()"
      >
        <Icon icon="i-lucide-plus" class="size-4" />
        {{ t('CRM.STAGES.NEW_STAGE') }}
      </button>
    </div>

    <StageFormDialog ref="formRef" @save="save" />
  </Dialog>
</template>
