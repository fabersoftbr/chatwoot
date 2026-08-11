import { computed } from 'vue';
import { mount, flushPromises } from '@vue/test-utils';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import ContactDeals from '../ContactDeals.vue';

vi.mock('dashboard/composables/store');

const stages = [
  { id: 1, name: 'New', stage_type: 'open' },
  { id: 2, name: 'Qualified', stage_type: 'open' },
  { id: 3, name: 'Won', stage_type: 'won' },
];

const openDeal = {
  id: 1,
  title: 'Big deal',
  deal_stage_id: 1,
  temperature: 'hot',
  value_cents: 120000,
  currency: 'BRL',
  contact: { name: 'Ana' },
};

const lastStageDeal = {
  id: 2,
  title: 'Almost there',
  deal_stage_id: 2,
  temperature: 'warm',
  value_cents: 50000,
  currency: 'BRL',
  contact: { name: 'Bruno' },
};

const wonDeal = {
  id: 3,
  title: 'Closed deal',
  deal_stage_id: 3,
  temperature: 'cold',
  value_cents: 90000,
  currency: 'BRL',
  contact: { name: 'Carla' },
};

// The global vitest setup (vitest.setup.js) already installs the real
// vue-i18n plugin with the app's `en` messages, so `useI18n()` resolves
// actual translated strings here rather than needing a $t mock.
const mountContactDeals = async (deals, { contactId = 7 } = {}) => {
  const dispatch = vi.fn(action => {
    if (action === 'deals/fetchByContact') return Promise.resolve(deals);
    return Promise.resolve();
  });
  useStore.mockReturnValue({ dispatch });
  useMapGetter.mockImplementation(getter => {
    const mockValues = {
      'deals/getStages': stages,
      'contacts/getContacts': [],
    };
    return computed(() => mockValues[getter]);
  });

  const wrapper = mount(ContactDeals, { props: { contactId } });
  await flushPromises();
  return { wrapper, dispatch };
};

describe('ContactDeals', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders open deals with title and formatted value', async () => {
    const { wrapper } = await mountContactDeals([openDeal, wonDeal]);

    expect(wrapper.text()).toContain('Big deal');
    expect(wrapper.text()).toContain('R$');
  });

  it('renders a closed (won) deal instead of filtering it out', async () => {
    const { wrapper } = await mountContactDeals([openDeal, wonDeal]);

    expect(wrapper.text()).toContain('Closed deal');
  });

  it('renders the empty state when the contact has no deals at all', async () => {
    const { wrapper } = await mountContactDeals([]);

    expect(wrapper.text()).toContain('No deals for this contact');
  });

  it('sums only won-stage deals into a formatted won total, rendered under the list', async () => {
    const { wrapper } = await mountContactDeals([
      openDeal,
      lastStageDeal,
      wonDeal,
    ]);

    // Only wonDeal (90000 cents) counts toward the total.
    expect(wrapper.text()).toContain('Total won');
    expect(wrapper.text()).toContain('R$\xa0900');
  });

  it('does not render a won total when there are no won deals', async () => {
    const { wrapper } = await mountContactDeals([openDeal, lastStageDeal]);

    expect(wrapper.text()).not.toContain('Total won');
  });

  it('does not render an advance button for a deal in a non-open (closed) stage', async () => {
    const { wrapper } = await mountContactDeals([wonDeal]);

    const advanceButtons = wrapper
      .findAll('button')
      .filter(btn => btn.text().startsWith('>'));
    expect(advanceButtons).toHaveLength(0);
  });

  it('does not render an advance button for a deal already in the last open stage', async () => {
    const { wrapper } = await mountContactDeals([lastStageDeal]);

    const advanceButtons = wrapper
      .findAll('button')
      .filter(btn => btn.text().startsWith('>'));
    expect(advanceButtons).toHaveLength(0);
  });

  it('dispatches deals/move with the next open stage id when advance is clicked, then refetches', async () => {
    const { wrapper, dispatch } = await mountContactDeals([openDeal]);

    const advanceButton = wrapper
      .findAll('button')
      .find(btn => btn.text().startsWith('>'));
    expect(advanceButton).toBeTruthy();

    dispatch.mockClear();
    await advanceButton.trigger('click');
    await flushPromises();

    expect(dispatch).toHaveBeenCalledWith('deals/move', {
      id: openDeal.id,
      stageId: 2,
      position: 0,
    });
    expect(dispatch).toHaveBeenCalledWith('deals/fetchByContact', 7);
  });
});
