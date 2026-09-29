<script>
import WhatsappTemplateForm from 'dashboard/routes/dashboard/settings/inbox/components/WhatsappTemplateForm.vue';
import TemplatesPicker from './TemplatesPicker.vue';
import WhatsAppTemplateReply from './WhatsAppTemplateReply.vue';
export default {
  components: {
    TemplatesPicker,
    WhatsAppTemplateReply,
    WhatsappTemplateForm,
  },
  props: {
    show: {
      type: Boolean,
      default: false,
    },
    inboxId: {
      type: Number,
      default: undefined,
    },
    // Creating a template writes to Meta's WABA, which only the Cloud API provider exposes.
    canCreateTemplate: {
      type: Boolean,
      default: false,
    },
  },
  emits: ['onSend', 'cancel', 'update:show'],
  data() {
    return {
      selectedWaTemplate: null,
      isCreatingTemplate: false,
    };
  },
  computed: {
    localShow: {
      get() {
        return this.show;
      },
      set(value) {
        this.$emit('update:show', value);
      },
    },
    modalHeaderContent() {
      if (this.isCreatingTemplate) {
        return this.$t('WHATSAPP_TEMPLATES.FORM.TITLE');
      }
      return this.selectedWaTemplate
        ? this.$t('WHATSAPP_TEMPLATES.MODAL.TEMPLATE_SELECTED_SUBTITLE', {
            templateName: this.selectedWaTemplate.name,
          })
        : this.$t('WHATSAPP_TEMPLATES.MODAL.SUBTITLE');
    },
  },
  methods: {
    pickTemplate(template) {
      this.selectedWaTemplate = template;
    },
    // The template lands on Meta as PENDING, so the picker only shows it once
    // the inbox is refetched with the synced list the create call triggered.
    async onTemplateCreated() {
      this.isCreatingTemplate = false;
      await this.$store.dispatch('inboxes/get');
    },
    onResetTemplate() {
      this.selectedWaTemplate = null;
    },
    onSendMessage(message) {
      this.$emit('onSend', message);
    },
    onClose() {
      this.$emit('cancel');
    },
  },
};
</script>

<template>
  <woot-modal v-model:show="localShow" :on-close="onClose" size="modal-big">
    <woot-modal-header
      :header-title="$t('WHATSAPP_TEMPLATES.MODAL.TITLE')"
      :header-content="modalHeaderContent"
    />
    <div class="row modal-content">
      <WhatsappTemplateForm
        v-if="isCreatingTemplate"
        :inbox-id="inboxId"
        @created="onTemplateCreated"
        @cancel="isCreatingTemplate = false"
      />
      <TemplatesPicker
        v-else-if="!selectedWaTemplate"
        :inbox-id="inboxId"
        :can-create-template="canCreateTemplate"
        @on-select="pickTemplate"
        @on-create="isCreatingTemplate = true"
      />
      <WhatsAppTemplateReply
        v-else
        :template="selectedWaTemplate"
        @reset-template="onResetTemplate"
        @send-message="onSendMessage"
      />
    </div>
  </woot-modal>
</template>

<style scoped>
.modal-content {
  padding: 1.5625rem 2rem;
}
</style>
