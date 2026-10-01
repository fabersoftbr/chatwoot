require 'rails_helper'

RSpec.describe Whatsapp::TemplateVariables do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account, name: 'Maria Silva', email: 'maria@exemplo.com', phone_number: '+5511900000000') }

  describe '.extract' do
    it 'returns named variables in order of first appearance, without repeats' do
      body = 'Olá {{contact_first_name}}, confirmamos para {{contact_first_name}} no {{contact_phone_number}}.'

      expect(described_class.extract(body)).to eq(%w[contact_first_name contact_phone_number])
    end

    it 'ignores positional variables' do
      expect(described_class.extract('Olá {{1}}, pedido {{2}}')).to be_empty
    end
  end

  describe '.unsupported' do
    it 'names the ones nothing can fill' do
      expect(described_class.unsupported(%w[contact_name cpf_do_cliente])).to eq(['cpf_do_cliente'])
    end
  end

  describe '.resolve' do
    it 'reads each value off the contact' do
      resolved = described_class.resolve(%w[contact_name contact_first_name contact_email contact_phone_number], contact: contact)

      expect(resolved).to eq(
        'contact_name' => 'Maria Silva',
        'contact_first_name' => 'Maria',
        'contact_email' => 'maria@exemplo.com',
        'contact_phone_number' => '+5511900000000'
      )
    end

    it 'returns a blank string when the contact has no value, rather than nil' do
      nameless = create(:contact, account: account, name: '', phone_number: '+5511911111111')

      expect(described_class.resolve(['contact_first_name'], contact: nameless)).to eq('contact_first_name' => '')
    end

    it 'reads the agent name off the sender' do
      user = create(:user, name: 'João')

      expect(described_class.resolve(['agent_name'], contact: contact, sender: user)).to eq('agent_name' => 'João')
    end
  end

  describe '.fill' do
    it 'overwrites the stored value with this contact and leaves other keys alone' do
      params = { 'name' => 'boas_vindas', 'processed_params' => { 'body' => { 'contact_first_name' => 'Maria', 'pedido' => '123' } } }

      filled = described_class.fill(params, contact: create(:contact, account: account, name: 'Ana Souza'))

      expect(filled['processed_params']['body']).to eq('contact_first_name' => 'Ana', 'pedido' => '123')
      expect(filled['name']).to eq('boas_vindas')
    end

    it 'returns the params untouched when there is nothing to fill' do
      params = { 'processed_params' => { 'body' => { '1' => 'texto' } } }

      expect(described_class.fill(params, contact: contact)).to eq(params)
    end

    it 'tolerates params without a body' do
      expect(described_class.fill({ 'name' => 'x' }, contact: contact)).to eq('name' => 'x')
      expect(described_class.fill(nil, contact: contact)).to be_nil
    end
  end
end
