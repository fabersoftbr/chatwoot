# Turns one claimed step into one outgoing Message. Creating the Message is the send on both
# channels: WhatsApp Cloud picks it up through SendReplyJob -> Whatsapp::SendOnWhatsappService, and
# Evolution through the api-inbox webhook in WebhookListener. The Message is also the audit trail —
# its status and external_error are where a refusal lands.
class Cadences::SendStepService
  pattr_initialize [:enrollment!, :step!]

  def perform
    return if contact.phone_number.blank?
    # A variable that resolves to nothing would send "Olá ," so skip this contact for this step,
    # the same call campaigns make.
    return if cadence.whatsapp_cloud? && template_params.blank?

    conversation = enrollment.conversation || create_conversation
    enrollment.update!(conversation: conversation) if enrollment.conversation.blank?

    Messages::MessageBuilder.new(cadence.sender, conversation, message_params).perform
  end

  private

  delegate :cadence, to: :enrollment
  delegate :contact, to: :enrollment
  delegate :inbox, to: :cadence

  def create_conversation
    contact_inbox = ContactInboxBuilder.new(
      contact: contact,
      inbox: inbox,
      # Passed explicitly because ContactInboxBuilder raises on Channel::Evolution, and both channels
      # address the contact by the same bare e164 number.
      source_id: contact.phone_number.delete('+')
    ).perform

    ConversationBuilder.new(params: {}, contact_inbox: contact_inbox).perform
  end

  def message_params
    params = { content: rendered_content, message_type: 'outgoing' }
    params[:template_params] = template_params if cadence.whatsapp_cloud?
    params
  end

  # The step stores what the author typed, so a variable may hold Liquid like {{contact.name}}.
  # Resolving it here is what makes a cadence personal; nil means something rendered blank.
  # Memoized because perform checks it before building the message.
  def template_params
    return @template_params if defined?(@template_params)

    @template_params = Whatsapp::LiquidTemplateProcessorService
                       .new(campaign: cadence, contact: contact)
                       .process_template_params(step['template_params'])
  end

  # What lands in the conversation bubble. On Cloud the wire payload is the approved template, so
  # this is only what the agent reads in the thread: the step's own text when the author wrote one,
  # else the template name, which beats an empty bubble. Liquid::CampaignTemplateService wants
  # anything answering sender/inbox/account, and a Cadence answers all three.
  def rendered_content
    body = step['content'].presence || (cadence.whatsapp_cloud? ? step['template_params']['name'] : nil)
    return if body.blank?

    Liquid::CampaignTemplateService.new(campaign: cadence, contact: contact).call(body)
  end
end
