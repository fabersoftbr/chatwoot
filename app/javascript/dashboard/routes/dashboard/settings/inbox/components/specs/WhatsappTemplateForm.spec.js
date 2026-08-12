import { shallowMount } from '@vue/test-utils';
import WhatsappTemplateForm from '../WhatsappTemplateForm.vue';

const mountForm = () =>
  shallowMount(WhatsappTemplateForm, { props: { inboxId: 7 } });

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
});
