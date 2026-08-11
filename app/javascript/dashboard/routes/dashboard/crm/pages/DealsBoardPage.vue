<script setup>
import { onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';

const { t } = useI18n();
const store = useStore();

onMounted(() => store.dispatch('deals/fetchBoard', {}));
</script>

<template>
  <div class="flex flex-col w-full h-full p-4 overflow-hidden">
    <h1 class="text-xl font-medium text-slate-900 dark:text-slate-100">
      {{ t('CRM.HEADER') }}
    </h1>
  </div>
</template>
