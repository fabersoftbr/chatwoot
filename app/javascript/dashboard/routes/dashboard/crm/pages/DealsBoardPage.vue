<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import DealColumn from '../components/DealColumn.vue';
import DealDrawer from '../components/DealDrawer.vue';
import DealFilters from '../components/DealFilters.vue';
import DealFormDialog from '../components/DealFormDialog.vue';
import LostReasonDialog from '../components/LostReasonDialog.vue';

const { t } = useI18n();
const store = useStore();
const route = useRoute();
const router = useRouter();

const stages = useMapGetter('deals/getStages');
const dealsByStage = useMapGetter('deals/getDealsByStage');

const lostDialogRef = ref(null);
const dealFormRef = ref(null);
const pendingMove = ref(null);
const filters = ref({});

const selectedDealId = computed(() =>
  route.params.dealId ? Number(route.params.dealId) : null
);

const onSelect = deal =>
  router.push({
    name: 'deal_details',
    params: { ...route.params, dealId: deal.id },
  });

const closeDrawer = () =>
  router.push({ name: 'deals_board', params: route.params });

const refresh = () => store.dispatch('deals/fetchBoard', filters.value);

onMounted(refresh);

const onFiltersChange = newFilters => {
  filters.value = newFilters;
  refresh();
};

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
    <div class="flex items-center justify-between">
      <h1 class="text-xl font-medium text-slate-900 dark:text-slate-100">
        {{ t('CRM.HEADER') }}
      </h1>
      <button
        class="px-3 py-1.5 text-sm text-white rounded bg-woot-500"
        @click="dealFormRef.open()"
      >
        {{ t('CRM.NEW_DEAL') }}
      </button>
    </div>

    <DealFilters @change="onFiltersChange" />

    <div class="flex gap-3 overflow-x-auto grow">
      <DealColumn
        v-for="stage in stages"
        :key="stage.id"
        :stage="stage"
        :deals="dealsByStage(stage.id)"
        @move="onMove"
        @select="onSelect"
      />
    </div>

    <LostReasonDialog
      ref="lostDialogRef"
      @confirm="onLostConfirm"
      @cancel="onLostCancel"
    />

    <DealDrawer
      v-if="selectedDealId"
      :deal-id="selectedDealId"
      @close="closeDrawer"
    />

    <DealFormDialog ref="dealFormRef" @created="refresh" />
  </div>
</template>
