require 'rails_helper'

RSpec.describe DealActivity do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, role: :agent) }
  let(:contact) { create(:contact, account: account) }
  let(:open_stage) { create(:deal_stage, account: account, stage_type: :open, position: 0) }
  let(:next_stage) { create(:deal_stage, account: account, stage_type: :open, position: 1) }

  describe 'validations' do
    it 'requires content on manual types' do
      activity = build(:deal_activity, activity_type: :call, content: nil)
      expect(activity).not_to be_valid
    end

    it 'allows blank content on system types' do
      activity = build(:deal_activity, activity_type: :stage_changed, content: nil)
      expect(activity).to be_valid
    end
  end

  describe 'automatic logging' do
    around do |example|
      Current.user = user
      example.run
      Current.user = nil
    end

    it 'logs creation' do
      deal = create(:deal, account: account, contact: contact, deal_stage: open_stage)

      expect(deal.deal_activities.pluck(:activity_type)).to eq(['created'])
      expect(deal.deal_activities.first.user_id).to eq(user.id)
    end

    it 'logs a stage change with the previous and next stage ids' do
      deal = create(:deal, account: account, contact: contact, deal_stage: open_stage)
      deal.update!(deal_stage: next_stage)

      activity = deal.deal_activities.find_by(activity_type: :stage_changed)
      expect(activity.metadata).to eq(
        'from_stage_id' => open_stage.id, 'to_stage_id' => next_stage.id
      )
    end

    it 'logs a temperature change' do
      deal = create(:deal, account: account, contact: contact, deal_stage: open_stage, temperature: :warm)
      deal.update!(temperature: :hot)

      activity = deal.deal_activities.find_by(activity_type: :temperature_changed)
      expect(activity.metadata).to eq('from' => 'warm', 'to' => 'hot')
    end

    it 'logs an assignee change' do
      deal = create(:deal, account: account, contact: contact, deal_stage: open_stage)
      deal.update!(assignee: user)

      activity = deal.deal_activities.find_by(activity_type: :assigned)
      expect(activity.metadata).to eq('to_user_id' => user.id)
    end

    it 'does not log anything when an unrelated field changes' do
      deal = create(:deal, account: account, contact: contact, deal_stage: open_stage)

      expect { deal.update!(description: 'nova descrição') }
        .not_to change(deal.deal_activities, :count)
    end
  end

  describe '.latest' do
    it 'returns the newest activity first' do
      deal = create(:deal, account: account, contact: contact, deal_stage: open_stage)
      older = create(:deal_activity, deal: deal, created_at: 2.days.ago)
      newer = create(:deal_activity, deal: deal, created_at: 1.hour.ago)

      manual = deal.deal_activities.latest.where.not(activity_type: :created)

      expect(manual.first(2)).to eq([newer, older])
    end
  end
end
