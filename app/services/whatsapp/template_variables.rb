# The contact fields a template author can drop straight into a message body. Meta calls these
# NAMED parameters: the registered body carries {{contact_first_name}} and the send supplies a
# value under that same name, which is what Whatsapp::TemplateProcessorService already emits for
# templates whose parameter_format is NAMED.
#
# Keep this list in step with CONTACT_VARIABLES in WhatsappTemplateForm.vue — the form offers
# exactly these and the builder refuses anything else, so a typo is caught before Meta sees it.
module Whatsapp::TemplateVariables
  PATTERN = /\{\{([a-z][a-z0-9_]*)\}\}/

  RESOLVERS = {
    'contact_name' => ->(contact, _sender) { contact.name },
    'contact_first_name' => ->(contact, _sender) { contact.name.to_s.split.first },
    'contact_phone_number' => ->(contact, _sender) { contact.phone_number },
    'contact_email' => ->(contact, _sender) { contact.email },
    'agent_name' => ->(_contact, sender) { sender&.name }
  }.freeze

  module_function

  def supported
    RESOLVERS.keys
  end

  # Named variables in the order they first appear, so the examples the form collects line up.
  def extract(body)
    body.to_s.scan(PATTERN).flatten.uniq
  end

  def unsupported(names)
    names - supported
  end

  # The body params a NAMED template needs, keyed the way Meta expects them. A variable the
  # contact cannot fill comes back blank, and the caller decides whether that is worth sending.
  def resolve(names, contact:, sender: nil)
    names.index_with { |name| RESOLVERS[name].call(contact, sender).to_s }
  end

  # Overwrites every supported contact variable in the body params with this contact's own value.
  # Keyed by name, so no template lookup is needed: whatever the author left under
  # "contact_first_name" is this contact's first name by the time it reaches Meta. Values the
  # author typed under any other key are left alone.
  def fill(template_params, contact:, sender: nil)
    body = template_params&.dig('processed_params', 'body')
    return template_params if body.blank?

    names = body.keys & supported
    return template_params if names.empty?

    filled = body.merge(resolve(names, contact: contact, sender: sender))
    template_params.deep_merge('processed_params' => { 'body' => filled })
  end
end
