import { shallowMount } from '@vue/test-utils';
import { createStore } from 'vuex';
import Sidebar from '../Sidebar.vue';
import SidebarGroup from '../SidebarGroup.vue';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';

// Sidebar.vue builds its nav from `useAccount`/`useConfig`, which in turn
// depend on `vue-router` and cloud/enterprise config we don't care about
// here — stub them out so the spec only has to reason about `menuItems`.
vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({
    accountScopedRoute: (name, params, query) => ({ name, params, query }),
    isOnChatwootCloud: { value: false },
  }),
}));

vi.mock('dashboard/composables/useConfig', () => ({
  useConfig: () => ({ isEnterprise: false }),
}));

vi.mock('dashboard/composables/utils/useKbd', () => ({
  useKbd: () => 'Ctrl K',
}));

vi.mock('../useSidebarKeyboardShortcuts', () => ({
  useSidebarKeyboardShortcuts: () => {},
}));

const buildStore = (isDealsFeatureEnabled = false) =>
  createStore({
    state: { uiSettings: { uiSettings: {} } },
    getters: {
      getCurrentAccountId: () => 1,
      getCurrentUserID: () => 1,
      getUISettings: () => ({}),
    },
    modules: {
      accounts: {
        namespaced: true,
        getters: {
          isFeatureEnabledonAccount: () => (accountId, flag) =>
            flag === FEATURE_FLAGS.DEALS && isDealsFeatureEnabled,
          isRTL: () => false,
        },
      },
      globalConfig: {
        namespaced: true,
        getters: { isACustomBrandedInstance: () => false },
      },
      inboxes: {
        namespaced: true,
        getters: { getInboxes: () => [] },
        actions: { get: () => {} },
      },
      labels: {
        namespaced: true,
        getters: { getLabelsOnSidebar: () => [] },
        actions: { get: () => {} },
      },
      conversationUnreadCounts: {
        namespaced: true,
        getters: {
          getAllUnreadCount: () => 0,
          getInboxUnreadCount: () => () => 0,
          getLabelUnreadCount: () => () => 0,
          getTeamUnreadCount: () => () => 0,
          getMentionsUnreadCount: () => 0,
          getParticipatingUnreadCount: () => 0,
          getUnattendedUnreadCount: () => 0,
          getFolderUnreadCount: () => () => 0,
        },
        actions: { clear: () => {}, get: () => {} },
      },
      teams: {
        namespaced: true,
        getters: { getMyTeams: () => [] },
        actions: { get: () => {} },
      },
      customViews: {
        namespaced: true,
        getters: {
          getContactCustomViews: () => [],
          getConversationCustomViews: () => [],
        },
        actions: { get: () => {} },
      },
      sidebarSortPreferences: {
        namespaced: true,
        getters: { getSectionSort: () => () => undefined },
        actions: { initialize: () => {} },
      },
      notifications: {
        namespaced: true,
        actions: { unReadCount: () => {} },
      },
      attributes: {
        namespaced: true,
        actions: { get: () => {} },
      },
    },
  });

const mountSidebar = isDealsFeatureEnabled =>
  shallowMount(Sidebar, {
    props: { isMobileSidebarOpen: false },
    global: { plugins: [buildStore(isDealsFeatureEnabled)] },
  });

describe('Sidebar', () => {
  it('does not render a CRM nav entry when the deals feature flag is off', () => {
    const wrapper = mountSidebar(false);
    const groups = wrapper.findAllComponents(SidebarGroup);
    expect(groups.some(group => group.props('name') === 'CRM')).toBe(false);
  });

  it('renders a CRM nav entry pointing at deals_board when the deals feature flag is on', () => {
    const wrapper = mountSidebar(true);
    const groups = wrapper.findAllComponents(SidebarGroup);
    const crmGroup = groups.find(group => group.props('name') === 'CRM');

    expect(crmGroup).toBeTruthy();
    expect(crmGroup.props('to')).toEqual({
      name: 'deals_board',
      params: undefined,
      query: undefined,
    });
    expect(crmGroup.props('icon')).toBe('i-lucide-handshake');
  });
});
