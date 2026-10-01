require 'rails_helper'

RSpec.describe Cadence do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account, timezone: 'America/Sao_Paulo') }

  describe '#deliver_at_for' do
    # 2026-09-30 is a Wednesday. Sao Paulo is UTC-3 and has no DST since 2019.
    let(:enrolled_at) { Time.find_zone('America/Sao_Paulo').local(2026, 9, 30, 9, 0).utc }

    def cadence_with(steps)
      described_class.new(account: account, inbox: inbox, title: 'Follow up', steps: steps)
    end

    it 'sends immediately when the step has no offset and no time' do
      cadence = cadence_with([{ 'delay_days' => 0, 'content' => 'oi' }])

      expect(cadence.deliver_at_for(0, from: enrolled_at)).to eq(enrolled_at)
    end

    it 'keeps the enrollment time of day when only a day offset is given' do
      cadence = cadence_with([{ 'delay_days' => 2, 'content' => 'oi' }])

      expect(cadence.deliver_at_for(0, from: enrolled_at).in_time_zone('America/Sao_Paulo'))
        .to eq(Time.find_zone('America/Sao_Paulo').local(2026, 10, 2, 9, 0))
    end

    it 'pins the requested wall clock time in the inbox timezone' do
      cadence = cadence_with([{ 'delay_days' => 1, 'send_hour' => 14, 'send_minute' => 30, 'content' => 'oi' }])

      expect(cadence.deliver_at_for(0, from: enrolled_at).in_time_zone('America/Sao_Paulo'))
        .to eq(Time.find_zone('America/Sao_Paulo').local(2026, 10, 1, 14, 30))
    end

    it 'rolls forward to the requested weekday' do
      # Tuesday is 2, and the offset lands on Thursday 2026-10-01.
      cadence = cadence_with([{ 'delay_days' => 1, 'send_hour' => 19, 'weekday' => 2, 'content' => 'oi' }])

      expect(cadence.deliver_at_for(0, from: enrolled_at).in_time_zone('America/Sao_Paulo'))
        .to eq(Time.find_zone('America/Sao_Paulo').local(2026, 10, 6, 19, 0))
    end

    it 'measures every step from the same origin so late ticks do not accumulate drift' do
      cadence = cadence_with([{ 'delay_days' => 1, 'content' => 'a' }, { 'delay_days' => 3, 'content' => 'b' }])

      expect(cadence.deliver_at_for(1, from: enrolled_at)).to eq(enrolled_at + 3.days)
    end

    it 'returns nil past the last step' do
      cadence = cadence_with([{ 'delay_days' => 1, 'content' => 'a' }])

      expect(cadence.deliver_at_for(1, from: enrolled_at)).to be_nil
    end
  end

  describe 'validations' do
    it 'rejects a WhatsApp Cloud step without a template' do
      channel = create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud',
                                          validate_provider_config: false, sync_templates: false)
      cadence = described_class.new(account: account, inbox: channel.inbox, title: 'Follow up',
                                    steps: [{ 'delay_days' => 1, 'content' => 'plain text' }])

      expect(cadence).not_to be_valid
      expect(cadence.errors[:steps].first).to include('approved template')
    end

    it 'rejects an inbox the cadence cannot deliver on' do
      cadence = described_class.new(account: account, inbox: inbox, title: 'Follow up',
                                    steps: [{ 'delay_days' => 1, 'content' => 'oi' }])

      expect(cadence).not_to be_valid
      expect(cadence.errors[:inbox]).to be_present
    end
  end
end
