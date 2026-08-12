<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { frontendURL } from 'dashboard/helper/URLHelper';

const props = defineProps({
  contact: { type: Object, required: true },
});

const { t } = useI18n();
const route = useRoute();

const profileUrl = computed(() =>
  frontendURL(`accounts/${route.params.accountId}/contacts/${props.contact.id}`)
);
</script>

<template>
  <div class="flex flex-col gap-3 p-4">
    <router-link :to="profileUrl" class="text-sm font-medium text-n-blue-11">
      {{ contact.name }}
    </router-link>

    <div v-if="contact.email" class="flex flex-col gap-1">
      <span class="text-xs text-n-slate-11">
        {{ t('CONTACT_PANEL.EMAIL_ADDRESS') }}
      </span>
      <span class="text-sm">{{ contact.email }}</span>
    </div>

    <div v-if="contact.phone_number" class="flex flex-col gap-1">
      <span class="text-xs text-n-slate-11">
        {{ t('CONTACT_PANEL.PHONE_NUMBER') }}
      </span>
      <span class="text-sm">{{ contact.phone_number }}</span>
    </div>
  </div>
</template>
