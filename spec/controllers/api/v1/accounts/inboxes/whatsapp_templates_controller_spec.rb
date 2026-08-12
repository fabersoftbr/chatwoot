require 'rails_helper'

RSpec.describe 'WhatsApp Templates API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:whatsapp_channel) do
    create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud',
                              validate_provider_config: false, sync_templates: false)
  end
  let(:inbox) { whatsapp_channel.inbox }
  let(:valid_params) do
    { name: 'boas_vindas', language: 'pt_BR', category: 'UTILITY',
      body: 'Olá {{1}}', examples: ['Pedro'] }
  end

  describe 'POST /api/v1/accounts/{account.id}/inboxes/{inbox.id}/whatsapp_templates' do
    context 'when unauthenticated' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/whatsapp_templates", params: valid_params
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when the user is an agent' do
      it 'returns forbidden — templates are an administrator action' do
        post "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/whatsapp_templates",
             params: valid_params, headers: agent.create_new_auth_token

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when the user is an administrator' do
      it 'creates the template and returns the refreshed list' do
        allow_any_instance_of(Channel::Whatsapp).to receive(:create_template)
          .and_return({ success: true, body: { 'id' => '999' } })
        allow_any_instance_of(Channel::Whatsapp).to receive(:sync_templates)
        whatsapp_channel.update!(message_templates: [{ 'name' => 'boas_vindas', 'status' => 'PENDING' }])

        post "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/whatsapp_templates",
             params: valid_params, headers: administrator.create_new_auth_token

        expect(response).to have_http_status(:created)
        expect(response.parsed_body['message_templates'].first['name']).to eq('boas_vindas')
      end

      it 'passes the built payload to the channel' do
        expect_any_instance_of(Channel::Whatsapp).to receive(:create_template).with(
          hash_including(name: 'boas_vindas', language: 'pt_BR', category: 'UTILITY')
        ).and_return({ success: true, body: {} })
        allow_any_instance_of(Channel::Whatsapp).to receive(:sync_templates)

        post "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/whatsapp_templates",
             params: valid_params, headers: administrator.create_new_auth_token
      end

      it 'returns 422 with the builder message when the params are invalid' do
        post "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/whatsapp_templates",
             params: valid_params.merge(body: 'Olá {{1}} e {{3}}', examples: %w[a b]),
             headers: administrator.create_new_auth_token

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to match(/sequence/i)
      end

      it 'returns 422 with the Meta error message verbatim' do
        allow_any_instance_of(Channel::Whatsapp).to receive(:create_template).and_return(
          { success: false, body: { 'error' => { 'message' => 'Template name already exists' } } }
        )

        post "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/whatsapp_templates",
             params: valid_params, headers: administrator.create_new_auth_token

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to eq('Template name already exists')
      end

      it 'does not sync templates when creation failed' do
        allow_any_instance_of(Channel::Whatsapp).to receive(:create_template)
          .and_return({ success: false, body: {} })
        expect_any_instance_of(Channel::Whatsapp).not_to receive(:sync_templates)

        post "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/whatsapp_templates",
             params: valid_params, headers: administrator.create_new_auth_token
      end
    end

    context 'when the channel is not WhatsApp Cloud' do
      let(:other_inbox) { create(:channel_twilio_sms, account: account).inbox }

      it 'returns 422' do
        post "/api/v1/accounts/#{account.id}/inboxes/#{other_inbox.id}/whatsapp_templates",
             params: valid_params, headers: administrator.create_new_auth_token

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'DELETE /api/v1/accounts/{account.id}/inboxes/{inbox.id}/whatsapp_templates/{name}' do
    it 'returns forbidden for an agent' do
      delete "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/whatsapp_templates/boas_vindas",
             headers: agent.create_new_auth_token

      expect(response).to have_http_status(:forbidden)
    end

    it 'deletes the template and returns the refreshed list for an administrator' do
      expect_any_instance_of(Channel::Whatsapp).to receive(:delete_template)
        .with('boas_vindas').and_return({ success: true, body: {} })
      allow_any_instance_of(Channel::Whatsapp).to receive(:sync_templates)

      delete "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/whatsapp_templates/boas_vindas",
             headers: administrator.create_new_auth_token

      expect(response).to have_http_status(:ok)
    end

    it 'returns 422 with the Meta error when deletion fails' do
      allow_any_instance_of(Channel::Whatsapp).to receive(:delete_template).and_return(
        { success: false, body: { 'error' => { 'message' => 'Template not found' } } }
      )

      delete "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/whatsapp_templates/boas_vindas",
             headers: administrator.create_new_auth_token

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to eq('Template not found')
    end
  end
end
