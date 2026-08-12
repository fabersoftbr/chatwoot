import { shallowMount } from '@vue/test-utils';
import { useAlert } from 'dashboard/composables';
import WhatsappTemplatesAPI from 'dashboard/api/channel/whatsappTemplates';
import WhatsappTemplatesPage from '../WhatsappTemplatesPage.vue';

vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/api/channel/whatsappTemplates', () => ({
  default: { delete: vi.fn() },
}));

const inbox = {
  id: 7,
  message_templates: [
    {
      name: 'boas_vindas',
      language: 'pt_BR',
      category: 'UTILITY',
      status: 'APPROVED',
    },
    {
      name: 'pedido',
      language: 'pt_BR',
      category: 'UTILITY',
      status: 'PENDING',
    },
  ],
};

const mountPage = (props = {}) =>
  shallowMount(WhatsappTemplatesPage, {
    props: { inbox, ...props },
    global: { stubs: { WhatsappTemplateForm: true } },
  });

describe('WhatsappTemplatesPage', () => {
  it('renders a row per template', () => {
    expect(mountPage().findAll('tbody tr')).toHaveLength(2);
  });

  it('renders the empty state when the inbox has no templates', () => {
    const wrapper = mountPage({ inbox: { id: 7, message_templates: [] } });
    expect(wrapper.text()).toContain('No templates yet');
  });

  it('tolerates the empty-hash default the column ships with', () => {
    // channel_whatsapp.message_templates defaults to {} but is written as an array.
    // Asserting on the coerced value and on the absent table, because the
    // `v-if="!templates.length"` empty state renders for {} either way.
    const wrapper = mountPage({ inbox: { id: 7, message_templates: {} } });
    expect(wrapper.vm.templates).toEqual([]);
    expect(wrapper.find('table').exists()).toBe(false);
    expect(wrapper.text()).toContain('No templates yet');
  });

  it("shows Meta's own wording when a delete is refused", async () => {
    WhatsappTemplatesAPI.delete.mockRejectedValue({
      response: { data: { error: 'Template name already exists' } },
    });
    const wrapper = mountPage();
    wrapper.vm.templateToDelete = 'pedido';

    await wrapper.vm.confirmDelete();

    expect(useAlert).toHaveBeenCalledWith('Template name already exists');
  });

  it('falls back to the generic message when the server sends no error string', async () => {
    WhatsappTemplatesAPI.delete.mockRejectedValue({ response: { data: {} } });
    const wrapper = mountPage();
    wrapper.vm.templateToDelete = 'pedido';

    await wrapper.vm.confirmDelete();

    expect(useAlert).toHaveBeenCalledWith(
      'Something went wrong. Please try again.'
    );
  });
});
