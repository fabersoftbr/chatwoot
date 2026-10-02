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
    meta_error = result[:body].is_a?(Hash) ? result[:body]['error'] : nil
    message = meta_error&.dig('message')
    hint = permission_hint if access_error?(meta_error)
    render json: { error: [message || I18n.t('errors.whatsapp_templates.failed'), hint].compact.join(' ') },
           status: :unprocessable_entity
  end

  # Only an access complaint earns our hint. Meta answers with the same sentence whether the WABA
  # id is wrong, the token cannot see it, or the token can read it but not write templates, and
  # splitting those is worth a second call. A payload complaint like "Invalid parameter" is not
  # about access at all, and appending an access lecture to it sends people into Business Manager
  # to fix something that was never broken.
  def access_error?(meta_error)
    return false if meta_error.blank?

    meta_error['code'].to_i == 200 ||
      meta_error['error_subcode'].to_i == 33 ||
      meta_error['message'].to_s.downcase.include?('permission')
  end

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
