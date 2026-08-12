import { shallowMount } from '@vue/test-utils';
import { useAlert } from 'dashboard/composables';
import WhatsappTemplatesAPI from 'dashboard/api/channel/whatsappTemplates';
import WhatsappTemplateForm from '../WhatsappTemplateForm.vue';

vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/api/channel/whatsappTemplates', () => ({
  default: { create: vi.fn() },
}));

const mountForm = () =>
  shallowMount(WhatsappTemplateForm, { props: { inboxId: 7 } });

const mountValidForm = () => {
  const wrapper = mountForm();
  wrapper.vm.name = 'boas_vindas';
  wrapper.vm.body = 'Olá, tudo bem?';
  return wrapper;
};

describe('WhatsappTemplateForm', () => {
  it('renders one example field per variable in the body', async () => {
    const wrapper = mountForm();
    await wrapper.find('textarea').setValue('Olá {{1}}, pedido {{2}}');

    expect(wrapper.findAll('[data-testid="example-input"]')).toHaveLength(2);
  });

  it('counts a repeated variable once', async () => {
    const wrapper = mountForm();
    await wrapper.find('textarea').setValue('Oi {{1}}, confirma {{1}}?');

    expect(wrapper.findAll('[data-testid="example-input"]')).toHaveLength(1);
  });

  it('renders no example field when the body has no variables', async () => {
    const wrapper = mountForm();
    await wrapper.find('textarea').setValue('Olá, tudo bem?');

    expect(wrapper.findAll('[data-testid="example-input"]')).toHaveLength(0);
  });

  it('forces the name to lowercase', async () => {
    const wrapper = mountForm();
    await wrapper
      .find('input[data-testid="template-name"]')
      .setValue('Boas Vindas');

    expect(wrapper.vm.name).toBe('boas vindas');
  });

  it("shows Meta's own wording when the template is refused", async () => {
    WhatsappTemplatesAPI.create.mockRejectedValue({
      response: { data: { error: 'Template name already exists' } },
    });
    const wrapper = mountValidForm();

    await wrapper.vm.submit();

    expect(useAlert).toHaveBeenCalledWith('Template name already exists');
    expect(wrapper.emitted('created')).toBeUndefined();
  });

  it('falls back to the generic message when the server sends no error string', async () => {
    WhatsappTemplatesAPI.create.mockRejectedValue({ response: { data: {} } });
    const wrapper = mountValidForm();

    await wrapper.vm.submit();

    expect(useAlert).toHaveBeenCalledWith(
      'Something went wrong. Please try again.'
    );
  });
});
