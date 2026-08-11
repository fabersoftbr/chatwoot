require 'rails_helper'

RSpec.describe DealStage do
  let(:account) { create(:account) }

  describe 'validations' do
    it 'requires a name' do
      stage = described_class.new(account: account, position: 0)
      expect(stage).not_to be_valid
      expect(stage.errors[:name]).to be_present
    end
  end

  describe '.seed_defaults' do
    it 'creates the five default stages for an account without stages' do
      stages = described_class.seed_defaults(account)

      expect(stages.map(&:name)).to eq(
        ['Prospectado', 'Em negociação', 'Contrato enviado', 'Ganho', 'Perdido']
      )
      expect(stages.map(&:position)).to eq([0, 1, 2, 3, 4])
      expect(stages.map(&:stage_type)).to eq(%w[open open open won lost])
    end

    it 'is idempotent' do
      described_class.seed_defaults(account)
      expect { described_class.seed_defaults(account) }.not_to change(described_class, :count)
    end

    it 'does not seed an account that already has a stage' do
      create(:deal_stage, account: account, name: 'Custom', position: 0)

      expect(described_class.seed_defaults(account).map(&:name)).to eq(['Custom'])
    end
  end

  describe '.ordered' do
    it 'sorts by position' do
      second = create(:deal_stage, account: account, position: 1)
      first = create(:deal_stage, account: account, position: 0)

      expect(account.deal_stages.ordered).to eq([first, second])
    end
  end

  describe 'stage_type predicates' do
    it 'exposes prefixed predicates' do
      expect(build(:deal_stage, stage_type: :won)).to be_stage_won
      expect(build(:deal_stage, stage_type: :open)).not_to be_stage_lost
    end
  end
end
