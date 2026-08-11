import { mount } from '@vue/test-utils';
import LostReasonDialog from '../LostReasonDialog.vue';

// The global vitest setup (vitest.setup.js) already installs the real
// vue-i18n plugin with the app's `en` messages, so `useI18n()` resolves
// actual translated strings here rather than needing a $t mock.
describe('LostReasonDialog', () => {
  it('renders nothing until open() is called', () => {
    const wrapper = mount(LostReasonDialog);
    expect(wrapper.find('textarea').exists()).toBe(false);
  });

  it('disables the confirm button while the textarea is empty or whitespace-only', async () => {
    const wrapper = mount(LostReasonDialog);
    wrapper.vm.open();
    await wrapper.vm.$nextTick();

    const confirmButton = wrapper.findAll('button')[1];
    expect(confirmButton.attributes('disabled')).toBeDefined();

    await wrapper.find('textarea').setValue('   ');
    expect(confirmButton.attributes('disabled')).toBeDefined();

    await wrapper.find('textarea').setValue('Lost to a competitor');
    expect(confirmButton.attributes('disabled')).toBeUndefined();
  });

  it('emits confirm with the trimmed reason and closes on confirm', async () => {
    const wrapper = mount(LostReasonDialog);
    wrapper.vm.open();
    await wrapper.vm.$nextTick();

    await wrapper.find('textarea').setValue('  Too expensive  ');
    await wrapper.findAll('button')[1].trigger('click');

    expect(wrapper.emitted('confirm')[0]).toEqual(['Too expensive']);
    expect(wrapper.find('textarea').exists()).toBe(false);
  });

  it('emits cancel and closes without emitting confirm', async () => {
    const wrapper = mount(LostReasonDialog);
    wrapper.vm.open();
    await wrapper.vm.$nextTick();

    await wrapper.findAll('button')[0].trigger('click');

    expect(wrapper.emitted('cancel')).toBeTruthy();
    expect(wrapper.emitted('confirm')).toBeFalsy();
    expect(wrapper.find('textarea').exists()).toBe(false);
  });
});
