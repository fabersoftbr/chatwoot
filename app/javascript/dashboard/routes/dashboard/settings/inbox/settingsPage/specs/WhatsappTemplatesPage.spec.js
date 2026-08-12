import { shallowMount } from '@vue/test-utils';
import WhatsappTemplatesPage from '../WhatsappTemplatesPage.vue';

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
    const wrapper = mountPage({ inbox: { id: 7, message_templates: {} } });
    expect(wrapper.text()).toContain('No templates yet');
  });
});
