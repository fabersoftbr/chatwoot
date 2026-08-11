import { mount } from '@vue/test-utils';
import { useRoute } from 'vue-router';
import DealContactTab from '../DealContactTab.vue';

vi.mock('vue-router');

const mountTab = contact => {
  useRoute.mockReturnValue({ params: { accountId: '7' } });
  return mount(DealContactTab, { props: { contact } });
};

describe('DealContactTab', () => {
  it('renders the contact name, email and phone', () => {
    const wrapper = mountTab({
      id: 42,
      name: 'Jane Doe',
      email: 'jane@example.com',
      phone_number: '+15551234567',
      thumbnail: '',
    });

    expect(wrapper.text()).toContain('Jane Doe');
    expect(wrapper.text()).toContain('jane@example.com');
    expect(wrapper.text()).toContain('+15551234567');
  });

  it('omits the email and phone rows without printing "undefined" when blank', () => {
    const wrapper = mountTab({
      id: 42,
      name: 'Jane Doe',
      email: '',
      phone_number: '',
      thumbnail: '',
    });

    expect(wrapper.text()).toContain('Jane Doe');
    expect(wrapper.text()).not.toContain('undefined');
  });

  it('links to the contact profile using the accountId from the route', () => {
    const wrapper = mountTab({
      id: 42,
      name: 'Jane Doe',
      email: '',
      phone_number: '',
      thumbnail: '',
    });

    const link = wrapper.get('router-link');
    expect(link.attributes('to')).toBe('/app/accounts/7/contacts/42');
  });
});
