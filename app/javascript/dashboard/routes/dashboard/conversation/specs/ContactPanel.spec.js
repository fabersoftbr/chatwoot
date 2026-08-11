import { shallowMount } from '@vue/test-utils';
import { createStore } from 'vuex';
import ContactPanel from '../ContactPanel.vue';
import ContactDeals from '../contact/ContactDeals.vue';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';

// ContactPanel reads Linear's cloud-feature gate via `useAccount`, which
// depends on `vue-router` — stub it out, this spec only cares about deals.
vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({ isCloudFeatureEnabled: () => false }),
}));

const contact = { id: 1, name: 'Jane Doe' };

const buildStore = isDealsFeatureEnabled =>
  createStore({
    getters: {
      getSelectedChat: () => ({ meta: { sender: { id: contact.id } } }),
      getUISettings: () => ({}),
    },
    actions: {
      updateUISettings: () => {},
    },
    modules: {
      conversationMetadata: {
        namespaced: true,
        getters: { getConversationMetadata: () => () => ({}) },
      },
      contacts: {
        namespaced: true,
        getters: { getContact: () => () => contact },
        actions: { show: () => {} },
      },
      integrations: {
        namespaced: true,
        getters: { getIntegration: () => () => ({ enabled: false }) },
        actions: { get: () => {} },
      },
      accounts: {
        namespaced: true,
        getters: {
          isFeatureEnabledonAccount: () => (accountId, flag) =>
            flag === FEATURE_FLAGS.DEALS && isDealsFeatureEnabled,
        },
      },
      attributes: {
        namespaced: true,
        actions: { get: () => {} },
      },
    },
  });

const mountContactPanel = isDealsFeatureEnabled =>
  shallowMount(ContactPanel, {
    props: { conversationId: 1 },
    global: { plugins: [buildStore(isDealsFeatureEnabled)] },
  });

describe('ContactPanel', () => {
  it('does not render ContactDeals when the deals feature flag is off', () => {
    const wrapper = mountContactPanel(false);
    expect(wrapper.findComponent(ContactDeals).exists()).toBe(false);
  });

  it('renders ContactDeals when the deals feature flag is on and the contact has an id', () => {
    const wrapper = mountContactPanel(true);
    const dealsComponent = wrapper.findComponent(ContactDeals);
    expect(dealsComponent.exists()).toBe(true);
    expect(dealsComponent.props('contactId')).toBe(contact.id);
  });
});
