import { computed } from 'vue';
import { mount } from '@vue/test-utils';
import { useAlert } from 'dashboard/composables';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import Index from '../Index.vue';

vi.mock('dashboard/composables/store');
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const stages = [
  {
    id: 2,
    name: 'Qualified',
    color: '#00ff00',
    stage_type: 'open',
    position: 1,
  },
  { id: 1, name: 'New', color: '#ff0000', stage_type: 'open', position: 0 },
  { id: 3, name: 'Won', color: '#0000ff', stage_type: 'won', position: 2 },
];

// getStages returns a position-sorted copy, mirroring the real store getter.
const sortedStages = [...stages].sort((a, b) => a.position - b.position);

// The global vitest setup (vitest.setup.js) already installs the real
// vue-i18n plugin with the app's `en` messages, so `useI18n()` resolves
// actual translated strings here rather than needing a $t mock.
const mountPage = dispatch => {
  useStore.mockReturnValue({ dispatch });
  useMapGetter.mockImplementation(getter => {
    const mockValues = { 'dealStages/getStages': sortedStages };
    return computed(() => mockValues[getter]);
  });
  return mount(Index);
};

describe('Deal stages settings page', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders the stage rows from the store getter in position order', () => {
    const wrapper = mountPage(vi.fn().mockResolvedValue());
    const nameInputs = wrapper.findAll(
      'input.grow[aria-label="Name"], input.grow'
    );
    expect(nameInputs.map(w => w.element.value)).toEqual([
      'New',
      'Qualified',
      'Won',
    ]);
  });

  it('dispatches dealStages/create with the typed name and clears the input', async () => {
    const dispatch = vi.fn().mockResolvedValue();
    const wrapper = mountPage(dispatch);

    const newStageInput = wrapper.find('input[placeholder="Name"]');
    await newStageInput.setValue('Negotiation');
    await wrapper.find('button.bg-woot-500').trigger('click');
    await wrapper.vm.$nextTick();

    expect(dispatch).toHaveBeenCalledWith(
      'dealStages/create',
      expect.objectContaining({ name: 'Negotiation' })
    );
    expect(newStageInput.element.value).toBe('');
  });

  it('dispatches dealStages/update with the stage id and new name on blur', async () => {
    const dispatch = vi.fn().mockResolvedValue();
    const wrapper = mountPage(dispatch);

    const rows = wrapper.findAll('.border-slate-100');
    const nameInput = rows[0].find('input.grow');
    await nameInput.setValue('New Renamed');
    await nameInput.trigger('blur');

    expect(dispatch).toHaveBeenCalledWith('dealStages/update', {
      id: 1,
      name: 'New Renamed',
    });
  });

  it('dispatches dealStages/delete, and surfaces an alert on rejection instead of throwing', async () => {
    const dispatch = vi
      .fn()
      .mockImplementation(action =>
        action === 'dealStages/delete'
          ? Promise.reject(new Error('This stage still has deals.'))
          : Promise.resolve()
      );
    const wrapper = mountPage(dispatch);

    const rows = wrapper.findAll('.border-slate-100');
    const deleteButton = rows[0].find('button.text-red-600');

    await expect(deleteButton.trigger('click')).resolves.toBeUndefined();
    await wrapper.vm.$nextTick();
    await wrapper.vm.$nextTick();

    expect(dispatch).toHaveBeenCalledWith('dealStages/delete', 1);
    expect(useAlert).toHaveBeenCalledWith(
      'Move the deals out of this stage first.'
    );
  });

  it('gives every row control an accessible name', () => {
    const wrapper = mountPage(vi.fn().mockResolvedValue());

    const controls = [
      ...wrapper.findAll('input').map(w => w.element),
      ...wrapper.findAll('button').map(w => w.element),
    ];

    expect(controls.length).toBeGreaterThan(0);
    controls.forEach(el => {
      expect(el.getAttribute('aria-label')?.trim()).toBeTruthy();
    });
  });
});
