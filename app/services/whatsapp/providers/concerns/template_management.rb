module Whatsapp::Providers::Concerns::TemplateManagement
  extend ActiveSupport::Concern

  # Deliberately not routed through `process_response`: that helper is for
  # message sends and returns nil after logging, which would hide the Meta
  # error text the dashboard needs to show verbatim.
  def create_template(payload)
    response = HTTParty.post("#{business_account_path}/message_templates", headers: api_headers, body: payload.to_json)
    template_response(response)
  end

  def delete_template(name)
    response = HTTParty.delete("#{business_account_path}/message_templates?name=#{CGI.escape(name)}", headers: api_headers)
    template_response(response)
  end

  private

  def template_response(response)
    { success: response.success?, body: response.parsed_response }
  end
end
