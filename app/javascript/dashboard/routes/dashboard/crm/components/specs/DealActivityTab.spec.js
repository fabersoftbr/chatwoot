import { mount, flushPromises } from '@vue/test-utils';
import { useAlert } from 'dashboard/composables';
import { useStore } from 'dashboard/composables/store';
import DealActivityTab from '../DealActivityTab.vue';

vi.mock('dashboard/composables/store');
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const manualActivity = {
  id: 1,
  activity_type: 'call',
  content: 'Called the client about pricing',
  metadata: {},
  created_at: '2026-08-10T10:00:00Z',
  user: { id: 1, name: 'Jane Doe', thumbnail: '' },
};

const systemActivity = {
  id: 2,
  activity_type: 'stage_changed',
  content: null,
  metadata: {},
  created_at: '2026-08-09T10:00:00Z',
  user: null,
};

// The global vitest setup (vitest.setup.js) already installs the real
// vue-i18n plugin with the app's `en` messages, so `useI18n()` resolves
// actual translated strings here rather than needing a $t mock.
const mountTab = async (dispatch, dealId = 1) => {
  useStore.mockReturnValue({ dispatch });
  const wrapper = mount(DealActivityTab, { props: { dealId } });
  await flushPromises();
  return wrapper;
};

describe('DealActivityTab', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders the content of a manual activity', async () => {
    const dispatch = vi.fn().mockResolvedValue([manualActivity]);
    const wrapper = await mountTab(dispatch);

    expect(wrapper.text()).toContain('Called the client about pricing');
  });

  it('renders the translated type label for a system activity with no content or user, and never prints "undefined"', async () => {
    const dispatch = vi.fn().mockResolvedValue([systemActivity]);
    const wrapper = await mountTab(dispatch);

    expect(wrapper.text()).toContain('Stage changed');
    expect(wrapper.text()).not.toContain('undefined');
  });

  it('disables the submit button for empty and whitespace-only content', async () => {
    const dispatch = vi.fn().mockResolvedValue([]);
    const wrapper = await mountTab(dispatch);

    const submitButton = wrapper.get('button');
    expect(submitButton.attributes('disabled')).toBeDefined();

    await wrapper.find('textarea').setValue('   ');
    expect(submitButton.attributes('disabled')).toBeDefined();

    await wrapper.find('textarea').setValue('A real note');
    expect(submitButton.attributes('disabled')).toBeUndefined();
  });

  it('submits trimmed content for the selected type, then reloads the list', async () => {
    const dispatch = vi.fn().mockImplementation(action => {
      if (action === 'deals/createActivity') return Promise.resolve({});
      return Promise.resolve([]);
    });
    const wrapper = await mountTab(dispatch);

    await wrapper.find('select').setValue('note');
    await wrapper.find('textarea').setValue('  A trimmed note  ');
    dispatch.mockClear();

    await wrapper.get('button').trigger('click');
    await flushPromises();

    expect(dispatch).toHaveBeenCalledWith('deals/createActivity', {
      dealId: 1,
      activityType: 'note',
      content: 'A trimmed note',
    });
    expect(dispatch).toHaveBeenCalledWith('deals/fetchActivities', 1);
    expect(wrapper.find('textarea').element.value).toBe('');
  });

  it('surfaces the error with useAlert when the activity submit is rejected', async () => {
    const dispatch = vi.fn().mockImplementation(action => {
      if (action === 'deals/createActivity') {
        return Promise.reject(new Error('Content cannot be blank.'));
      }
      return Promise.resolve([]);
    });
    const wrapper = await mountTab(dispatch);

    await wrapper.find('textarea').setValue('A note');
    await wrapper.get('button').trigger('click');
    await flushPromises();

    expect(useAlert).toHaveBeenCalledWith('Content cannot be blank.');
  });

  it('renders the empty-state label when there are no activities', async () => {
    const dispatch = vi.fn().mockResolvedValue([]);
    const wrapper = await mountTab(dispatch);

    expect(wrapper.text()).toContain('No activity yet');
  });
});
