<script setup>
import { onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';

const props = defineProps({
  dealId: { type: Number, required: true },
});

const { t } = useI18n();
const store = useStore();

const MANUAL_TYPES = ['note', 'call', 'meeting', 'email'];

const activities = ref([]);
const activityType = ref('call');
const content = ref('');

const load = async () => {
  activities.value = await store.dispatch(
    'deals/fetchActivities',
    props.dealId
  );
};

onMounted(load);

const submit = async () => {
  if (!content.value.trim()) return;

  await store.dispatch('deals/createActivity', {
    dealId: props.dealId,
    activityType: activityType.value,
    content: content.value.trim(),
  });
  content.value = '';
  load();
};

const describe = activity => {
  if (MANUAL_TYPES.includes(activity.activity_type)) return activity.content;
  return t(`CRM.ACTIVITY.TYPES.${activity.activity_type.toUpperCase()}`);
};
</script>

<template>
  <div class="flex flex-col gap-4 p-4">
    <div class="flex flex-col gap-2">
      <div class="flex gap-2">
        <select
          v-model="activityType"
          class="p-2 text-sm border rounded border-slate-200 dark:border-slate-600 dark:bg-slate-900"
        >
          <option v-for="type in MANUAL_TYPES" :key="type" :value="type">
            {{ t(`CRM.ACTIVITY.TYPES.${type.toUpperCase()}`) }}
          </option>
        </select>
        <button
          class="px-3 text-sm text-white rounded bg-woot-500 disabled:opacity-50"
          :disabled="!content.trim()"
          @click="submit"
        >
          {{ t('CRM.ACTIVITY.SUBMIT') }}
        </button>
      </div>
      <textarea
        v-model="content"
        rows="2"
        class="w-full p-2 text-sm border rounded border-slate-200 dark:border-slate-600 dark:bg-slate-900"
        :placeholder="t('CRM.ACTIVITY.PLACEHOLDER')"
      />
    </div>

    <ul v-if="activities.length" class="flex flex-col gap-3">
      <li
        v-for="activity in activities"
        :key="activity.id"
        class="pl-3 border-l-2 border-slate-200 dark:border-slate-600"
      >
        <p class="text-sm text-slate-800 dark:text-slate-100">
          {{ describe(activity) }}
        </p>
        <p class="text-xs text-slate-500">
          {{ t(`CRM.ACTIVITY.TYPES.${activity.activity_type.toUpperCase()}`) }}
          <template v-if="activity.user"> · {{ activity.user.name }}</template>
          · {{ new Date(activity.created_at).toLocaleString() }}
        </p>
      </li>
    </ul>

    <p v-else class="text-sm text-slate-400">{{ t('CRM.ACTIVITY.EMPTY') }}</p>
  </div>
</template>
