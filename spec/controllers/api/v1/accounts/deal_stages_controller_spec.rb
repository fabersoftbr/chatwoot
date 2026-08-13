require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::DealStagesController', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:pipeline) { Pipeline.seed_default(account) }

  describe 'GET /api/v1/accounts/{account.id}/deal_stages' do
    it 'returns unauthorized for an anonymous request' do
      get "/api/v1/accounts/#{account.id}/deal_stages"
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns the stages of the requested pipeline' do
      get "/api/v1/accounts/#{account.id}/deal_stages",
          params: { pipeline_id: pipeline.id },
          headers: agent.create_new_auth_token

      expect(response).to have_http_status(:success)
      payload = response.parsed_body['payload']
      expect(payload.pluck('name')).to eq(
        ['Prospectado', 'Em negociação', 'Contrato enviado', 'Ganho', 'Perdido']
      )
      expect(payload.pluck('pipeline_id').uniq).to eq([pipeline.id])
    end

    it 'does not return the stages of another pipeline' do
      other = create(:pipeline, account: account, name: 'Outbound')

      get "/api/v1/accounts/#{account.id}/deal_stages",
          params: { pipeline_id: other.id },
          headers: agent.create_new_auth_token

      expect(response.parsed_body['payload'].pluck('id')).to match_array(other.deal_stages.pluck(:id))
    end

    it 'falls back to the default pipeline without a pipeline_id' do
      pipeline

      get "/api/v1/accounts/#{account.id}/deal_stages", headers: agent.create_new_auth_token

      expect(response.parsed_body['payload'].pluck('pipeline_id').uniq).to eq([pipeline.id])
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/deal_stages' do
    it 'creates a stage for an administrator' do
      expect do
        post "/api/v1/accounts/#{account.id}/deal_stages",
             params: { name: 'Proposta', color: '#111111', position: 9, pipeline_id: pipeline.id },
             headers: administrator.create_new_auth_token
      end.to change(pipeline.deal_stages, :count).by(1)

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['name']).to eq('Proposta')
    end

    it 'creates a stage for an agent' do
      expect do
        post "/api/v1/accounts/#{account.id}/deal_stages",
             params: { name: 'Proposta', color: '#111111', position: 9, pipeline_id: pipeline.id },
             headers: agent.create_new_auth_token
      end.to change(pipeline.deal_stages, :count).by(1)

      expect(response).to have_http_status(:success)
    end
  end

  describe 'PATCH /api/v1/accounts/{account.id}/deal_stages/reorder' do
    # Pipeline#after_create seeds 5 default stages, so the pipeline always has
    # more stages than the ones each example creates and reorders explicitly.
    # Assertions below compare relative order rather than absolute positions.
    it 'writes the new order' do
      first = create(:deal_stage, account: account, pipeline: pipeline, position: 10)
      second = create(:deal_stage, account: account, pipeline: pipeline, position: 11)

      patch "/api/v1/accounts/#{account.id}/deal_stages/reorder",
            params: { pipeline_id: pipeline.id, stage_ids: [second.id, first.id] },
            headers: administrator.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(second.reload.position).to be < first.reload.position
    end

    it 'keeps positions distinct when the request omits a stage' do
      first = create(:deal_stage, account: account, pipeline: pipeline, position: 10)
      second = create(:deal_stage, account: account, pipeline: pipeline, position: 11)
      third = create(:deal_stage, account: account, pipeline: pipeline, position: 12)

      patch "/api/v1/accounts/#{account.id}/deal_stages/reorder",
            params: { pipeline_id: pipeline.id, stage_ids: [third.id, first.id] },
            headers: administrator.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(third.reload.position).to be < first.reload.position
      expect(first.reload.position).to be < second.reload.position
      expect([first, second, third].map(&:position).uniq.length).to eq(3)
    end

    it 'ignores a stage id belonging to another account' do
      first = create(:deal_stage, account: account, pipeline: pipeline, position: 10)
      second = create(:deal_stage, account: account, pipeline: pipeline, position: 11)
      other_account_stage = create(:deal_stage)
      other_position = other_account_stage.position

      patch "/api/v1/accounts/#{account.id}/deal_stages/reorder",
            params: { pipeline_id: pipeline.id, stage_ids: [other_account_stage.id, second.id, first.id] },
            headers: administrator.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(second.reload.position).to be < first.reload.position
      expect(other_account_stage.reload.position).to eq(other_position)
    end
  end

  describe 'DELETE /api/v1/accounts/{account.id}/deal_stages/{id}' do
    it 'deletes an empty stage' do
      stage = create(:deal_stage, account: account)

      delete "/api/v1/accounts/#{account.id}/deal_stages/#{stage.id}",
             headers: administrator.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(account.deal_stages.find_by(id: stage.id)).to be_nil
    end

    it 'refuses to delete a stage that still holds deals' do
      stage = create(:deal_stage, account: account)
      create(:deal, account: account, deal_stage: stage)

      delete "/api/v1/accounts/#{account.id}/deal_stages/#{stage.id}",
             headers: administrator.create_new_auth_token

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['deals_count']).to eq(1)
    end

    it 'blocks deleting the last won stage' do
      won = pipeline.deal_stages.find_by(stage_type: :won)

      delete "/api/v1/accounts/#{account.id}/deal_stages/#{won.id}", headers: agent.create_new_auth_token

      expect(response).to have_http_status(:unprocessable_entity)
      expect(DealStage.exists?(won.id)).to be(true)
    end
  end
end
