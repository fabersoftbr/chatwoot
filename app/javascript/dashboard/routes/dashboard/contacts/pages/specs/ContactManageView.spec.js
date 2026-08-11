import { shallowMount } from '@vue/test-utils';
import { createStore } from 'vuex';
import ContactManageView from '../ContactManageView.vue';
import ContactDeals from 'dashboard/routes/dashboard/conversation/contact/ContactDeals.vue';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';

const contact = { id: 1, name: 'Jane Doe' };

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { contactId: 1, accountId: 1 } }),
  useRouter: () => ({ back: () => {}, push: () => {} }),
}));

const buildStore = isDealsFeatureEnabled =>
  createStore({
    modules: {
      contacts: {
        namespaced: true,
        getters: {
          getContactById: () => () => contact,
          getUIFlags: () => ({
            isFetchingItem: false,
            isMerging: false,
            isUpdating: false,
          }),
        },
        actions: { show: () => {}, fetchContactableInbox: () => {} },
      },
      accounts: {
        namespaced: true,
        getters: {
          isFeatureEnabledonAccount: () => (accountId, flag) =>
            flag === FEATURE_FLAGS.DEALS && isDealsFeatureEnabled,
        },
      },
      attributes: { namespaced: true, actions: { get: () => {} } },
      contactNotes: { namespaced: true, actions: { get: () => {} } },
      contactConversations: { namespaced: true, actions: { get: () => {} } },
    },
    getters: { getCurrentAccountId: () => 1 },
  });

// shallowMount's default stub for ContactsDetailsLayout ignores its named
// slots entirely, which would hide the sidebarHeader/sidebar content
// (including the tab bar and ContactDeals) from the render tree. Replace it
// with a passthrough so those slots actually render (still as stubs).
const ContactsDetailsLayoutStub = {
  template:
    '<div><slot /><slot name="sidebarHeader" /><slot name="sidebar" /></div>',
};

const mountView = isDealsFeatureEnabled => {
  const wrapper = shallowMount(ContactManageView, {
    global: {
      plugins: [buildStore(isDealsFeatureEnabled)],
      stubs: { ContactsDetailsLayout: ContactsDetailsLayoutStub },
    },
  });
  // Simulate the user clicking the (stubbed) "Deals" tab so the block's
  // own `v-if` gets a chance to render — the flag gate on the parent
  // (asserted below) is what must hold regardless of tab state.
  wrapper.findComponent(TabBar).vm.$emit('tabChanged', { value: 'deals' });
  return wrapper;
};

describe('ContactManageView', () => {
  it('does not render ContactDeals when the deals feature flag is off, even on the deals tab', async () => {
    const wrapper = mountView(false);
    await wrapper.vm.$nextTick();
    expect(wrapper.findComponent(ContactDeals).exists()).toBe(false);
  });

  it('renders ContactDeals on the deals tab when the deals feature flag is on', async () => {
    const wrapper = mountView(true);
    await wrapper.vm.$nextTick();
    const dealsComponent = wrapper.findComponent(ContactDeals);
    expect(dealsComponent.exists()).toBe(true);
    expect(dealsComponent.props('contactId')).toBe(contact.id);
  });
});
