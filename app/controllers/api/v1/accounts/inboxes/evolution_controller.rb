class Api::V1::Accounts::Inboxes::EvolutionController < Api::V1::Accounts::BaseController
  before_action :fetch_inbox

  # Evolution's QR code lives for seconds, so the pairing screen asks for a new
  # one instead of showing whatever was stored at creation time.
  def qr_code
    @inbox.channel.refresh_qr_code!
    render json: { qr_code: @inbox.channel.qr_code, connection_state: @inbox.channel.connection_state }
  rescue Evolution::Api::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def fetch_inbox
    @inbox = Current.account.inboxes.find(params[:inbox_id])
    # Administrator-level on purpose: pairing rebinds the account's WhatsApp number.
    authorize @inbox, :update?
    render json: { error: 'This inbox is not an Evolution channel' }, status: :unprocessable_entity unless @inbox.evolution?
  end
end
