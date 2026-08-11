<script>
const NAME_REGEX = /^[a-z0-9_]+$/;
const VARIABLE_REGEX = /\{\{(\d+)\}\}/g;

export default {
  props: {
    isSubmitting: {
      type: Boolean,
      default: false,
    },
  },
  emits: ['submit', 'cancel'],
  data() {
    return {
      name: '',
      language: 'pt_BR',
      category: 'UTILITY',
      body: '',
      examples: {},
      categories: ['UTILITY', 'MARKETING', 'AUTHENTICATION'],
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
    onSubmit() {
      if (!this.isValid) return;
      this.$emit('submit', {
        name: this.name,
        language: this.language,
        category: this.category,
        body: this.body,
        examples: this.variables.map(index => this.examples[index]),
      });
    },
  },
};
</script>

<template>
  <form class="flex flex-col gap-4" @submit.prevent="onSubmit">
    <label :class="{ error: name && !isNameValid }">
      {{ $t('WHATSAPP_TEMPLATES.SETTINGS.FORM.NAME.LABEL') }}
      <input
        :value="name"
        type="text"
        :placeholder="$t('WHATSAPP_TEMPLATES.SETTINGS.FORM.NAME.PLACEHOLDER')"
        @input="onNameInput"
      />
      <span v-if="name && !isNameValid" class="message">
        {{ $t('WHATSAPP_TEMPLATES.SETTINGS.FORM.NAME.ERROR') }}
      </span>
      <span v-else class="text-xs text-slate-600 dark:text-slate-400">
        {{ $t('WHATSAPP_TEMPLATES.SETTINGS.FORM.NAME.HELP') }}
      </span>
    </label>

    <label>
      {{ $t('WHATSAPP_TEMPLATES.SETTINGS.FORM.LANGUAGE.LABEL') }}
      <select v-model="language">
        <option v-for="item in languages" :key="item" :value="item">
          {{ item }}
        </option>
      </select>
    </label>

    <label>
      {{ $t('WHATSAPP_TEMPLATES.SETTINGS.FORM.CATEGORY.LABEL') }}
      <select v-model="category">
        <option v-for="item in categories" :key="item" :value="item">
          {{ item }}
        </option>
      </select>
    </label>

    <label>
      {{ $t('WHATSAPP_TEMPLATES.SETTINGS.FORM.BODY.LABEL') }}
      <textarea
        v-model="body"
        rows="4"
        :placeholder="$t('WHATSAPP_TEMPLATES.SETTINGS.FORM.BODY.PLACEHOLDER')"
      />
      <span class="text-xs text-slate-600 dark:text-slate-400">
        {{ $t('WHATSAPP_TEMPLATES.SETTINGS.FORM.BODY.HELP') }}
      </span>
    </label>

    <div v-if="variables.length" class="flex flex-col gap-2">
      <span class="text-sm font-medium">
        {{ $t('WHATSAPP_TEMPLATES.SETTINGS.FORM.EXAMPLES.LABEL') }}
      </span>
      <label v-for="index in variables" :key="index">
        <input
          v-model="examples[index]"
          type="text"
          :placeholder="
            $t('WHATSAPP_TEMPLATES.SETTINGS.FORM.EXAMPLES.PLACEHOLDER', {
              variable: `{{${index}}}`,
            })
          "
        />
      </label>
      <span class="text-xs text-slate-600 dark:text-slate-400">
        {{ $t('WHATSAPP_TEMPLATES.SETTINGS.FORM.EXAMPLES.HELP') }}
      </span>
    </div>

    <div class="flex gap-2 justify-end">
      <woot-button variant="clear" @click.prevent="$emit('cancel')">
        {{ $t('WHATSAPP_TEMPLATES.SETTINGS.FORM.CANCEL') }}
      </woot-button>
      <woot-button
        type="submit"
        :is-loading="isSubmitting"
        :is-disabled="!isValid || isSubmitting"
      >
        {{ $t('WHATSAPP_TEMPLATES.SETTINGS.FORM.SUBMIT') }}
      </woot-button>
    </div>
  </form>
</template>
