import { shallowMount } from '@vue/test-utils';
import { createStore } from 'vuex';
import ContactPanel from '../components/ContactPanel.vue';
import ContactDeals from 'dashboard/routes/dashboard/conversation/contact/ContactDeals.vue';

const contact = { id: 1, name: 'Jane Doe' };

const buildStore = isFeatureEnabled =>
  createStore({
    modules: {
      auth: {
        namespaced: false,
        getters: {
          getCurrentAccountId: () => 1,
        },
      },
      accounts: {
        namespaced: true,
        getters: {
          isFeatureEnabledonAccount: () => () => isFeatureEnabled,
        },
      },
    },
  });

describe('ContactPanel', () => {
  it('does not render ContactDeals when the deals feature flag is off', () => {
    const wrapper = shallowMount(ContactPanel, {
      props: { contact },
      global: { plugins: [buildStore(false)] },
    });

    expect(wrapper.findComponent(ContactDeals).exists()).toBe(false);
  });

  it('renders ContactDeals when the deals feature flag is on and the contact has an id', () => {
    const wrapper = shallowMount(ContactPanel, {
      props: { contact },
      global: { plugins: [buildStore(true)] },
    });

    expect(wrapper.findComponent(ContactDeals).exists()).toBe(true);
  });
});
