require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Deals::ActivitiesController', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:contact) { create(:contact, account: account) }
  let(:stage) { create(:deal_stage, account: account, stage_type: :open) }
  let(:deal) { create(:deal, account: account, contact: contact, deal_stage: stage) }

  describe 'GET /api/v1/accounts/{account.id}/deals/{deal.id}/activities' do
    it 'returns unauthorized for an anonymous request' do
      get "/api/v1/accounts/#{account.id}/deals/#{deal.id}/activities"
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns the timeline newest first' do
      create(:deal_activity, deal: deal, activity_type: :call, content: 'Antiga', created_at: 2.days.ago)
      create(:deal_activity, deal: deal, activity_type: :note, content: 'Recente', created_at: 1.hour.ago)

      get "/api/v1/accounts/#{account.id}/deals/#{deal.id}/activities",
          headers: agent.create_new_auth_token

      expect(response).to have_http_status(:success)
      payload = response.parsed_body['payload']
      contents = payload.pluck('content')
      # the auto-logged `created` activity's created_at is always "now" (deal creation time),
      # so it always sorts before these manually backdated activities; assert their relative order instead.
      expect(contents.index('Recente')).to be < contents.index('Antiga')
      expect(payload.pluck('activity_type')).to include('created')
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/deals/{deal.id}/activities' do
    it 'creates a manual activity attributed to the current user' do
      expect do
        post "/api/v1/accounts/#{account.id}/deals/#{deal.id}/activities",
             params: { activity_type: 'call', content: 'Liguei, retorna terça' },
             headers: agent.create_new_auth_token
      end.to change(deal.deal_activities, :count).by(1)

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body['activity_type']).to eq('call')
      expect(body['user']['id']).to eq(agent.id)
    end

    it 'refuses a system activity type' do
      post "/api/v1/accounts/#{account.id}/deals/#{deal.id}/activities",
           params: { activity_type: 'stage_changed', content: 'hack' },
           headers: agent.create_new_auth_token

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'refuses empty content' do
      post "/api/v1/accounts/#{account.id}/deals/#{deal.id}/activities",
           params: { activity_type: 'note', content: '' },
           headers: agent.create_new_auth_token

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/contacts/{contact.id}/deals' do
    it 'returns the deals of that contact only' do
      wanted = create(:deal, account: account, contact: contact, deal_stage: stage)
      create(:deal, account: account, deal_stage: stage)

      get "/api/v1/accounts/#{account.id}/contacts/#{contact.id}/deals",
          headers: agent.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['payload'].pluck('id')).to eq([wanted.id])
    end
  end
end
