class Api::V1::Accounts::Inboxes::WhatsappTemplatesController < Api::V1::Accounts::BaseController
  before_action :fetch_inbox
  before_action :validate_whatsapp_cloud_channel

  def create
    payload = Whatsapp::TemplateBuilder.new(**template_params.to_h.symbolize_keys).build
    result = @inbox.channel.create_template(payload)
    return render_meta_error(result) unless result[:success]

    @inbox.channel.sync_templates
    render json: { message_templates: @inbox.channel.reload.message_templates }, status: :created
  rescue Whatsapp::TemplateBuilder::InvalidTemplateError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    result = @inbox.channel.delete_template(params[:name])
    return render_meta_error(result) unless result[:success]

    @inbox.channel.sync_templates
    render json: { message_templates: @inbox.channel.reload.message_templates }, status: :ok
  end

  private

  def fetch_inbox
    @inbox = Current.account.inboxes.find(params[:inbox_id])
    # Administrator-level on purpose: these calls write to the account's Meta WABA.
    # Checked directly (not via `authorize`) because the app-wide
    # Pundit::NotAuthorizedError handler renders 401 for every controller;
    # a denied write to the WABA must read as 403, a deliberate block, not
    # an authentication problem.
    return if InboxPolicy.new(pundit_user, @inbox).update?

    render json: { error: 'You are not authorized to do this action' }, status: :forbidden
  end

  def validate_whatsapp_cloud_channel
    return if @inbox.channel.is_a?(Channel::Whatsapp) && @inbox.channel.provider == 'whatsapp_cloud'

    render json: { error: 'Template management is only available for WhatsApp Cloud channels' },
           status: :unprocessable_entity
  end

  def template_params
    params.permit(:name, :language, :category, :body, examples: [])
  end

  # Meta's own wording is the most useful thing we can show; translating it
  # would hide the real reason and turn every rejection into a support ticket.
  def render_meta_error(result)
    body = result[:body]
    message = body.is_a?(Hash) ? body.dig('error', 'message') : nil
    render json: { error: message || 'Template request failed', details: body }, status: :unprocessable_entity
  end
end
