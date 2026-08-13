import { computed } from 'vue';
import { mount } from '@vue/test-utils';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import DealFormDialog from '../DealFormDialog.vue';

vi.mock('dashboard/composables/store');

const stages = [
  { id: 1, name: 'New' },
  { id: 2, name: 'Qualified' },
];

const pipelines = [
  { id: 10, name: 'Sales' },
  { id: 20, name: 'Support' },
];

const contacts = [
  { id: 1, name: 'Jane Doe' },
  { id: 2, name: 'John Smith' },
];

// The global vitest setup (vitest.setup.js) already installs the real
// vue-i18n plugin with the app's `en` messages, so `useI18n()` resolves
// actual translated strings here rather than needing a $t mock.
const mountDialog = (dispatch, props = {}) => {
  useStore.mockReturnValue({ dispatch });
  useMapGetter.mockImplementation(getter => {
    const mockValues = {
      'dealStages/getStages': stages,
      'pipelines/getPipelines': pipelines,
      'contacts/getContacts': contacts,
    };
    return computed(() => mockValues[getter]);
  });
  return mount(DealFormDialog, { props });
};

describe('DealFormDialog', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders nothing until open() is called', () => {
    const wrapper = mountDialog(vi.fn().mockResolvedValue());

    expect(wrapper.find('h3').exists()).toBe(false);

    wrapper.vm.open();
    return wrapper.vm.$nextTick().then(() => {
      expect(wrapper.find('h3').exists()).toBe(true);
    });
  });

  it('renders the contact select when no contactId prop is given', async () => {
    const wrapper = mountDialog(vi.fn().mockResolvedValue());
    wrapper.vm.open();
    await wrapper.vm.$nextTick();

    const selects = wrapper.findAll('select');
    expect(selects).toHaveLength(4);
  });

  it('hides the contact select and pre-fills contact_id when a contactId prop is given', async () => {
    const dispatch = vi.fn().mockResolvedValue({ id: 99 });
    const wrapper = mountDialog(dispatch, { contactId: 7 });
    wrapper.vm.open();
    await wrapper.vm.$nextTick();

    const selects = wrapper.findAll('select');
    expect(selects).toHaveLength(3);

    await wrapper
      .find('input[type="text"], input:not([type])')
      .setValue('A deal');
    await wrapper.get('button.bg-woot-500').trigger('click');
    await wrapper.vm.$nextTick();

    expect(dispatch).toHaveBeenCalledWith(
      'deals/create',
      expect.objectContaining({ contact_id: 7 })
    );
  });

  it('loads the stages for the pipelineId prop rather than the first pipeline', async () => {
    const dispatch = vi.fn().mockResolvedValue();
    const wrapper = mountDialog(dispatch, { pipelineId: 20 });
    wrapper.vm.open();
    await wrapper.vm.$nextTick();

    expect(dispatch).toHaveBeenCalledWith('dealStages/get', {
      pipelineId: 20,
    });
  });

  it('falls back to the first pipeline when no pipelineId prop is given', async () => {
    const dispatch = vi.fn().mockResolvedValue();
    const wrapper = mountDialog(dispatch);
    wrapper.vm.open();
    await wrapper.vm.$nextTick();

    expect(dispatch).toHaveBeenCalledWith('dealStages/get', {
      pipelineId: pipelines[0].id,
    });
  });

  it('disables submit while the title is empty or whitespace-only', async () => {
    const wrapper = mountDialog(vi.fn().mockResolvedValue(), { contactId: 7 });
    wrapper.vm.open();
    await wrapper.vm.$nextTick();

    const submitButton = wrapper.get('button.bg-woot-500');
    expect(submitButton.attributes('disabled')).toBeDefined();

    const titleInput = wrapper.find('input[placeholder="Title"]');
    await titleInput.setValue('   ');
    expect(submitButton.attributes('disabled')).toBeDefined();

    await titleInput.setValue('A real deal');
    expect(submitButton.attributes('disabled')).toBeUndefined();
  });

  it('dispatches deals/create with the form fields on a valid submit and emits created', async () => {
    const createdDeal = { id: 42, title: 'A real deal' };
    const dispatch = vi.fn().mockResolvedValue(createdDeal);
    const wrapper = mountDialog(dispatch, { contactId: 7 });
    wrapper.vm.open();
    await wrapper.vm.$nextTick();

    await wrapper.find('input[placeholder="Title"]').setValue('A real deal');
    await wrapper.find('input[placeholder="Value"]').setValue('12000');
    await wrapper.get('button.bg-woot-500').trigger('click');
    await wrapper.vm.$nextTick();

    expect(dispatch).toHaveBeenCalledWith('deals/create', {
      title: 'A real deal',
      contact_id: 7,
      deal_stage_id: 1,
      value_cents: 1200000,
      temperature: 'warm',
    });
    expect(wrapper.emitted('created')).toBeTruthy();
    expect(wrapper.emitted('created')[0]).toEqual([createdDeal]);
  });

  it('gives every form control an accessible name', async () => {
    const wrapper = mountDialog(vi.fn().mockResolvedValue());
    wrapper.vm.open();
    await wrapper.vm.$nextTick();

    const controls = [
      ...wrapper.findAll('input').map(w => w.element),
      ...wrapper.findAll('select').map(w => w.element),
      ...wrapper.findAll('textarea').map(w => w.element),
    ];

    expect(controls.length).toBeGreaterThan(0);
    controls.forEach(el => {
      expect(el.getAttribute('aria-label')?.trim()).toBeTruthy();
    });
  });
});
