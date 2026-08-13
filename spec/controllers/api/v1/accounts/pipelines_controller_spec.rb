require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::PipelinesController', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }

  describe 'GET /api/v1/accounts/{account.id}/pipelines' do
    it 'returns unauthorized for an anonymous request' do
      get "/api/v1/accounts/#{account.id}/pipelines"
      expect(response).to have_http_status(:unauthorized)
    end

    it 'seeds the default pipeline on the first call' do
      get "/api/v1/accounts/#{account.id}/pipelines", headers: agent.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['payload'].pluck('name')).to eq([Pipeline::DEFAULT_NAME])
    end

    it 'does not seed twice' do
      2.times { get "/api/v1/accounts/#{account.id}/pipelines", headers: agent.create_new_auth_token }

      expect(account.pipelines.count).to eq(1)
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/pipelines' do
    it 'creates a pipeline with its default stages for an agent' do
      post "/api/v1/accounts/#{account.id}/pipelines",
           params: { name: 'Outbound', position: 1 },
           headers: agent.create_new_auth_token

      expect(response).to have_http_status(:success)
      pipeline = account.pipelines.find(response.parsed_body['id'])
      expect(pipeline.name).to eq('Outbound')
      expect(pipeline.deal_stages.count).to eq(5)
    end
  end

  describe 'PATCH /api/v1/accounts/{account.id}/pipelines/{id}' do
    it 'renames a pipeline' do
      pipeline = create(:pipeline, account: account)

      patch "/api/v1/accounts/#{account.id}/pipelines/#{pipeline.id}",
            params: { name: 'Renomeado' },
            headers: agent.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(pipeline.reload.name).to eq('Renomeado')
    end

    it 'does not expose a pipeline of another account' do
      other = create(:pipeline, account: create(:account))

      patch "/api/v1/accounts/#{account.id}/pipelines/#{other.id}",
            params: { name: 'Nope' },
            headers: agent.create_new_auth_token

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE /api/v1/accounts/{account.id}/pipelines/{id}' do
    it 'deletes a pipeline and its stages' do
      pipeline = create(:pipeline, account: account)

      expect do
        delete "/api/v1/accounts/#{account.id}/pipelines/#{pipeline.id}", headers: agent.create_new_auth_token
      end.to change(DealStage, :count).by(-5)

      expect(response).to have_http_status(:success)
      expect(Pipeline.exists?(pipeline.id)).to be(false)
    end

    it 'blocks deleting a pipeline that still has deals' do
      pipeline = create(:pipeline, account: account)
      stage = pipeline.deal_stages.ordered.first
      create(:deal, account: account, deal_stage: stage)

      delete "/api/v1/accounts/#{account.id}/pipelines/#{pipeline.id}", headers: agent.create_new_auth_token

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['deals_count']).to eq(1)
      expect(Pipeline.exists?(pipeline.id)).to be(true)
    end
  end
end
