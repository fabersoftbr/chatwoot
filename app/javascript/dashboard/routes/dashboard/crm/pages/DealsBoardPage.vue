<script setup>
import { onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import DealColumn from '../components/DealColumn.vue';
import LostReasonDialog from '../components/LostReasonDialog.vue';

const { t } = useI18n();
const store = useStore();

const stages = useMapGetter('deals/getStages');
const dealsByStage = useMapGetter('deals/getDealsByStage');

const lostDialogRef = ref(null);
const pendingMove = ref(null);

const refresh = () => store.dispatch('deals/fetchBoard', {});

onMounted(refresh);

const applyMove = async (move, lostReason) => {
  try {
    await store.dispatch('deals/move', {
      id: move.dealId,
      stageId: move.stageId,
      position: move.position,
      lostReason,
    });
  } catch (error) {
    useAlert(error.message);
  }
  refresh();
};

const onMove = move => {
  const target = stages.value.find(stage => stage.id === move.stageId);

  if (target?.stage_type === 'lost') {
    pendingMove.value = move;
    lostDialogRef.value.open();
    return;
  }

  applyMove(move);
};

const onLostConfirm = reason => {
  applyMove(pendingMove.value, reason);
  pendingMove.value = null;
};

const onLostCancel = () => {
  pendingMove.value = null;
  refresh();
};
</script>

<template>
  <div class="flex flex-col w-full h-full gap-4 p-4 overflow-hidden">
    <h1 class="text-xl font-medium text-slate-900 dark:text-slate-100">
      {{ t('CRM.HEADER') }}
    </h1>

    <div class="flex gap-3 overflow-x-auto grow">
      <DealColumn
        v-for="stage in stages"
        :key="stage.id"
        :stage="stage"
        :deals="dealsByStage(stage.id)"
        @move="onMove"
      />
    </div>

    <LostReasonDialog
      ref="lostDialogRef"
      @confirm="onLostConfirm"
      @cancel="onLostCancel"
    />
  </div>
</template>
