<script>
import { useAlert } from 'dashboard/composables';
import WhatsappTemplatesAPI from 'dashboard/api/channel/whatsappTemplates';
import NextButton from 'dashboard/components-next/button/Button.vue';
import NextDialog from 'dashboard/components-next/dialog/Dialog.vue';
import WhatsappTemplateForm from '../components/WhatsappTemplateForm.vue';

// Anything unlisted is still under review, hence the amber fallback. PAUSED and
// DISABLED are not "pending" — they are inactive, so they get their own colour.
const STATUS_CLASSES = {
  approved: 'text-n-teal-11',
  rejected: 'text-n-ruby-11',
  paused: 'text-n-slate-11',
  disabled: 'text-n-slate-11',
};

export default {
  components: { NextButton, NextDialog, WhatsappTemplateForm },
  props: {
    inbox: {
      type: Object,
      default: () => ({}),
    },
  },
  data() {
    return {
      templateToDelete: null,
      isDeleting: false,
    };
  },
  computed: {
    templates() {
      // The column defaults to {} but every writer stores an Array.
      const stored = this.inbox.message_templates;
      return Array.isArray(stored) ? stored : [];
    },
    // Without Meta's template id we can only delete by name, which wipes every
    // language version. Say so instead of silently doing it.
    deleteConfirmMessage() {
      return this.templateToDelete && !this.templateToDelete.id
        ? this.$t('WHATSAPP_TEMPLATES.DELETE.CONFIRM_MESSAGE_ALL_LANGUAGES')
        : this.$t('WHATSAPP_TEMPLATES.DELETE.CONFIRM_MESSAGE');
    },
  },
  methods: {
    statusClass(status) {
      return STATUS_CLASSES[(status || '').toLowerCase()] || 'text-n-amber-11';
    },
    templateBody(template) {
      const component = (template.components || []).find(
        item => item.type === 'BODY'
      );
      return component ? component.text : '';
    },
    refreshInbox() {
      return this.$store.dispatch('inboxes/get', this.inbox.id);
    },
    async onCreated() {
      this.$refs.formDialog?.close();
      await this.refreshInbox();
    },
    openDeleteDialog(template) {
      this.templateToDelete = template;
      this.$refs.deleteDialog?.open();
    },
    async confirmDelete() {
      this.isDeleting = true;
      try {
        await WhatsappTemplatesAPI.delete(
          this.inbox.id,
          this.templateToDelete.name,
          this.templateToDelete.id
        );
        this.$refs.deleteDialog?.close();
        await this.refreshInbox();
        useAlert(this.$t('WHATSAPP_TEMPLATES.API.DELETE_SUCCESS'));
      } catch (error) {
        // Meta's own wording, shown verbatim.
        useAlert(
          error?.response?.data?.error ||
            this.$t('WHATSAPP_TEMPLATES.API.ERROR')
        );
      } finally {
        this.isDeleting = false;
      }
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-4">
    <div class="flex gap-4 justify-between items-start">
      <div>
        <h4 class="text-base text-n-slate-12">
          {{ $t('WHATSAPP_TEMPLATES.TITLE') }}
        </h4>
        <p class="text-sm text-n-slate-11">
          {{ $t('WHATSAPP_TEMPLATES.SUBTITLE') }}
        </p>
      </div>
      <NextButton
        :label="$t('WHATSAPP_TEMPLATES.ADD')"
        icon="i-lucide-plus"
        @click="$refs.formDialog.open()"
      />
    </div>

    <p v-if="!templates.length" class="text-sm text-n-slate-11">
      {{ $t('WHATSAPP_TEMPLATES.EMPTY') }}
    </p>

    <table v-else class="woot-table">
      <thead>
        <tr>
          <th>{{ $t('WHATSAPP_TEMPLATES.TABLE.NAME') }}</th>
          <th>{{ $t('WHATSAPP_TEMPLATES.TABLE.LANGUAGE') }}</th>
          <th>{{ $t('WHATSAPP_TEMPLATES.TABLE.CATEGORY') }}</th>
          <th>{{ $t('WHATSAPP_TEMPLATES.TABLE.STATUS') }}</th>
          <th>{{ $t('WHATSAPP_TEMPLATES.TABLE.ACTIONS') }}</th>
        </tr>
      </thead>
      <tbody>
        <tr
          v-for="template in templates"
          :key="`${template.name}-${template.language}`"
        >
          <td>
            <span class="font-medium">{{ template.name }}</span>
            <p class="text-xs text-n-slate-11">{{ templateBody(template) }}</p>
          </td>
          <td>{{ template.language }}</td>
          <td>{{ template.category }}</td>
          <td :class="statusClass(template.status)">{{ template.status }}</td>
          <td>
            <NextButton
              sm
              ghost
              ruby
              :label="$t('WHATSAPP_TEMPLATES.DELETE.BUTTON')"
              @click="openDeleteDialog(template)"
            />
          </td>
        </tr>
      </tbody>
    </table>

    <NextDialog
      ref="formDialog"
      width="2xl"
      overflow-y-auto
      :title="$t('WHATSAPP_TEMPLATES.FORM.TITLE')"
      :show-cancel-button="false"
      :show-confirm-button="false"
    >
      <WhatsappTemplateForm
        :inbox-id="inbox.id"
        @created="onCreated"
        @cancel="$refs.formDialog.close()"
      />
    </NextDialog>

    <NextDialog
      ref="deleteDialog"
      type="alert"
      :title="$t('WHATSAPP_TEMPLATES.DELETE.CONFIRM_TITLE')"
      :description="deleteConfirmMessage"
      :confirm-button-label="$t('WHATSAPP_TEMPLATES.DELETE.CONFIRM_YES')"
      :cancel-button-label="$t('WHATSAPP_TEMPLATES.DELETE.CONFIRM_NO')"
      :is-loading="isDeleting"
      @confirm="confirmDelete"
    />
  </div>
</template>
