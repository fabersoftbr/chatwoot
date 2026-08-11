require 'rails_helper'

RSpec.describe Deal do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:open_stage) { create(:deal_stage, account: account, stage_type: :open, position: 0) }
  let(:won_stage) { create(:deal_stage, account: account, stage_type: :won, position: 1) }
  let(:lost_stage) { create(:deal_stage, account: account, stage_type: :lost, position: 2) }

  describe 'validations' do
    it 'requires a title' do
      deal = build(:deal, account: account, contact: contact, deal_stage: open_stage, title: nil)
      expect(deal).not_to be_valid
      expect(deal.errors[:title]).to be_present
    end

    it 'rejects a negative value' do
      deal = build(:deal, account: account, contact: contact, deal_stage: open_stage, value_cents: -1)
      expect(deal).not_to be_valid
    end

    it 'requires a lost reason in a lost stage' do
      deal = build(:deal, account: account, contact: contact, deal_stage: lost_stage, lost_reason: nil)
      expect(deal).not_to be_valid
      expect(deal.errors[:lost_reason]).to be_present
    end

    it 'accepts a lost stage when the reason is given' do
      deal = build(:deal, account: account, contact: contact, deal_stage: lost_stage, lost_reason: 'Preço')
      expect(deal).to be_valid
    end

    it 'rejects a contact belonging to another account' do
      other_contact = create(:contact, account: create(:account))
      deal = build(:deal, account: account, contact: other_contact, deal_stage: open_stage)
      expect(deal).not_to be_valid
      expect(deal.errors[:contact]).to be_present
    end

    it 'rejects a deal_stage belonging to another account' do
      other_stage = create(:deal_stage, account: create(:account))
      deal = build(:deal, account: account, contact: contact, deal_stage: other_stage)
      expect(deal).not_to be_valid
      expect(deal.errors[:deal_stage]).to be_present
    end

    it 'rejects an assignee who is not a member of the account' do
      outsider = create(:user, account: create(:account))
      deal = build(:deal, account: account, contact: contact, deal_stage: open_stage, assignee: outsider)
      expect(deal).not_to be_valid
      expect(deal.errors[:assignee]).to be_present
    end

    it 'accepts a contact, deal_stage and assignee that belong to the account' do
      member = create(:user, account: account)
      deal = build(:deal, account: account, contact: contact, deal_stage: open_stage, assignee: member)
      expect(deal).to be_valid
    end
  end

  describe 'closed_at' do
    it 'is nil while the deal sits in an open stage' do
      deal = create(:deal, account: account, contact: contact, deal_stage: open_stage)
      expect(deal.closed_at).to be_nil
    end

    it 'is set when the deal reaches a won stage' do
      deal = create(:deal, account: account, contact: contact, deal_stage: open_stage)
      deal.update!(deal_stage: won_stage)
      expect(deal.reload.closed_at).to be_present
    end

    it 'is cleared when the deal goes back to an open stage' do
      deal = create(:deal, account: account, contact: contact, deal_stage: won_stage)
      deal.update!(deal_stage: open_stage)
      expect(deal.reload.closed_at).to be_nil
    end
  end

  describe 'position' do
    it 'appends new deals to the end of their stage' do
      first = create(:deal, account: account, contact: contact, deal_stage: open_stage)
      second = create(:deal, account: account, contact: contact, deal_stage: open_stage)

      expect([first.position, second.position]).to eq([0, 1])
    end
  end

  describe '#move_to!' do
    it 'moves a deal to another stage at the given index and reindexes the column' do
      target_a = create(:deal, account: account, contact: contact, deal_stage: won_stage)
      target_b = create(:deal, account: account, contact: contact, deal_stage: won_stage)
      deal = create(:deal, account: account, contact: contact, deal_stage: open_stage)

      deal.move_to!(stage_id: won_stage.id, position: 1)

      expect(deal.reload.deal_stage_id).to eq(won_stage.id)
      expect([target_a.reload.position, deal.position, target_b.reload.position]).to eq([0, 1, 2])
    end

    it 'stores the lost reason when moving into a lost stage' do
      deal = create(:deal, account: account, contact: contact, deal_stage: open_stage)

      deal.move_to!(stage_id: lost_stage.id, position: 0, lost_reason: 'Sem orçamento')

      expect(deal.reload.lost_reason).to eq('Sem orçamento')
      expect(deal.closed_at).to be_present
    end

    it 'refuses to move into a lost stage without a reason' do
      deal = create(:deal, account: account, contact: contact, deal_stage: open_stage)

      expect { deal.move_to!(stage_id: lost_stage.id, position: 0) }
        .to raise_error(ActiveRecord::RecordInvalid)
      expect(deal.reload.deal_stage_id).to eq(open_stage.id)
    end

    it 'does not contaminate the in-memory object when validation fails' do
      deal = create(:deal, account: account, contact: contact, deal_stage: open_stage)
      original_lost_reason = deal.lost_reason

      expect { deal.move_to!(stage_id: lost_stage.id, position: 0) }
        .to raise_error(ActiveRecord::RecordInvalid)

      # The unreloaded object must still report the original stage and lost_reason
      expect(deal.deal_stage_id).to eq(open_stage.id)
      expect(deal.lost_reason).to eq(original_lost_reason)
    end
  end

  describe 'scopes' do
    it 'returns only deals in open stages' do
      open_deal = create(:deal, account: account, contact: contact, deal_stage: open_stage)
      create(:deal, account: account, contact: contact, deal_stage: won_stage)

      expect(account.deals.open_deals).to eq([open_deal])
    end

    it 'returns open deals whose next action is in the past' do
      overdue = create(:deal, account: account, contact: contact, deal_stage: open_stage,
                              next_action_at: 1.day.ago)
      create(:deal, account: account, contact: contact, deal_stage: open_stage,
                    next_action_at: 1.day.from_now)

      expect(account.deals.overdue).to eq([overdue])
    end
  end
end
