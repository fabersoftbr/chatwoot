import { computed } from 'vue';
import { mount } from '@vue/test-utils';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import DealDetailsTab from '../DealDetailsTab.vue';

vi.mock('dashboard/composables/store');

const stages = [
  { id: 1, name: 'New' },
  { id: 2, name: 'Qualified' },
];

const agents = [
  { id: 1, name: 'Jane Agent' },
  { id: 2, name: 'John Agent' },
];

const baseDeal = {
  id: 1,
  title: 'Big deal',
  description: 'Some notes',
  value_cents: 120000,
  temperature: 'hot',
  deal_stage_id: 1,
  assignee_id: 1,
  currency: 'BRL',
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
  const dispatch = vi.fn();

  beforeEach(() => {
    vi.clearAllMocks();
    useMapGetter.mockImplementation(getter => {
      const mockValues = {
        'deals/getStages': stages,
        'agents/getAgents': agents,
      };
      return computed(() => mockValues[getter]);
    });
    useStore.mockReturnValue({ dispatch });
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

  it('renders the value input in currency units, not cents', () => {
    const wrapper = mountTab({ ...baseDeal, value_cents: 1200000 });

    expect(wrapper.get('input[type="number"]').element.value).toBe('12000');
  });

  it('emits value_cents converted from currency units when the value input is blurred', async () => {
    const wrapper = mountTab(baseDeal);

    const valueInput = wrapper.get('input[type="number"]');
    await valueInput.setValue('500');
    await valueInput.trigger('blur');

    expect(wrapper.emitted('update')).toBeTruthy();
    expect(wrapper.emitted('update')[0]).toEqual([{ value_cents: 50000 }]);
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

  it('renders the assignee select with the account agents and pre-selects the current owner', () => {
    const wrapper = mountTab(baseDeal);

    const assigneeSelect = wrapper.get('[aria-label="Owner"]');
    const options = assigneeSelect.findAll('option').map(o => o.text());
    expect(options).toEqual(['', 'Jane Agent', 'John Agent']);
    expect(assigneeSelect.element.value).toBe('1');
  });

  it('emits update with only the assignee_id field when the assignee select changes', async () => {
    const wrapper = mountTab(baseDeal);

    const assigneeSelect = wrapper.get('[aria-label="Owner"]');
    await assigneeSelect.setValue('2');

    expect(wrapper.emitted('update')).toBeTruthy();
    expect(wrapper.emitted('update')[0]).toEqual([{ assignee_id: 2 }]);
  });

  it('emits null (not an empty string) for assignee_id when "no owner" is selected', async () => {
    const wrapper = mountTab(baseDeal);

    const assigneeSelect = wrapper.get('[aria-label="Owner"]');
    await assigneeSelect.setValue('');

    expect(wrapper.emitted('update')).toBeTruthy();
    expect(wrapper.emitted('update')[0]).toEqual([{ assignee_id: null }]);
  });

  it('dispatches agents/get on mount when the agents list is empty', () => {
    useMapGetter.mockImplementation(getter => {
      const mockValues = {
        'deals/getStages': stages,
        'agents/getAgents': [],
      };
      return computed(() => mockValues[getter]);
    });

    mountTab(baseDeal);

    expect(dispatch).toHaveBeenCalledWith('agents/get');
  });

  it('does not dispatch agents/get on mount when the agents list is already populated', () => {
    mountTab(baseDeal);

    expect(dispatch).not.toHaveBeenCalledWith('agents/get');
  });

  it('renders the currency select with BRL, USD and EUR pre-selected to the current currency', () => {
    const wrapper = mountTab(baseDeal);

    const currencySelect = wrapper.get('[aria-label="Currency"]');
    const options = currencySelect.findAll('option').map(o => o.text());
    expect(options).toEqual(['BRL', 'USD', 'EUR']);
    expect(currencySelect.element.value).toBe('BRL');
  });

  it('emits update with only the currency field when the currency select changes', async () => {
    const wrapper = mountTab(baseDeal);

    const currencySelect = wrapper.get('[aria-label="Currency"]');
    await currencySelect.setValue('USD');

    expect(wrapper.emitted('update')).toBeTruthy();
    expect(wrapper.emitted('update')[0]).toEqual([{ currency: 'USD' }]);
  });

  it('re-syncs the assignee and currency fields when the deal prop changes', async () => {
    const wrapper = mountTab(baseDeal);

    await wrapper.setProps({
      deal: { ...baseDeal, assignee_id: 2, currency: 'EUR' },
    });

    expect(wrapper.get('[aria-label="Owner"]').element.value).toBe('2');
    expect(wrapper.get('[aria-label="Currency"]').element.value).toBe('EUR');
  });
});
