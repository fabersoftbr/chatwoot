<script>
import { useAlert } from 'dashboard/composables';
import WhatsappTemplatesAPI from 'dashboard/api/channel/whatsappTemplates';
import NextButton from 'dashboard/components-next/button/Button.vue';

const NAME_REGEX = /^[a-z0-9_]+$/;
// Mirrors TemplateBuilder#variable_indexes server-side.
const VARIABLE_REGEX = /\{\{(\d+)\}\}/g;

export default {
  components: { NextButton },
  props: {
    inboxId: {
      type: [Number, String],
      required: true,
    },
  },
  emits: ['created', 'cancel'],
  data() {
    return {
      name: '',
      language: 'pt_BR',
      category: 'UTILITY',
      body: '',
      examples: {},
      isSubmitting: false,
      // AUTHENTICATION needs an OTP button plus a security footer this form does
      // not build, so Meta rejects every submission. See TemplateBuilder::CATEGORIES.
      categories: ['UTILITY', 'MARKETING'],
      languages: ['pt_BR', 'en_US', 'es_ES'],
    };
  },
  computed: {
    variables() {
      const found = [...this.body.matchAll(VARIABLE_REGEX)].map(match =>
        Number(match[1])
      );
      return [...new Set(found)].sort((a, b) => a - b);
    },
    hasValidSequence() {
      return this.variables.every((value, index) => value === index + 1);
    },
    isNameValid() {
      return NAME_REGEX.test(this.name);
    },
    isValid() {
      return (
        this.isNameValid &&
        this.body.trim() !== '' &&
        this.hasValidSequence &&
        this.variables.every(index => (this.examples[index] || '').trim())
      );
    },
  },
  methods: {
    onNameInput(event) {
      this.name = event.target.value.toLowerCase();
    },
    async submit() {
      if (!this.isValid || this.isSubmitting) return;
      this.isSubmitting = true;
      try {
        await WhatsappTemplatesAPI.create(this.inboxId, {
          name: this.name,
          language: this.language,
          category: this.category,
          body: this.body,
          examples: this.variables.map(index => this.examples[index]),
        });
        useAlert(this.$t('WHATSAPP_TEMPLATES.API.CREATE_SUCCESS'));
        this.$emit('created');
      } catch (error) {
        // Meta's own wording explains why the template was refused, show it as is.
        useAlert(
          error?.response?.data?.error ||
            this.$t('WHATSAPP_TEMPLATES.API.ERROR')
        );
      } finally {
        this.isSubmitting = false;
      }
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-4">
    <label class="flex flex-col gap-1 text-sm text-n-slate-12">
      {{ $t('WHATSAPP_TEMPLATES.FORM.NAME') }}
      <input
        :value="name"
        data-testid="template-name"
        type="text"
        :placeholder="$t('WHATSAPP_TEMPLATES.FORM.NAME_PLACEHOLDER')"
        @input="onNameInput"
      />
      <span
        class="text-xs"
        :class="name && !isNameValid ? 'text-n-ruby-11' : 'text-n-slate-11'"
      >
        {{ $t('WHATSAPP_TEMPLATES.FORM.NAME_HINT') }}
      </span>
    </label>

    <label class="flex flex-col gap-1 text-sm text-n-slate-12">
      {{ $t('WHATSAPP_TEMPLATES.FORM.LANGUAGE') }}
      <select v-model="language">
        <option v-for="item in languages" :key="item" :value="item">
          {{ item }}
        </option>
      </select>
    </label>

    <label class="flex flex-col gap-1 text-sm text-n-slate-12">
      {{ $t('WHATSAPP_TEMPLATES.FORM.CATEGORY') }}
      <select v-model="category">
        <option v-for="item in categories" :key="item" :value="item">
          {{ item }}
        </option>
      </select>
    </label>

    <label class="flex flex-col gap-1 text-sm text-n-slate-12">
      {{ $t('WHATSAPP_TEMPLATES.FORM.BODY') }}
      <textarea
        v-model="body"
        rows="4"
        :placeholder="$t('WHATSAPP_TEMPLATES.FORM.BODY_PLACEHOLDER')"
      />
      <span class="text-xs text-n-slate-11">
        {{ $t('WHATSAPP_TEMPLATES.FORM.BODY_HINT') }}
      </span>
    </label>

    <label
      v-for="index in variables"
      :key="index"
      class="flex flex-col gap-1 text-sm text-n-slate-12"
    >
      {{ $t('WHATSAPP_TEMPLATES.FORM.EXAMPLE_LABEL', { index }) }}
      <input
        v-model="examples[index]"
        data-testid="example-input"
        type="text"
      />
    </label>

    <p class="text-xs text-n-slate-11">
      {{ $t('WHATSAPP_TEMPLATES.FORM.PENDING_NOTICE') }}
    </p>

    <div class="flex justify-end gap-2">
      <NextButton
        faded
        slate
        type="button"
        :label="$t('WHATSAPP_TEMPLATES.FORM.CANCEL')"
        @click="$emit('cancel')"
      />
      <NextButton
        type="button"
        :label="$t('WHATSAPP_TEMPLATES.FORM.SUBMIT')"
        :is-loading="isSubmitting"
        :disabled="!isValid || isSubmitting"
        @click="submit"
      />
    </div>
  </div>
</template>
