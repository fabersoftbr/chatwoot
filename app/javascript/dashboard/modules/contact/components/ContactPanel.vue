<script>
import { mapGetters } from 'vuex';
import EditContact from 'dashboard/routes/dashboard/conversation/contact/EditContact.vue';
import NewConversation from 'dashboard/routes/dashboard/conversation/contact/NewConversation.vue';
import AddCustomAttribute from 'dashboard/modules/contact/components/AddCustomAttribute.vue';
import ContactDeals from 'dashboard/routes/dashboard/conversation/contact/ContactDeals.vue';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import ContactIntro from './ContactIntro.vue';
import ContactFields from './ContactFields.vue';

export default {
  components: {
    AddCustomAttribute,
    ContactDeals,
    ContactFields,
    ContactIntro,
    EditContact,
    NewConversation,
  },
  props: {
    contact: {
      type: Object,
      default: () => ({}),
    },
  },
  data() {
    return {
      showCustomAttributeModal: false,
      showEditModal: false,
      showConversationModal: false,
    };
  },
  computed: {
    ...mapGetters({
      isFeatureEnabledonAccount: 'accounts/isFeatureEnabledonAccount',
      accountId: 'getCurrentAccountId',
    }),
    enableNewConversation() {
      return this.contact && this.contact.id;
    },
    isDealsFeatureEnabled() {
      return this.isFeatureEnabledonAccount(
        this.accountId,
        FEATURE_FLAGS.DEALS
      );
    },
  },
  methods: {
    toggleCustomAttributeModal() {
      this.showCustomAttributeModal = !this.showCustomAttributeModal;
    },
    toggleEditModal() {
      this.showEditModal = !this.showEditModal;
    },
    toggleConversationModal() {
      this.showConversationModal = !this.showConversationModal;
    },
    createCustomAttribute(data) {
      const { id } = this.contact;
      const { attributeValue, attributeName } = data;
      const updatedFields = {
        id,
        custom_attributes: {
          [attributeName]: attributeValue,
        },
      };
      this.updateContact(updatedFields);
    },
    updateField(data) {
      const { id } = this.contact;
      const updatedFields = {
        id,
        ...data,
      };
      this.updateContact(updatedFields);
    },
    updateContact(contactItem) {
      this.$store.dispatch('contacts/update', contactItem);
    },
  },
};
</script>

<template>
  <div class="panel">
    <ContactIntro
      :contact="contact"
      @message="toggleConversationModal"
      @edit="toggleEditModal"
    />
    <ContactFields
      :contact="contact"
      @update="updateField"
      @create-attribute="toggleCustomAttributeModal"
    />
    <ContactDeals
      v-if="isDealsFeatureEnabled && contact && contact.id"
      :contact-id="contact.id"
    />
    <EditContact
      v-if="showEditModal"
      :show="showEditModal"
      :contact="contact"
      @cancel="toggleEditModal"
    />
    <NewConversation
      v-if="enableNewConversation"
      :show="showConversationModal"
      :contact="contact"
      @cancel="toggleConversationModal"
    />
    <AddCustomAttribute
      :show="showCustomAttributeModal"
      @cancel="toggleCustomAttributeModal"
      @create="createCustomAttribute"
    />
  </div>
</template>

<style scoped lang="scss">
.panel {
  padding: var(--space-normal) var(--space-normal);
}
</style>
