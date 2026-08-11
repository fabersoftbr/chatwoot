import { computed } from 'vue';
import { mount } from '@vue/test-utils';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import DealFilters from '../DealFilters.vue';

vi.mock('dashboard/composables/store');

const agents = [
  { id: 1, name: 'Jane Doe' },
  { id: 2, name: 'John Smith' },
];

const mountFilters = (dispatch = vi.fn(), agentList = agents) => {
  useStore.mockReturnValue({ dispatch });
  useMapGetter.mockImplementation(getter => {
    const mockValues = { 'agents/getAgents': agentList };
    return computed(() => mockValues[getter]);
  });
  return mount(DealFilters);
};

describe('DealFilters', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('dispatches agents/get on mount when the agent list is empty', () => {
    const dispatch = vi.fn();
    mountFilters(dispatch, []);

    expect(dispatch).toHaveBeenCalledWith('agents/get');
  });

  it('does not dispatch agents/get when agents are already loaded', () => {
    const dispatch = vi.fn();
    mountFilters(dispatch, agents);

    expect(dispatch).not.toHaveBeenCalledWith('agents/get');
  });

  it('emits change with { q } when typing in the search box', async () => {
    const wrapper = mountFilters();

    await wrapper
      .find('input[type="text"], input:not([type])')
      .setValue('acme');

    const emitted = wrapper.emitted('change');
    expect(emitted).toBeTruthy();
    expect(emitted[emitted.length - 1]).toEqual([{ q: 'acme' }]);
  });

  it('emits change with the temperature when a temperature is selected', async () => {
    const wrapper = mountFilters();

    const selects = wrapper.findAll('select');
    const temperatureSelect = selects[1];
    await temperatureSelect.setValue('hot');

    const emitted = wrapper.emitted('change');
    expect(emitted[emitted.length - 1]).toEqual([{ temperature: 'hot' }]);
  });

  it('emits overdue: true when toggled on and omits it entirely when toggled off', async () => {
    const wrapper = mountFilters();

    const checkbox = wrapper.find('input[type="checkbox"]');
    await checkbox.setValue(true);

    let emitted = wrapper.emitted('change');
    expect(emitted[emitted.length - 1]).toEqual([{ overdue: true }]);

    await checkbox.setValue(false);

    emitted = wrapper.emitted('change');
    expect(emitted[emitted.length - 1]).toEqual([{}]);
  });

  it('gives every control an accessible name', () => {
    const wrapper = mountFilters();

    const controls = [
      ...wrapper.findAll('input').map(w => w.element),
      ...wrapper.findAll('select').map(w => w.element),
    ];

    expect(controls.length).toBeGreaterThan(0);
    controls.forEach(el => {
      expect(el.getAttribute('aria-label')?.trim()).toBeTruthy();
    });
  });
});
