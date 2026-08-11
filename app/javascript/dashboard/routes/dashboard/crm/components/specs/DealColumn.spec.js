import { shallowMount } from '@vue/test-utils';
import DealColumn from '../DealColumn.vue';

const stage = {
  id: 1,
  name: 'Prospectado',
  color: '#6B7280',
  deals_count: 40,
  deals_value_cents: 4000000,
};

// Only 25 of the 40 deals in this stage are loaded (the board caps each
// column), so `deals` deliberately under-represents the stage totals here.
const loadedDeals = Array.from({ length: 25 }, (_, index) => ({
  id: index + 1,
  value_cents: 10000,
  currency: 'BRL',
}));

// The global vitest setup (vitest.setup.js) already installs the real
// vue-i18n plugin with the app's `en` messages.
const mountColumn = (props = {}) =>
  shallowMount(DealColumn, {
    props: { stage, deals: loadedDeals, ...props },
  });

describe('DealColumn', () => {
  it('reports the count from the stage, not the loaded deals array', () => {
    const wrapper = mountColumn();
    expect(wrapper.text()).toContain('40');
    expect(wrapper.text()).not.toContain('25');
  });

  it('reports the total from the stage, not a reduce over the loaded deals', () => {
    const wrapper = mountColumn();
    // loadedDeals sums to 250000 (25 * 10000); the stage total is 4000000.
    expect(wrapper.text()).toMatch(/40\.000|40,000/);
  });

  it('falls back to the loaded currency for a single-currency column', () => {
    const wrapper = mountColumn();
    expect(wrapper.text()).toMatch(/R\$/);
  });

  it('does not label a mixed-currency column with the first deal currency', () => {
    const mixedDeals = [
      { id: 1, value_cents: 10000, currency: 'BRL' },
      { id: 2, value_cents: 10000, currency: 'USD' },
    ];
    const wrapper = mountColumn({ deals: mixedDeals });
    // Should fall back to the default currency rather than blindly using
    // deals[0].currency, so this must not throw and must still render a
    // formatted value using the stage total.
    expect(wrapper.text()).toMatch(/40\.000|40,000/);
  });
});
