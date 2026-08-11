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
};

const lastStageDeal = {
  id: 2,
  title: 'Almost there',
  deal_stage_id: 2,
  temperature: 'warm',
  value_cents: 50000,
  currency: 'BRL',
};

const wonDeal = {
  id: 3,
  title: 'Closed deal',
  deal_stage_id: 3,
  temperature: 'cold',
  value_cents: 90000,
  currency: 'BRL',
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

  it('renders open deals with title, stage, temperature and formatted value, filtering out non-open deals', async () => {
    const { wrapper } = await mountContactDeals([openDeal, wonDeal]);

    expect(wrapper.text()).toContain('Big deal');
    expect(wrapper.text()).toContain('New');
    expect(wrapper.text()).toContain('Hot');
    expect(wrapper.text()).toContain('R$');

    expect(wrapper.text()).not.toContain('Closed deal');
  });

  it('renders the empty state when the contact has no open deals', async () => {
    const { wrapper } = await mountContactDeals([wonDeal]);

    expect(wrapper.text()).toContain('No deals for this contact');
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
