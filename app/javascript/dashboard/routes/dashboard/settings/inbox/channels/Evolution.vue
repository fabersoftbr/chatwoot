<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required } from '@vuelidate/validators';
import { useAlert } from 'dashboard/composables';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import router from '../../../../index';
import PageHeader from '../../SettingsSubPageHeader.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const { t } = useI18n();
const store = useStore();
const uiFlags = useMapGetter('inboxes/getUIFlags');

const channelName = ref('');
const v$ = useVuelidate({ channelName: { required } }, { channelName });

const createChannel = async () => {
  v$.value.$touch();
  if (v$.value.$invalid) return;

  const name = channelName.value.trim();
  try {
    const inbox = await store.dispatch('inboxes/createChannel', {
      name,
      // Evolution binds its instance to the inbox by name, and the inbox does
      // not exist yet when the channel record is created.
      channel: { type: 'evolution', inbox_name: name },
    });

    router.replace({
      name: 'settings_inboxes_add_agents',
      params: { page: 'new', inbox_id: inbox.id },
    });
  } catch (error) {
    useAlert(
      error.message || t('INBOX_MGMT.ADD.EVOLUTION_CHANNEL.API.ERROR_MESSAGE')
    );
  }
};
</script>

<template>
  <div class="h-full w-full p-6 col-span-6">
    <PageHeader
      :header-title="$t('INBOX_MGMT.ADD.EVOLUTION_CHANNEL.TITLE')"
      :header-content="$t('INBOX_MGMT.ADD.EVOLUTION_CHANNEL.DESC')"
    />
    <form class="flex flex-wrap flex-col mx-0" @submit.prevent="createChannel">
      <div class="flex-shrink-0 flex-grow-0">
        <label :class="{ error: v$.channelName.$error }">
          {{ $t('INBOX_MGMT.ADD.EVOLUTION_CHANNEL.CHANNEL_NAME.LABEL') }}
          <input
            v-model="channelName"
            type="text"
            :placeholder="
              $t('INBOX_MGMT.ADD.EVOLUTION_CHANNEL.CHANNEL_NAME.PLACEHOLDER')
            "
            @blur="v$.channelName.$touch"
          />
          <span v-if="v$.channelName.$error" class="message">
            {{ $t('INBOX_MGMT.ADD.EVOLUTION_CHANNEL.CHANNEL_NAME.ERROR') }}
          </span>
        </label>
        <p class="help-text">
          {{ $t('INBOX_MGMT.ADD.EVOLUTION_CHANNEL.CHANNEL_NAME.SUBTITLE') }}
        </p>
      </div>

      <div class="w-full mt-4">
        <NextButton
          :is-loading="uiFlags.isCreating"
          type="submit"
          solid
          blue
          :label="$t('INBOX_MGMT.ADD.EVOLUTION_CHANNEL.SUBMIT_BUTTON')"
        />
      </div>
    </form>
  </div>
</template>
