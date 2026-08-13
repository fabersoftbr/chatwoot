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

  describe 'pipeline scoping' do
    it 'belongs to a pipeline' do
      pipeline = create(:pipeline, account: account)
      stage = create(:deal_stage, account: account, pipeline: pipeline)

      expect(stage.pipeline).to eq(pipeline)
    end
  end

  describe 'destroying closing stages' do
    let(:pipeline) { create(:pipeline, account: account) }

    it 'refuses to destroy the last won stage of the pipeline' do
      won = pipeline.deal_stages.find_by(stage_type: :won)

      expect(won.destroy).to be(false)
      expect(won.errors[:base]).to be_present
      expect(described_class.exists?(won.id)).to be(true)
    end

    it 'refuses to destroy the last lost stage of the pipeline' do
      lost = pipeline.deal_stages.find_by(stage_type: :lost)

      expect(lost.destroy).to be(false)
    end

    it 'allows destroying a won stage when the pipeline has another one' do
      won = pipeline.deal_stages.find_by(stage_type: :won)
      create(:deal_stage, account: account, pipeline: pipeline, stage_type: :won, position: 9)

      expect(won.destroy).to be_truthy
    end

    it 'allows destroying an open stage' do
      open_stage = pipeline.deal_stages.find_by(stage_type: :open)

      expect(open_stage.destroy).to be_truthy
    end
  end

  describe '.ordered' do
    it 'sorts by position' do
      pipeline = create(:pipeline, account: account)
      second = create(:deal_stage, account: account, pipeline: pipeline, position: 11)
      first = create(:deal_stage, account: account, pipeline: pipeline, position: 10)

      expect(pipeline.deal_stages.ordered.last(2)).to eq([first, second])
    end
  end

  describe 'stage_type predicates' do
    it 'exposes prefixed predicates' do
      expect(build(:deal_stage, stage_type: :won)).to be_stage_won
      expect(build(:deal_stage, stage_type: :open)).not_to be_stage_lost
    end
  end
end
