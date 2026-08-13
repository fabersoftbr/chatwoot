import { computed } from 'vue';
import { shallowMount } from '@vue/test-utils';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import StageManagerDialog from '../StageManagerDialog.vue';

vi.mock('dashboard/composables/store');

const stages = [
  { id: 1, name: 'Novo Lead', color: '#6366F1', position: 0, deals_count: 18 },
  {
    id: 2,
    name: 'Qualificação',
    color: '#F59E0B',
    position: 1,
    deals_count: 1,
  },
  { id: 3, name: 'Ganho', color: '#22C55E', position: 2, deals_count: 0 },
];

let dispatch;

const mountDialog = () => {
  dispatch = vi.fn().mockResolvedValue();
  useStore.mockReturnValue({ dispatch });
  useMapGetter.mockImplementation(getter => {
    const mockValues = { 'deals/getStages': stages };
    return computed(() => mockValues[getter]);
  });
  return shallowMount(StageManagerDialog, {
    props: { pipelineId: 7 },
    global: {
      stubs: { Dialog: { template: '<div><slot /></div>' } },
    },
  });
};

describe('StageManagerDialog', () => {
  it('renders one row per stage with its deal count', () => {
    const wrapper = mountDialog();

    const rows = wrapper.findAll('[data-testid="stage-row"]');
    expect(rows).toHaveLength(3);
    expect(rows[0].text()).toContain('Novo Lead');
    expect(rows[0].text()).toContain('18');
  });

  it('reorders by swapping the moved stage with its neighbour', async () => {
    const wrapper = mountDialog();

    await wrapper
      .findAll('[data-testid="stage-move-down"]')[0]
      .trigger('click');

    expect(dispatch).toHaveBeenCalledWith('dealStages/reorder', {
      pipelineId: 7,
      stageIds: [2, 1, 3],
    });
  });
});
