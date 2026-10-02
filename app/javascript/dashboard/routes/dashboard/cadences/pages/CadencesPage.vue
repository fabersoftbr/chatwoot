<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useToggle } from '@vueuse/core';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';

import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import CampaignLayout from 'dashboard/components-next/Campaigns/CampaignLayout.vue';
import CadenceDialog from 'dashboard/components-next/Cadences/CadenceDialog.vue';
import CadenceCard from 'dashboard/components-next/Cadences/CadenceCard.vue';

const { t } = useI18n();
const store = useStore();

const [showCadenceDialog, toggleCadenceDialog] = useToggle();
const deletingId = ref(null);

const uiFlags = useMapGetter('cadences/getUIFlags');
const cadences = useMapGetter('cadences/getCadences');

const isFetching = computed(() => uiFlags.value.isFetching);
const isEmpty = computed(
  () => cadences.value?.length === 0 && !isFetching.value
);

onMounted(() => {
  store.dispatch('cadences/get');
  store.dispatch('labels/get');
  store.dispatch('inboxes/get');
});

const handleToggle = async cadence => {
  try {
    await store.dispatch('cadences/update', {
      id: cadence.id,
      enabled: !cadence.enabled,
    });
  } catch (error) {
    useAlert(t('CADENCE.API.ERROR'));
  }
};

const handleDelete = async cadence => {
  deletingId.value = cadence.id;
  try {
    await store.dispatch('cadences/delete', cadence.id);
    useAlert(t('CADENCE.API.DELETE_SUCCESS'));
  } catch (error) {
    useAlert(t('CADENCE.API.ERROR'));
  } finally {
    deletingId.value = null;
  }
};
</script>

<template>
  <CampaignLayout
    :header-title="t('CADENCE.HEADER_TITLE')"
    :button-label="t('CADENCE.NEW')"
    @click="toggleCadenceDialog()"
    @close="toggleCadenceDialog(false)"
  >
    <template #action>
      <CadenceDialog
        v-if="showCadenceDialog"
        @close="toggleCadenceDialog(false)"
      />
    </template>

    <div
      v-if="isFetching"
      class="flex items-center justify-center py-10 text-n-slate-11"
    >
      <Spinner />
    </div>
    <div v-else-if="!isEmpty" class="flex flex-col gap-3">
      <CadenceCard
        v-for="cadence in cadences"
        :key="cadence.id"
        :cadence="cadence"
        @toggle="handleToggle"
        @delete="handleDelete"
      />
    </div>
    <div v-else class="flex flex-col items-center gap-2 pt-14 text-center">
      <span class="text-base font-medium text-n-slate-12">
        {{ t('CADENCE.EMPTY_STATE.TITLE') }}
      </span>
      <span class="max-w-md text-sm text-n-slate-11">
        {{ t('CADENCE.EMPTY_STATE.SUBTITLE') }}
      </span>
    </div>
  </CampaignLayout>
</template>
