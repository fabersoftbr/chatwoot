<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import DealDetailsTab from './DealDetailsTab.vue';
import DealActivityTab from './DealActivityTab.vue';
import DealContactTab from './DealContactTab.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  dealId: { type: Number, required: true },
});

const emit = defineEmits(['close']);

const { t } = useI18n();
const store = useStore();

const activeTab = ref('details');
const getDeal = useMapGetter('deals/getDeal');
const deal = computed(() => getDeal.value(props.dealId));

// A rejected update leaves the store's deal untouched, but DealDetailsTab's
// local form state has already moved on (v-model updates it before the
// dispatch resolves). Bumping this key remounts the tab so its form
// re-seeds from the actual (unchanged) store value instead of continuing to
// show the value the server refused.
const detailsKey = ref(0);

const onUpdate = fields =>
  store
    .dispatch('deals/update', { id: props.dealId, ...fields })
    .catch(error => {
      useAlert(error.message);
      detailsKey.value += 1;
    });

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
      class="fixed top-0 right-0 z-40 flex flex-col h-full border-l bg-n-solid-2 w-96 border-n-weak"
    >
      <header
        class="flex items-start justify-between gap-2 p-4 border-b border-n-weak"
      >
        <div>
          <h2 class="text-base font-medium text-n-slate-12">
            {{ deal.title }}
          </h2>
          <p class="text-xs text-n-slate-11">{{ deal.contact.name }}</p>
        </div>
        <Button
          variant="ghost"
          color="slate"
          size="sm"
          icon="i-lucide-x"
          :aria-label="t('CRM.CLOSE')"
          @click="emit('close')"
        />
      </header>

      <nav class="flex gap-4 px-4 border-b border-n-weak">
        <button
          v-for="tab in ['details', 'activity', 'contact']"
          :key="tab"
          class="py-2 text-sm"
          :class="
            activeTab === tab
              ? 'text-n-blue-11 border-b-2 border-n-brand'
              : 'text-n-slate-11'
          "
          @click="activeTab = tab"
        >
          {{ t(`CRM.TABS.${tab.toUpperCase()}`) }}
        </button>
      </nav>

      <div class="overflow-y-auto grow">
        <DealDetailsTab
          v-if="activeTab === 'details'"
          :key="detailsKey"
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
