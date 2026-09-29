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
    # hsm_id scopes the delete to one language version; without it Meta removes all of them.
    result = @inbox.channel.delete_template(params[:name], params[:hsm_id])
    return render_meta_error(result) unless result[:success]

    @inbox.channel.sync_templates
    render json: { message_templates: @inbox.channel.reload.message_templates }, status: :ok
  end

  private

  def fetch_inbox
    @inbox = Current.account.inboxes.find(params[:inbox_id])
    # Administrator-level on purpose: these calls write to the account's Meta WABA.
    authorize @inbox, :update?
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
    error = [message || I18n.t('errors.whatsapp_templates.failed'), permission_hint].compact.join(' ')
    render json: { error: error }, status: :unprocessable_entity
  end

  # Meta answers with the same sentence whether the WABA id is wrong, the token cannot
  # see it, or the token can read it but not write templates. Our own read check splits
  # those, so run it once the write has already failed and say which half broke.
  #
  # The hint is a bonus on a path that is already failing: if the extra call to Meta blows
  # up, the user still needs to see what Meta said about the write.
  def permission_hint
    key = @inbox.channel.provider_service.validate_provider_config? ? :write_permission : :unreachable_waba
    I18n.t("errors.whatsapp_templates.#{key}")
  rescue StandardError => e
    Rails.logger.error("[WHATSAPP] Could not classify the template failure for inbox #{@inbox.id}: #{e.message}")
    nil
  end
end
