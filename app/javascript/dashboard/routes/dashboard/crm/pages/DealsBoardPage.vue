<script setup>
import { onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import DealColumn from '../components/DealColumn.vue';

const { t } = useI18n();
const store = useStore();

const stages = useMapGetter('deals/getStages');
const dealsByStage = useMapGetter('deals/getDealsByStage');

onMounted(() => store.dispatch('deals/fetchBoard', {}));

const onMove = async ({ dealId, stageId, position }) => {
  await store.dispatch('deals/move', { id: dealId, stageId, position });
  store.dispatch('deals/fetchBoard', {});
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
  </div>
</template>
