require 'rails_helper'

RSpec.describe CadenceEnrollment do
  let(:account) { create(:account) }
  let(:channel) do
    create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud',
                              validate_provider_config: false, sync_templates: false)
  end
  let(:cadence) do
    Cadence.create!(account: account, inbox: channel.inbox, title: 'Follow up',
                    steps: [{ 'delay_days' => 0, 'template_params' => { 'name' => 'boas_vindas' } }])
  end
  let(:contact) { create(:contact, account: account, name: 'Maria', phone_number: '+5511900000000') }

  describe '.enroll' do
    it 'enrolls a contact once' do
      expect(described_class.enroll(cadence, contact)).to be_present
      expect(cadence.cadence_enrollments.count).to eq(1)
    end

    # The whole design leans on this: the audience scan re-runs every five minutes and must not
    # produce a second enrolment, or the contact is charged for the sequence twice.
    it 'returns nil instead of raising when the contact is already in' do
      described_class.enroll(cadence, contact)

      expect(described_class.enroll(cadence, contact)).to be_nil
      expect(cadence.cadence_enrollments.count).to eq(1)
    end

    it 'does not re-enroll someone who already replied' do
      described_class.enroll(cadence, contact).stopped_replied!

      expect(described_class.enroll(cadence, contact)).to be_nil
      expect(cadence.cadence_enrollments.sole).to be_stopped_replied
    end

    it 'skips a contact with nowhere to be reached' do
      unreachable = create(:contact, account: account, name: 'Sem telefone', phone_number: nil)

      expect(described_class.enroll(cadence, unreachable)).to be_nil
      expect(cadence.cadence_enrollments.count).to be_zero
    end
  end
end
