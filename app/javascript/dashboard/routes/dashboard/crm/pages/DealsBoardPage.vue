<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import DealColumn from '../components/DealColumn.vue';
import DealDrawer from '../components/DealDrawer.vue';
import DealFilters from '../components/DealFilters.vue';
import DealFormDialog from '../components/DealFormDialog.vue';
import LostReasonDialog from '../components/LostReasonDialog.vue';
import PipelineManagerDialog from '../components/PipelineManagerDialog.vue';
import StageManagerDialog from '../components/StageManagerDialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const { t } = useI18n();
const store = useStore();
const route = useRoute();
const router = useRouter();

const stages = useMapGetter('deals/getStages');
const dealsByStage = useMapGetter('deals/getDealsByStage');
const pipelines = useMapGetter('pipelines/getPipelines');

const lostDialogRef = ref(null);
const dealFormRef = ref(null);
const pipelineManagerRef = ref(null);
const stageManagerRef = ref(null);
const pendingMove = ref(null);
const filters = ref({});

const selectedDealId = computed(() =>
  route.params.dealId ? Number(route.params.dealId) : null
);

const activePipelineId = computed(
  () => Number(route.query.pipeline_id) || pipelines.value[0]?.id || null
);

const selectPipeline = pipelineId =>
  router.push({
    name: 'deals_board',
    params: route.params,
    query: { ...route.query, pipeline_id: pipelineId },
  });

const onSelect = deal =>
  router.push({
    name: 'deal_details',
    params: { ...route.params, dealId: deal.id },
  });

const closeDrawer = () =>
  router.push({ name: 'deals_board', params: route.params });

const refresh = () => {
  if (!activePipelineId.value) return;
  store.dispatch('deals/fetchBoard', {
    ...filters.value,
    pipeline_id: activePipelineId.value,
  });
};

onMounted(() => store.dispatch('pipelines/get'));

watch(activePipelineId, refresh, { immediate: true });

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
      <h1 class="text-xl font-medium text-n-slate-12">
        {{ t('CRM.HEADER') }}
      </h1>
      <div class="flex items-center min-w-0 gap-2">
        <select
          class="!mb-0 text-sm min-w-0 max-w-56"
          :value="activePipelineId"
          :aria-label="t('CRM.PIPELINE.LABEL')"
          @change="selectPipeline(Number($event.target.value))"
        >
          <option
            v-for="pipeline in pipelines"
            :key="pipeline.id"
            :value="pipeline.id"
          >
            {{ pipeline.name }}
          </option>
        </select>
        <Button
          v-tooltip="t('CRM.PIPELINE.MANAGE')"
          icon="i-lucide-folder-tree"
          size="sm"
          variant="faded"
          class="flex-shrink-0"
          :aria-label="t('CRM.PIPELINE.MANAGE')"
          @click="pipelineManagerRef.open()"
        />
        <Button
          v-tooltip="t('CRM.PIPELINE.MANAGE_STAGES')"
          icon="i-lucide-columns-3"
          size="sm"
          variant="faded"
          class="flex-shrink-0"
          :aria-label="t('CRM.PIPELINE.MANAGE_STAGES')"
          @click="stageManagerRef.open()"
        />
        <Button
          :label="t('CRM.NEW_DEAL')"
          size="sm"
          class="flex-shrink-0"
          @click="dealFormRef.open()"
        />
      </div>
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

    <DealFormDialog
      ref="dealFormRef"
      :pipeline-id="activePipelineId"
      @created="refresh"
    />

    <StageManagerDialog
      ref="stageManagerRef"
      :pipeline-id="activePipelineId"
      @changed="refresh"
    />

    <PipelineManagerDialog ref="pipelineManagerRef" @changed="refresh" />
  </div>
</template>
