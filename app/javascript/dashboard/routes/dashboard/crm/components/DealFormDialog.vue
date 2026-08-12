<script setup>
import { onMounted, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useEventListener } from '@vueuse/core';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { unitsToCents } from '../helpers/position';

const props = defineProps({
  contactId: { type: Number, default: null },
});

const emit = defineEmits(['created']);

const { t } = useI18n();
const store = useStore();

const stages = useMapGetter('deals/getStages');
const contacts = useMapGetter('contacts/getContacts');

const isOpen = ref(false);
const form = reactive({
  title: '',
  contact_id: props.contactId,
  deal_stage_id: null,
  value: 0,
  temperature: 'warm',
});

onMounted(() => {
  // The contact select only renders when contactId isn't already fixed by
  // the caller (see `v-if="!contactId"` below), so skip the fetch entirely
  // in that case — it's the sidebar's only use of this dialog.
  if (!props.contactId && !contacts.value.length) {
    store.dispatch('contacts/get', {});
  }
});

const open = () => {
  form.title = '';
  form.contact_id = props.contactId;
  form.deal_stage_id = stages.value[0]?.id ?? null;
  form.value = 0;
  form.temperature = 'warm';
  isOpen.value = true;
};

const submit = async () => {
  if (!form.title.trim() || !form.contact_id || !form.deal_stage_id) return;

  const deal = await store.dispatch('deals/create', {
    ...form,
    value: undefined,
    value_cents: unitsToCents(form.value),
  });
  isOpen.value = false;
  emit('created', deal);
};

useEventListener(document, 'keydown', e => {
  if (isOpen.value && e.key === 'Escape') isOpen.value = false;
});

defineExpose({ open });
</script>

<template>
  <div>
    <div
      v-if="isOpen"
      role="dialog"
      aria-modal="true"
      :aria-label="t('CRM.NEW_DEAL')"
      class="fixed inset-0 z-50 flex items-center justify-center bg-black/40"
    >
      <div
        class="flex flex-col gap-3 p-5 rounded-lg w-96 bg-n-alpha-3 backdrop-blur-[100px]"
      >
        <h3 class="text-base font-medium">{{ t('CRM.NEW_DEAL') }}</h3>

        <input
          v-model="form.title"
          type="text"
          class="w-full !mb-0"
          :aria-label="t('CRM.FORM.TITLE')"
          :placeholder="t('CRM.FORM.TITLE')"
        />

        <select
          v-if="!contactId"
          v-model="form.contact_id"
          class="w-full !mb-0"
          :aria-label="t('CRM.FORM.CONTACT')"
        >
          <option :value="null" disabled>{{ t('CRM.FORM.CONTACT') }}</option>
          <option
            v-for="contact in contacts"
            :key="contact.id"
            :value="contact.id"
          >
            {{ contact.name }}
          </option>
        </select>

        <select
          v-model="form.deal_stage_id"
          class="w-full !mb-0"
          :aria-label="t('CRM.FORM.STAGE')"
        >
          <option v-for="stage in stages" :key="stage.id" :value="stage.id">
            {{ stage.name }}
          </option>
        </select>

        <input
          v-model.number="form.value"
          type="number"
          min="0"
          class="w-full !mb-0"
          :aria-label="t('CRM.FORM.VALUE')"
          :placeholder="t('CRM.FORM.VALUE')"
        />

        <select
          v-model="form.temperature"
          class="w-full !mb-0"
          :aria-label="t('CRM.FORM.TEMPERATURE')"
        >
          <option value="hot">{{ t('CRM.TEMPERATURE.HOT') }}</option>
          <option value="warm">{{ t('CRM.TEMPERATURE.WARM') }}</option>
          <option value="cold">{{ t('CRM.TEMPERATURE.COLD') }}</option>
        </select>

        <div class="flex justify-end gap-2">
          <button class="px-3 py-1.5 text-sm" @click="isOpen = false">
            {{ t('CRM.FORM.CANCEL') }}
          </button>
          <button
            class="px-3 py-1.5 text-sm text-white rounded bg-woot-500 disabled:opacity-50"
            :disabled="
              !form.title.trim() || !form.contact_id || !form.deal_stage_id
            "
            @click="submit"
          >
            {{ t('CRM.FORM.SAVE') }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
