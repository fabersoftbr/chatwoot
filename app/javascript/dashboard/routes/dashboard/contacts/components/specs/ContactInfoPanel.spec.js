import { shallowMount } from '@vue/test-utils';
import { createStore } from 'vuex';
import ContactInfoPanel from '../ContactInfoPanel.vue';
import ContactDeals from 'dashboard/routes/dashboard/conversation/contact/ContactDeals.vue';
import AccordionItem from 'dashboard/components/Accordion/AccordionItem.vue';

const contact = { id: 1, name: 'Jane Doe' };

// `is_ct_deals_open: true` forces the accordion open so the mounted tree
// actually contains ContactDeals — the section defaults to closed (matching
// its sibling sections), and AccordionItem only renders its slot when open.
const buildStore = (
  isFeatureEnabled,
  uiSettings = { is_ct_deals_open: true }
) =>
  createStore({
    modules: {
      auth: {
        namespaced: false,
        getters: {
          getCurrentAccountId: () => 1,
          getUISettings: () => uiSettings,
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

describe('ContactInfoPanel', () => {
  it('does not render ContactDeals when the deals feature flag is off', () => {
    const wrapper = shallowMount(ContactInfoPanel, {
      props: { contact },
      global: { plugins: [buildStore(false)] },
    });

    expect(wrapper.findComponent(ContactDeals).exists()).toBe(false);
  });

  it('renders ContactDeals when the deals feature flag is on and the contact has an id', () => {
    // AccordionItem must render for real here (not the shallow stub) —
    // its own template gates the default slot behind `v-if="isOpen"`, so a
    // stub would never mount ContactDeals regardless of the open state.
    const wrapper = shallowMount(ContactInfoPanel, {
      props: { contact },
      global: {
        plugins: [buildStore(true)],
        stubs: { AccordionItem: false },
      },
    });

    expect(wrapper.findComponent(ContactDeals).exists()).toBe(true);
  });

  it('collapses the deals accordion section by default, like its sibling sections', () => {
    const wrapper = shallowMount(ContactInfoPanel, {
      props: { contact },
      global: { plugins: [buildStore(true, {})] },
    });

    const accordionItems = wrapper.findAllComponents(AccordionItem);
    const dealsAccordion = accordionItems.find(
      item => item.props('title') === 'Deals'
    );
    expect(dealsAccordion.props('isOpen')).toBe(false);
  });
});
