<script setup>
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';

import CadenceForm from './CadenceForm.vue';

const emit = defineEmits(['close']);

const store = useStore();
const { t } = useI18n();

const handleSubmit = async cadence => {
  try {
    await store.dispatch('cadences/create', cadence);
    useAlert(t('CADENCE.API.CREATE_SUCCESS'));
    emit('close');
  } catch (error) {
    // The model explains which step Meta would refuse; the generic copy hides it.
    useAlert(
      error?.response?.data?.message ||
        error?.response?.data?.error ||
        t('CADENCE.API.ERROR')
    );
  }
};
</script>

<template>
  <div
    class="w-[30rem] z-50 min-w-0 absolute top-10 ltr:right-0 rtl:left-0 bg-n-alpha-3 backdrop-blur-[100px] rounded-xl border border-n-weak shadow-md max-h-[80vh] overflow-y-auto"
  >
    <div class="flex flex-col gap-6 p-6">
      <h3 class="flex-shrink-0 text-base font-medium text-n-slate-12">
        {{ t('CADENCE.CREATE_TITLE') }}
      </h3>
      <CadenceForm @submit="handleSubmit" @cancel="emit('close')" />
    </div>
  </div>
</template>
