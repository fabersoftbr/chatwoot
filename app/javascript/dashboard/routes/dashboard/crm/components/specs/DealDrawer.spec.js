import { computed } from 'vue';
import { mount, flushPromises } from '@vue/test-utils';
import { useAlert } from 'dashboard/composables';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import DealDrawer from '../DealDrawer.vue';

vi.mock('dashboard/composables/store');
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const deal = {
  id: 26,
  title: 'A late deal',
  contact: { name: 'Jane Doe' },
  pipeline_id: 100,
};

const mountDrawer = (dispatch, getDeal) => {
  useStore.mockReturnValue({ dispatch });
  useMapGetter.mockImplementation(getter => {
    const mockValues = {
      'deals/getDeal': getDeal,
      'dealStages/getStages': [],
      'pipelines/getPipelines': [],
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

  it('surfaces the error and re-syncs the form when an inline edit is rejected by the store', async () => {
    const dispatch = vi
      .fn()
      .mockImplementation(action =>
        action === 'deals/update'
          ? Promise.reject(new Error('Title is too long.'))
          : Promise.resolve()
      );
    const wrapper = mountDrawer(dispatch, () => deal);

    const titleInput = wrapper.get('input');
    await titleInput.setValue('An unacceptably long title');
    await titleInput.trigger('blur');
    await flushPromises();

    expect(dispatch).toHaveBeenCalledWith('deals/update', {
      id: 26,
      title: 'An unacceptably long title',
    });
    expect(useAlert).toHaveBeenCalledWith('Title is too long.');
    // The remounted tab re-seeds its form from the (unchanged) store value.
    expect(wrapper.get('input').element.value).toBe('A late deal');
  });

  it('renders a close button in the header that emits close when clicked', async () => {
    const wrapper = mountDrawer(vi.fn(), () => deal);

    const closeButton = wrapper.get('header button');
    expect(closeButton.attributes('aria-label')).toBe('Close');

    await closeButton.trigger('click');

    expect(wrapper.emitted('close')).toHaveLength(1);
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
