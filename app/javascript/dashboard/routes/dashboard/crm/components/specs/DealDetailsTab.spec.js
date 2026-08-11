import { computed } from 'vue';
import { mount } from '@vue/test-utils';
import { useMapGetter } from 'dashboard/composables/store';
import DealDetailsTab from '../DealDetailsTab.vue';

vi.mock('dashboard/composables/store');

const stages = [
  { id: 1, name: 'New' },
  { id: 2, name: 'Qualified' },
];

const baseDeal = {
  id: 1,
  title: 'Big deal',
  description: 'Some notes',
  value_cents: 120000,
  temperature: 'hot',
  deal_stage_id: 1,
  expected_close_on: '2026-09-01',
  next_action: 'Call back',
  next_action_at: '2026-08-15T10:00',
  contact: { id: 1, name: 'Jane Doe' },
};

// The global vitest setup (vitest.setup.js) already installs the real
// vue-i18n plugin with the app's `en` messages, so `useI18n()` resolves
// actual translated strings here rather than needing a $t mock.
const mountTab = deal => mount(DealDetailsTab, { props: { deal } });

describe('DealDetailsTab', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    useMapGetter.mockImplementation(getter => {
      const mockValues = {
        'deals/getStages': stages,
      };
      return computed(() => mockValues[getter]);
    });
  });

  it('renders the form fields pre-filled from the deal prop', () => {
    const wrapper = mountTab(baseDeal);

    expect(wrapper.get('input').element.value).toBe('Big deal');
    expect(wrapper.get('select').element.value).toBe('1');
    expect(wrapper.get('textarea').element.value).toBe('Some notes');
  });

  it('emits update with only the title field when the title input is blurred after a change', async () => {
    const wrapper = mountTab(baseDeal);

    const titleInput = wrapper.get('input');
    await titleInput.setValue('Updated deal title');
    await titleInput.trigger('blur');

    expect(wrapper.emitted('update')).toBeTruthy();
    expect(wrapper.emitted('update')[0]).toEqual([
      { title: 'Updated deal title' },
    ]);
  });

  it('emits update with only the deal_stage_id field when the stage select changes', async () => {
    const wrapper = mountTab(baseDeal);

    const select = wrapper.get('select');
    await select.setValue('2');

    expect(wrapper.emitted('update')).toBeTruthy();
    expect(wrapper.emitted('update')[0]).toEqual([{ deal_stage_id: 2 }]);
  });

  it('re-syncs the form fields when the deal prop changes', async () => {
    const wrapper = mountTab(baseDeal);

    await wrapper.setProps({
      deal: { ...baseDeal, title: 'A different deal' },
    });

    expect(wrapper.get('input').element.value).toBe('A different deal');
  });
});
