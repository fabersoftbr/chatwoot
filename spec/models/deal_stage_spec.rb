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

    it 'is invalid when its pipeline belongs to a different account' do
      other_pipeline = create(:pipeline)
      stage = create(:deal_stage, account: account, pipeline: create(:pipeline, account: account))

      stage.pipeline = other_pipeline
      expect(stage).not_to be_valid
      expect(stage.errors[:pipeline]).to be_present
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

    it 'destroys all stages, including the last won and lost ones, when the pipeline itself is destroyed' do
      expect { pipeline.destroy }.to change(described_class, :count).by(-5)
    end

    it 'keeps the stages when the pipeline refuses to be destroyed because it still has deals' do
      create(:deal, account: account, deal_stage: pipeline.deal_stages.find_by(stage_type: :open))

      expect(pipeline.destroy).to be(false)
      expect(described_class.where(pipeline_id: pipeline.id).count).to eq(5)
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
