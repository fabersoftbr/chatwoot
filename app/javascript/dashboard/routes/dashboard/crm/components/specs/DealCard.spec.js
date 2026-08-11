import { shallowMount } from '@vue/test-utils';
import DealCard from '../DealCard.vue';

const baseDeal = {
  id: 1,
  title: 'Big deal',
  value_cents: 0,
  currency: 'BRL',
  temperature: 'hot',
  next_action: 'Call back',
  next_action_at: null,
  closed_at: null,
  contact: { id: 1, name: 'Jane Doe' },
  assignee: null,
};

// The global vitest setup (vitest.setup.js) already installs the real
// vue-i18n plugin with the app's `en` messages, so `useI18n()` resolves
// actual translated strings here rather than needing a $t mock.
const mountCard = deal =>
  shallowMount(DealCard, {
    props: { deal },
    global: {
      stubs: {
        Avatar: { template: '<span />' },
      },
    },
  });

describe('DealCard', () => {
  it('renders the deal title and contact name', () => {
    const wrapper = mountCard(baseDeal);
    expect(wrapper.text()).toContain('Big deal');
    expect(wrapper.text()).toContain('Jane Doe');
  });

  it('renders a formatted value when the deal has one', () => {
    const wrapper = mountCard({ ...baseDeal, value_cents: 1200000 });
    expect(wrapper.text()).not.toContain('No value');
    expect(wrapper.text()).toMatch(/12\.000|12,000/);
  });

  it('renders the no-value label when the deal has no value', () => {
    const wrapper = mountCard({ ...baseDeal, value_cents: 0 });
    expect(wrapper.text()).toContain('No value');
  });

  it('renders the overdue badge for an open deal past its next action', () => {
    const wrapper = mountCard({
      ...baseDeal,
      next_action_at: '2020-01-01T00:00:00Z',
      closed_at: null,
    });
    expect(wrapper.text()).toContain('Overdue');
  });

  it('does not render the overdue badge for a closed deal', () => {
    const wrapper = mountCard({
      ...baseDeal,
      next_action_at: '2020-01-01T00:00:00Z',
      closed_at: '2020-02-01T00:00:00Z',
    });
    expect(wrapper.text()).not.toContain('Overdue');
  });

  it('emits click with the deal when clicked', async () => {
    const wrapper = mountCard(baseDeal);
    await wrapper.find('button').trigger('click');
    expect(wrapper.emitted('click')[0]).toEqual([baseDeal]);
  });
});
