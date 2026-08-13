require 'rails_helper'

RSpec.describe Pipeline do
  let(:account) { create(:account) }

  describe 'validations' do
    it 'requires a name' do
      pipeline = described_class.new(account: account, position: 0)
      expect(pipeline).not_to be_valid
      expect(pipeline.errors[:name]).to be_present
    end
  end

  describe 'stage seeding' do
    it 'creates the five default stages on create' do
      pipeline = described_class.create!(account: account, name: 'Inbound', position: 0)

      expect(pipeline.deal_stages.ordered.map(&:name)).to eq(
        ['Prospectado', 'Em negociação', 'Contrato enviado', 'Ganho', 'Perdido']
      )
      expect(pipeline.deal_stages.ordered.map(&:stage_type)).to eq(%w[open open open won lost])
      expect(pipeline.deal_stages.ordered.map(&:position)).to eq([0, 1, 2, 3, 4])
    end

    it 'assigns the account to the seeded stages' do
      pipeline = described_class.create!(account: account, name: 'Inbound', position: 0)

      expect(pipeline.deal_stages.pluck(:account_id).uniq).to eq([account.id])
    end
  end

  describe '.seed_default' do
    it 'creates the default pipeline for an account without one' do
      pipeline = described_class.seed_default(account)

      expect(pipeline.name).to eq(described_class::DEFAULT_NAME)
      expect(pipeline.position).to eq(0)
    end

    it 'is idempotent' do
      described_class.seed_default(account)
      expect { described_class.seed_default(account) }.not_to change(described_class, :count)
    end

    it 'returns the first existing pipeline instead of creating one' do
      existing = create(:pipeline, account: account, name: 'Outbound', position: 0)

      expect(described_class.seed_default(account)).to eq(existing)
    end
  end

  describe '.resolve' do
    it 'returns the requested pipeline of the account' do
      pipeline = create(:pipeline, account: account)

      expect(described_class.resolve(account, pipeline.id)).to eq(pipeline)
    end

    it 'falls back to the default pipeline when the id is blank' do
      expect(described_class.resolve(account, nil).name).to eq(described_class::DEFAULT_NAME)
    end

    it 'raises for a pipeline of another account' do
      other = create(:pipeline, account: create(:account))

      expect { described_class.resolve(account, other.id) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe '.ordered' do
    it 'sorts by position' do
      second = create(:pipeline, account: account, position: 1)
      first = create(:pipeline, account: account, position: 0)

      expect(account.pipelines.ordered).to eq([first, second])
    end
  end
end
