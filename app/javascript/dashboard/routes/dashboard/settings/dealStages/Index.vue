<script setup>
import { onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import draggable from 'vuedraggable';
import { useAlert } from 'dashboard/composables';
import { useStore, useMapGetter } from 'dashboard/composables/store';

const { t } = useI18n();
const store = useStore();

const stages = useMapGetter('dealStages/getStages');
const newStageName = ref('');

onMounted(() => store.dispatch('dealStages/get'));

const list = ref([]);
const syncList = () => {
  // Row copies, not store references: v-model on a row must never mutate
  // dealStages/getStages' objects directly, or a rejected save would leave
  // the store (and every other consumer of the getter) holding a value the
  // server refused.
  list.value = stages.value.map(stage => ({ ...stage }));
};

// The store getter returns a freshly sorted copy on every recompute, so the
// local drag list needs to stay in step even before the user interacts with
// the draggable (e.g. the initial fetch resolving after mount).
watch(stages, syncList, { immediate: true });

const addStage = async () => {
  if (!newStageName.value.trim()) return;

  await store.dispatch('dealStages/create', {
    name: newStageName.value.trim(),
    position: stages.value.length,
    stage_type: 'open',
  });
  newStageName.value = '';
  syncList();
};

const rename = stage =>
  store
    .dispatch('dealStages/update', { id: stage.id, name: stage.name })
    .catch(error => {
      useAlert(error.message);
      syncList();
    });
const recolor = stage =>
  store
    .dispatch('dealStages/update', { id: stage.id, color: stage.color })
    .catch(error => {
      useAlert(error.message);
      syncList();
    });
const remove = stage =>
  store
    .dispatch('dealStages/delete', stage.id)
    .then(syncList)
    .catch(() => useAlert(t('CRM.SETTINGS.DELETE_BLOCKED')));
const persistOrder = () =>
  store.dispatch(
    'dealStages/reorder',
    list.value.map(stage => stage.id)
  );
</script>

<template>
  <div class="flex flex-col gap-4 p-6">
    <div>
      <h2 class="text-lg font-medium">{{ t('CRM.SETTINGS.TITLE') }}</h2>
      <p class="text-sm text-n-slate-11">{{ t('CRM.SETTINGS.DESCRIPTION') }}</p>
    </div>

    <div class="flex gap-2">
      <input
        v-model="newStageName"
        class="p-2 text-sm border rounded border-slate-200 dark:border-slate-600 dark:bg-slate-900"
        :placeholder="t('CRM.SETTINGS.NAME')"
        :aria-label="t('CRM.SETTINGS.NAME')"
        @keyup.enter="addStage"
      />
      <button
        class="px-3 text-sm text-white rounded bg-woot-500"
        :aria-label="t('CRM.SETTINGS.ADD_STAGE')"
        @click="addStage"
      >
        {{ t('CRM.SETTINGS.ADD_STAGE') }}
      </button>
    </div>

    <draggable
      v-model="list"
      item-key="id"
      class="flex flex-col gap-2 max-w-xl"
      @start="syncList"
      @end="persistOrder"
    >
      <template #item="{ element }">
        <div
          class="flex items-center gap-2 p-2 border rounded border-slate-100 dark:border-slate-700"
        >
          <span class="cursor-grab text-n-slate-10" aria-hidden="true">{{
            '⠿'
          }}</span>
          <input
            v-model="element.color"
            type="color"
            class="w-8 h-8"
            :aria-label="t('CRM.SETTINGS.COLOR')"
            @change="recolor(element)"
          />
          <input
            v-model="element.name"
            class="grow p-1 text-sm bg-transparent"
            :aria-label="t('CRM.SETTINGS.NAME')"
            @blur="rename(element)"
          />
          <span class="text-xs text-n-slate-11">
            {{ t(`CRM.SETTINGS.TYPES.${element.stage_type.toUpperCase()}`) }}
          </span>
          <button
            class="text-xs text-red-600"
            :aria-label="t('CRM.SETTINGS.DELETE')"
            @click="remove(element)"
          >
            {{ t('CRM.SETTINGS.DELETE') }}
          </button>
        </div>
      </template>
    </draggable>
  </div>
</template>
