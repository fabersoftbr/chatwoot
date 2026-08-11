require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::DealStagesController', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }

  describe 'GET /api/v1/accounts/{account.id}/deal_stages' do
    it 'returns unauthorized for an anonymous request' do
      get "/api/v1/accounts/#{account.id}/deal_stages"
      expect(response).to have_http_status(:unauthorized)
    end

    it 'seeds the default stages on the first call' do
      get "/api/v1/accounts/#{account.id}/deal_stages", headers: agent.create_new_auth_token

      expect(response).to have_http_status(:success)
      payload = response.parsed_body['payload']
      expect(payload.pluck('name')).to eq(
        ['Prospectado', 'Em negociação', 'Contrato enviado', 'Ganho', 'Perdido']
      )
      expect(payload.first['stage_type']).to eq('open')
    end

    it 'does not seed twice' do
      2.times { get "/api/v1/accounts/#{account.id}/deal_stages", headers: agent.create_new_auth_token }

      expect(account.deal_stages.count).to eq(5)
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/deal_stages' do
    it 'creates a stage for an administrator' do
      expect do
        post "/api/v1/accounts/#{account.id}/deal_stages",
             params: { name: 'Proposta', color: '#111111', position: 9 },
             headers: administrator.create_new_auth_token
      end.to change(account.deal_stages, :count).by(1)

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['name']).to eq('Proposta')
    end

    it 'rejects an agent' do
      post "/api/v1/accounts/#{account.id}/deal_stages",
           params: { name: 'Proposta' },
           headers: agent.create_new_auth_token

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'PATCH /api/v1/accounts/{account.id}/deal_stages/reorder' do
    it 'writes the new order' do
      first = create(:deal_stage, account: account, position: 0)
      second = create(:deal_stage, account: account, position: 1)

      patch "/api/v1/accounts/#{account.id}/deal_stages/reorder",
            params: { stage_ids: [second.id, first.id] },
            headers: administrator.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(second.reload.position).to eq(0)
      expect(first.reload.position).to eq(1)
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
  end
end
