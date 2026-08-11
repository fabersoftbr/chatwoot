<script>
import { useAlert } from 'dashboard/composables';
import WhatsappTemplatesAPI from 'dashboard/api/channel/whatsappTemplates';
import WhatsappTemplateForm from '../components/WhatsappTemplateForm.vue';

export default {
  components: { WhatsappTemplateForm },
  props: {
    inbox: {
      type: Object,
      default: () => ({}),
    },
  },
  data() {
    return {
      showForm: false,
      isSubmitting: false,
      templateToDelete: null,
    };
  },
  computed: {
    templates() {
      return this.$store.getters['inboxes/getWhatsAppTemplates'](this.inbox.id);
    },
    hasTemplateToDelete: {
      get() {
        return !!this.templateToDelete;
      },
      set(value) {
        if (!value) this.templateToDelete = null;
      },
    },
  },
  methods: {
    statusClass(status) {
      const normalized = (status || '').toLowerCase();
      if (normalized === 'approved') return 'text-green-600';
      if (normalized === 'rejected') return 'text-red-600';
      return 'text-yellow-600';
    },
    templateBody(template) {
      const component = (template.components || []).find(
        item => item.type === 'BODY'
      );
      return component ? component.text : '';
    },
    async onSubmit(payload) {
      this.isSubmitting = true;
      try {
        await WhatsappTemplatesAPI.create({
          ...payload,
          inbox_id: this.inbox.id,
        });
        await this.$store.dispatch('inboxes/get');
        this.showForm = false;
        useAlert(this.$t('WHATSAPP_TEMPLATES.SETTINGS.FORM.SUCCESS'));
      } catch (error) {
        useAlert(error?.response?.data?.error || error.message);
      } finally {
        this.isSubmitting = false;
      }
    },
    async confirmDelete() {
      const name = this.templateToDelete;
      this.templateToDelete = null;
      try {
        await WhatsappTemplatesAPI.remove({ inboxId: this.inbox.id, name });
        await this.$store.dispatch('inboxes/get');
        useAlert(this.$t('WHATSAPP_TEMPLATES.SETTINGS.DELETE.SUCCESS'));
      } catch (error) {
        useAlert(error?.response?.data?.error || error.message);
      }
    },
  },
};
</script>

<template>
  <div class="mx-8 flex flex-col gap-4">
    <div class="flex items-start justify-between gap-4">
      <div>
        <h4 class="text-base">
          {{ $t('WHATSAPP_TEMPLATES.SETTINGS.TITLE') }}
        </h4>
        <p class="text-sm text-slate-600 dark:text-slate-400">
          {{ $t('WHATSAPP_TEMPLATES.SETTINGS.SUBTITLE') }}
        </p>
      </div>
      <woot-button icon="add" @click="showForm = true">
        {{ $t('WHATSAPP_TEMPLATES.SETTINGS.NEW_TEMPLATE') }}
      </woot-button>
    </div>

    <p v-if="!templates.length" class="text-sm">
      {{ $t('WHATSAPP_TEMPLATES.SETTINGS.EMPTY') }}
    </p>

    <table v-else class="woot-table">
      <thead>
        <tr>
          <th>{{ $t('WHATSAPP_TEMPLATES.SETTINGS.TABLE.NAME') }}</th>
          <th>{{ $t('WHATSAPP_TEMPLATES.SETTINGS.TABLE.LANGUAGE') }}</th>
          <th>{{ $t('WHATSAPP_TEMPLATES.SETTINGS.TABLE.CATEGORY') }}</th>
          <th>{{ $t('WHATSAPP_TEMPLATES.SETTINGS.TABLE.STATUS') }}</th>
          <th>{{ $t('WHATSAPP_TEMPLATES.SETTINGS.TABLE.ACTIONS') }}</th>
        </tr>
      </thead>
      <tbody>
        <tr
          v-for="template in templates"
          :key="`${template.name}-${template.language}`"
        >
          <td>
            <span class="font-medium">{{ template.name }}</span>
            <p class="text-xs text-slate-600 dark:text-slate-400">
              {{ templateBody(template) }}
            </p>
          </td>
          <td>{{ template.language }}</td>
          <td>{{ template.category }}</td>
          <td :class="statusClass(template.status)">{{ template.status }}</td>
          <td>
            <woot-button
              variant="clear"
              color-scheme="alert"
              size="small"
              @click="templateToDelete = template.name"
            >
              {{ $t('WHATSAPP_TEMPLATES.SETTINGS.DELETE.BUTTON') }}
            </woot-button>
          </td>
        </tr>
      </tbody>
    </table>

    <woot-modal v-model:show="showForm" :on-close="() => (showForm = false)">
      <div class="p-8">
        <h4 class="text-base mb-4">
          {{ $t('WHATSAPP_TEMPLATES.SETTINGS.FORM.TITLE') }}
        </h4>
        <WhatsappTemplateForm
          :is-submitting="isSubmitting"
          @submit="onSubmit"
          @cancel="showForm = false"
        />
      </div>
    </woot-modal>

    <woot-delete-modal
      v-model:show="hasTemplateToDelete"
      :on-close="() => (templateToDelete = null)"
      :on-confirm="confirmDelete"
      :title="$t('WHATSAPP_TEMPLATES.SETTINGS.DELETE.CONFIRM_TITLE')"
      :message="
        $t('WHATSAPP_TEMPLATES.SETTINGS.DELETE.CONFIRM_MESSAGE', {
          name: templateToDelete,
        })
      "
      :confirm-text="$t('WHATSAPP_TEMPLATES.SETTINGS.DELETE.CONFIRM_YES')"
      :reject-text="$t('WHATSAPP_TEMPLATES.SETTINGS.DELETE.CONFIRM_NO')"
    />
  </div>
</template>
