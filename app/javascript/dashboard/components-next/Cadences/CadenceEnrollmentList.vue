<script setup>
import { onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import CadencesAPI from 'dashboard/api/cadences';

import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const props = defineProps({
  cadenceId: { type: Number, required: true },
});

const { t } = useI18n();

const enrollments = ref([]);
const isLoading = ref(true);
const stoppingId = ref(null);

const load = async () => {
  isLoading.value = true;
  try {
    const { data } = await CadencesAPI.getEnrollments(props.cadenceId);
    enrollments.value = data;
  } catch (error) {
    useAlert(t('CADENCE.API.ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const stop = async enrollment => {
  stoppingId.value = enrollment.id;
  try {
    await CadencesAPI.stopEnrollment(props.cadenceId, enrollment.id);
    enrollment.status = 'stopped_manually';
  } catch (error) {
    useAlert(t('CADENCE.API.ERROR'));
  } finally {
    stoppingId.value = null;
  }
};

onMounted(load);
</script>

<template>
  <div class="flex flex-col gap-2 pt-3 mt-3 border-t border-n-weak">
    <div v-if="isLoading" class="flex justify-center py-4 text-n-slate-11">
      <Spinner />
    </div>
    <span v-else-if="!enrollments.length" class="text-xs text-n-slate-11">
      {{ t('CADENCE.ENROLLMENTS.EMPTY') }}
    </span>
    <div
      v-for="enrollment in enrollments"
      v-else
      :key="enrollment.id"
      class="flex items-center justify-between gap-3 text-xs"
    >
      <span class="truncate text-n-slate-12">
        {{ enrollment.contact.name || enrollment.contact.phone_number }}
      </span>
      <div class="flex items-center flex-shrink-0 gap-2">
        <span class="text-n-slate-11">
          {{
            t('CADENCE.ENROLLMENTS.POSITION', {
              step: enrollment.step_index + 1,
              status: t(
                `CADENCE.ENROLLMENTS.STATUS.${enrollment.status.toUpperCase()}`
              ),
            })
          }}
        </span>
        <Button
          v-if="enrollment.status === 'active'"
          faded
          slate
          xs
          type="button"
          :is-loading="stoppingId === enrollment.id"
          :label="t('CADENCE.ENROLLMENTS.STOP')"
          @click="stop(enrollment)"
        />
      </div>
    </div>
  </div>
</template>
