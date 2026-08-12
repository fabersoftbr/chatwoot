module Whatsapp::Providers::Concerns::TemplateManagement
  extend ActiveSupport::Concern

  # Deliberately not routed through `process_response`: that helper is for
  # message sends and returns nil after logging, which would hide the Meta
  # error text the dashboard needs to show verbatim.
  def create_template(payload)
    response = HTTParty.post("#{business_account_path}/message_templates", headers: api_headers, body: payload.to_json)
    template_response(response)
  end

  # Meta deletes EVERY language version of a template when only `name` is sent.
  # Passing the template's own Meta id as `hsm_id` narrows the delete to the one
  # language the user clicked. Without an id we can only do the name-only form,
  # which is why the dashboard warns explicitly in that case.
  def delete_template(name, hsm_id = nil)
    query = { name: name }
    query[:hsm_id] = hsm_id if hsm_id.present?
    response = HTTParty.delete("#{business_account_path}/message_templates?#{query.to_query}", headers: api_headers)
    template_response(response)
  end

  private

  def template_response(response)
    { success: response.success?, body: response.parsed_response }
  end
end
