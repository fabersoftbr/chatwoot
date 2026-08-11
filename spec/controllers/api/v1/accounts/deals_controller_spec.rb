require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::DealsController', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:contact) { create(:contact, account: account) }
  let(:open_stage) { create(:deal_stage, account: account, stage_type: :open, position: 0) }
  let(:lost_stage) { create(:deal_stage, account: account, stage_type: :lost, position: 1) }

  describe 'GET /api/v1/accounts/{account.id}/deals' do
    it 'returns unauthorized for an anonymous request' do
      get "/api/v1/accounts/#{account.id}/deals"
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns the deals of the account only' do
      deal = create(:deal, account: account, contact: contact, deal_stage: open_stage)
      create(:deal)

      get "/api/v1/accounts/#{account.id}/deals", headers: agent.create_new_auth_token

      expect(response).to have_http_status(:success)
      payload = response.parsed_body['payload']
      expect(payload.length).to eq(1)
      expect(payload.first['id']).to eq(deal.id)
      expect(payload.first['contact']['id']).to eq(contact.id)
    end

    it 'filters by stage, assignee and temperature' do
      create(:deal, account: account, contact: contact, deal_stage: open_stage, temperature: :cold)
      wanted = create(:deal, account: account, contact: contact, deal_stage: open_stage,
                             temperature: :hot, assignee: agent)

      get "/api/v1/accounts/#{account.id}/deals",
          params: { stage_id: open_stage.id, assignee_id: agent.id, temperature: 'hot' },
          headers: agent.create_new_auth_token

      expect(response.parsed_body['payload'].pluck('id')).to eq([wanted.id])
    end

    it 'filters overdue deals' do
      overdue = create(:deal, account: account, contact: contact, deal_stage: open_stage,
                              next_action_at: 2.days.ago)
      create(:deal, account: account, contact: contact, deal_stage: open_stage,
                    next_action_at: 2.days.from_now)

      get "/api/v1/accounts/#{account.id}/deals",
          params: { overdue: 'true' },
          headers: agent.create_new_auth_token

      expect(response.parsed_body['payload'].pluck('id')).to eq([overdue.id])
    end

    it 'searches by title and contact name' do
      create(:deal, account: account, contact: contact, deal_stage: open_stage, title: 'Outro')
      wanted = create(:deal, account: account, contact: contact, deal_stage: open_stage, title: 'Contrato anual')

      get "/api/v1/accounts/#{account.id}/deals",
          params: { q: 'contrato' },
          headers: agent.create_new_auth_token

      expect(response.parsed_body['payload'].pluck('id')).to eq([wanted.id])
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/deals/board' do
    it 'returns every stage with its deals, count and value sum' do
      create(:deal, account: account, contact: contact, deal_stage: open_stage, value_cents: 10_000)
      create(:deal, account: account, contact: contact, deal_stage: open_stage, value_cents: 25_000)

      get "/api/v1/accounts/#{account.id}/deals/board", headers: agent.create_new_auth_token

      expect(response).to have_http_status(:success)
      column = response.parsed_body['payload'].find { |stage| stage['id'] == open_stage.id }
      expect(column['deals_count']).to eq(2)
      expect(column['deals_value_cents']).to eq(35_000)
      expect(column['deals'].length).to eq(2)
    end

    it 'seeds the default stages when the account has none' do
      get "/api/v1/accounts/#{account.id}/deals/board", headers: agent.create_new_auth_token

      expect(response.parsed_body['payload'].length).to eq(5)
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/deals' do
    it 'creates a deal' do
      expect do
        post "/api/v1/accounts/#{account.id}/deals",
             params: { title: 'Contrato anual', contact_id: contact.id, deal_stage_id: open_stage.id,
                       value_cents: 1_200_000, temperature: 'hot' },
             headers: agent.create_new_auth_token
      end.to change(account.deals, :count).by(1)

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['title']).to eq('Contrato anual')
      expect(response.parsed_body['temperature']).to eq('hot')
    end

    it 'returns 422 without a title' do
      post "/api/v1/accounts/#{account.id}/deals",
           params: { contact_id: contact.id, deal_stage_id: open_stage.id },
           headers: agent.create_new_auth_token

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'PATCH /api/v1/accounts/{account.id}/deals/{id}/move' do
    it 'moves the deal to another stage' do
      deal = create(:deal, account: account, contact: contact, deal_stage: open_stage)
      target = create(:deal_stage, account: account, stage_type: :open, position: 2)

      patch "/api/v1/accounts/#{account.id}/deals/#{deal.id}/move",
            params: { stage_id: target.id, position: 0 },
            headers: agent.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(deal.reload.deal_stage_id).to eq(target.id)
    end

    it 'returns 422 when moving into a lost stage without a reason' do
      deal = create(:deal, account: account, contact: contact, deal_stage: open_stage)

      patch "/api/v1/accounts/#{account.id}/deals/#{deal.id}/move",
            params: { stage_id: lost_stage.id, position: 0 },
            headers: agent.create_new_auth_token

      expect(response).to have_http_status(:unprocessable_entity)
      expect(deal.reload.deal_stage_id).to eq(open_stage.id)
    end

    it 'returns 422 when the target stage belongs to another account' do
      deal = create(:deal, account: account, contact: contact, deal_stage: open_stage)
      foreign_stage = create(:deal_stage, account: create(:account), stage_type: :open, position: 0)

      patch "/api/v1/accounts/#{account.id}/deals/#{deal.id}/move",
            params: { stage_id: foreign_stage.id, position: 0 },
            headers: agent.create_new_auth_token

      expect(response).to have_http_status(:unprocessable_entity)
      expect(deal.reload.deal_stage_id).to eq(open_stage.id)
    end

    it 'records the lost reason' do
      deal = create(:deal, account: account, contact: contact, deal_stage: open_stage)

      patch "/api/v1/accounts/#{account.id}/deals/#{deal.id}/move",
            params: { stage_id: lost_stage.id, position: 0, lost_reason: 'Preço' },
            headers: agent.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(deal.reload.lost_reason).to eq('Preço')
    end
  end

  describe 'DELETE /api/v1/accounts/{account.id}/deals/{id}' do
    it 'rejects an agent' do
      deal = create(:deal, account: account, contact: contact, deal_stage: open_stage)

      delete "/api/v1/accounts/#{account.id}/deals/#{deal.id}", headers: agent.create_new_auth_token

      expect(response).to have_http_status(:unauthorized)
    end

    it 'allows an administrator' do
      deal = create(:deal, account: account, contact: contact, deal_stage: open_stage)

      delete "/api/v1/accounts/#{account.id}/deals/#{deal.id}", headers: administrator.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(account.deals.find_by(id: deal.id)).to be_nil
    end
  end
end
