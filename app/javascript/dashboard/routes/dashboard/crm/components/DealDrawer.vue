<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import DealDetailsTab from './DealDetailsTab.vue';
import DealActivityTab from './DealActivityTab.vue';
import DealContactTab from './DealContactTab.vue';

const props = defineProps({
  dealId: { type: Number, required: true },
});

const emit = defineEmits(['close']);

const { t } = useI18n();
const store = useStore();

const activeTab = ref('details');
const getDeal = useMapGetter('deals/getDeal');
const deal = computed(() => getDeal.value(props.dealId));

const onUpdate = fields =>
  store.dispatch('deals/update', { id: props.dealId, ...fields });

// `deal` only comes from the board's `fetchBoard`, which caps each stage at
// 25 cards — the deep link can point at a deal the board never loaded. Fetch
// it directly when the store doesn't already have it.
watch(
  () => props.dealId,
  id => {
    if (id && !getDeal.value(id)) store.dispatch('deals/show', id);
  },
  { immediate: true }
);
</script>

<template>
  <div>
    <aside
      v-if="deal"
      class="fixed top-0 right-0 z-40 flex flex-col h-full bg-white border-l w-96 dark:bg-slate-800 border-slate-100 dark:border-slate-700"
    >
      <header
        class="flex items-start justify-between gap-2 p-4 border-b border-slate-100 dark:border-slate-700"
      >
        <div>
          <h2 class="text-base font-medium">{{ deal.title }}</h2>
          <p class="text-xs text-slate-500">{{ deal.contact.name }}</p>
        </div>
        <woot-button
          icon="dismiss"
          variant="clear"
          color-scheme="secondary"
          :aria-label="t('CRM.CLOSE')"
          @click="emit('close')"
        />
      </header>

      <nav
        class="flex gap-4 px-4 border-b border-slate-100 dark:border-slate-700"
      >
        <button
          v-for="tab in ['details', 'activity', 'contact']"
          :key="tab"
          class="py-2 text-sm"
          :class="
            activeTab === tab
              ? 'text-woot-600 border-b-2 border-woot-500'
              : 'text-slate-500'
          "
          @click="activeTab = tab"
        >
          {{ t(`CRM.TABS.${tab.toUpperCase()}`) }}
        </button>
      </nav>

      <div class="overflow-y-auto grow">
        <DealDetailsTab
          v-if="activeTab === 'details'"
          :deal="deal"
          @update="onUpdate"
        />
        <DealActivityTab v-if="activeTab === 'activity'" :deal-id="dealId" />
        <DealContactTab
          v-if="activeTab === 'contact'"
          :contact="deal.contact"
        />
      </div>
    </aside>
  </div>
</template>
