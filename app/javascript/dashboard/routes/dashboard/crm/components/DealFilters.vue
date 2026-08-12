<script setup>
import { onMounted, reactive } from 'vue';
import { useI18n } from 'vue-i18n';
import { useDebounceFn } from '@vueuse/core';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import Input from 'dashboard/components-next/input/Input.vue';

const emit = defineEmits(['change']);

const { t } = useI18n();
const store = useStore();

const agents = useMapGetter('agents/getAgents');

const filters = reactive({
  q: '',
  assignee_id: '',
  temperature: '',
  overdue: false,
});

onMounted(() => {
  if (!agents.value.length) {
    store.dispatch('agents/get');
  }
});

const emitChange = () => {
  const payload = Object.fromEntries(
    Object.entries(filters).filter(
      ([, value]) => value !== '' && value !== null && value !== false
    )
  );

  emit('change', payload);
};

// Only the free-text search fires per keystroke; the selects and checkbox
// are discrete choices and should apply immediately.
const emitChangeDebounced = useDebounceFn(emitChange, 300);
</script>

<template>
  <div class="flex items-center gap-2">
    <Input
      v-model="filters.q"
      :aria-label="t('CRM.SEARCH_PLACEHOLDER')"
      :placeholder="t('CRM.SEARCH_PLACEHOLDER')"
      @input="emitChangeDebounced"
    />

    <select
      v-model="filters.assignee_id"
      class="!mb-0"
      :aria-label="t('CRM.FILTERS.ASSIGNEE')"
      @change="emitChange"
    >
      <option value="">{{ t('CRM.FILTERS.ALL') }}</option>
      <option v-for="agent in agents" :key="agent.id" :value="agent.id">
        {{ agent.name }}
      </option>
    </select>

    <select
      v-model="filters.temperature"
      class="!mb-0"
      :aria-label="t('CRM.FILTERS.TEMPERATURE')"
      @change="emitChange"
    >
      <option value="">{{ t('CRM.FILTERS.ALL') }}</option>
      <option value="hot">{{ t('CRM.TEMPERATURE.HOT') }}</option>
      <option value="warm">{{ t('CRM.TEMPERATURE.WARM') }}</option>
      <option value="cold">{{ t('CRM.TEMPERATURE.COLD') }}</option>
    </select>

    <label class="flex items-center gap-1 text-sm">
      <input
        v-model="filters.overdue"
        type="checkbox"
        :aria-label="t('CRM.FILTERS.OVERDUE')"
        @change="emitChange"
      />
      {{ t('CRM.FILTERS.OVERDUE') }}
    </label>
  </div>
</template>
