# == Schema Information
#
# Table name: channel_evolution
#
#  id                    :bigint           not null, primary key
#  additional_attributes :jsonb
#  identifier            :string
#  instance_token        :string
#  qr_code               :string
#  webhook_url           :string
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  account_id            :integer          not null
#  instance_id           :string
#
# Indexes
#
#  index_channel_evolution_on_identifier  (identifier) UNIQUE
#

# A WhatsApp inbox backed by an Evolution API instance. Evolution pushes incoming
# messages into Chatwoot through its own Chatwoot integration, and Chatwoot pushes
# agent replies back through the API-inbox webhook — which is why this behaves
# like Channel::Api with webhook_url pinned to the instance.
class Channel::Evolution < ApplicationRecord
  include Channelable

  # The inbox does not exist yet when the channel is created, but Evolution needs
  # its name to bind the instance to it.
  attr_accessor :inbox_name

  self.table_name = 'channel_evolution'
  EDITABLE_ATTRS = [:inbox_name, { additional_attributes: {} }].freeze

  has_secure_token :identifier
  has_secure_token :instance_token

  before_create :create_evolution_instance
  before_destroy :delete_evolution_instance

  def name
    'Evolution'
  end

  # Evolution's QR code expires after a few seconds, so the dashboard asks for a
  # fresh one every time it shows the pairing screen.
  def refresh_qr_code!
    response = Evolution::Api.new("instance/connect/#{identifier}", {}, :get).call
    update!(qr_code: response['base64'])
    response
  end

  def connection_state
    Evolution::Api.new("instance/connectionState/#{identifier}", {}, :get).call.dig('instance', 'state')
  end

  private

  def create_evolution_instance
    response = Evolution::Api.new('instance/create', instance_payload).call
    self.instance_id = response.dig('instance', 'instanceId')
    self.qr_code = response.dig('qrcode', 'base64')
    self.webhook_url = "#{ENV.fetch('EVOLUTION_API_URL')}/chatwoot/webhook/#{identifier}"
  end

  def instance_payload
    {
      instanceName: identifier,
      token: instance_token,
      integration: 'WHATSAPP-BAILEYS',
      qrcode: true,
      chatwootAccountId: account.id.to_s,
      chatwootToken: account.administrators.first!.access_token.token,
      chatwootUrl: ENV.fetch('FRONTEND_URL'),
      chatwootNameInbox: inbox_name,
      chatwootSignMsg: true,
      chatwootReopenConversation: true,
      chatwootConversationPending: false,
      chatwootImportContacts: false,
      chatwootImportMessages: false,
      chatwootAutoCreate: false,
      chatwootOrganization: account.name
    }
  end

  # Leaving the instance behind would keep the phone paired and burn an Evolution
  # connection for an inbox nobody can see anymore.
  def delete_evolution_instance
    Evolution::Api.new("instance/delete/#{identifier}", {}, :delete).call
  rescue Evolution::Api::Error => e
    Rails.logger.error "Failed to delete Evolution instance #{identifier}: #{e.message}"
  end
end
