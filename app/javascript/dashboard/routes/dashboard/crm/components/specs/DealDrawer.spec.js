import { computed } from 'vue';
import { mount } from '@vue/test-utils';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import DealDrawer from '../DealDrawer.vue';

vi.mock('dashboard/composables/store');

const deal = {
  id: 26,
  title: 'A late deal',
  contact: { name: 'Jane Doe' },
};

const mountDrawer = (dispatch, getDeal) => {
  useStore.mockReturnValue({ dispatch });
  useMapGetter.mockImplementation(getter => {
    const mockValues = {
      'deals/getDeal': getDeal,
      'deals/getStages': [],
      'agents/getAgents': [],
    };
    return computed(() => mockValues[getter]);
  });
  return mount(DealDrawer, { props: { dealId: 26 } });
};

describe('DealDrawer', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('dispatches deals/show when the deal is not already in the store', () => {
    // The board only ever loads 25 deals per stage, so a deep link to the
    // 26th card resolves to nothing in the store until fetched directly.
    const dispatch = vi.fn().mockResolvedValue(deal);
    const getDeal = () => undefined;

    mountDrawer(dispatch, getDeal);

    expect(dispatch).toHaveBeenCalledWith('deals/show', 26);
  });

  it('does not dispatch deals/show when the deal is already in the store', () => {
    const dispatch = vi.fn();
    const getDeal = () => deal;

    mountDrawer(dispatch, getDeal);

    expect(dispatch).not.toHaveBeenCalledWith('deals/show', expect.anything());
  });

  it('renders nothing (no crash) while the deal has not loaded yet', () => {
    const dispatch = vi.fn().mockResolvedValue(deal);
    const getDeal = () => undefined;

    const wrapper = mountDrawer(dispatch, getDeal);

    expect(wrapper.find('aside').exists()).toBe(false);
  });
});
