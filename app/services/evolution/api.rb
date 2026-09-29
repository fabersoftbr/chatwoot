# Thin wrapper over the Evolution API. It exists so the channel does not repeat
# the base url, the apikey header and the "raise on anything but 2xx" handling.
class Evolution::Api
  Error = Class.new(StandardError)

  def initialize(path, payload = {}, method = :post)
    @path = path
    @payload = payload
    @method = method
  end

  def call
    response = HTTParty.send(
      @method,
      "#{ENV.fetch('EVOLUTION_API_URL')}/#{@path}",
      headers: { 'Content-Type' => 'application/json', 'apikey' => ENV.fetch('EVOLUTION_API_KEY') },
      body: @payload.to_json,
      timeout: 15
    )
    raise Error, evolution_error(response) unless response.success?

    response.parsed_response
  end

  private

  # Evolution answers with { message: ... } or { response: { message: [...] } }.
  def evolution_error(response)
    body = response.parsed_response
    return response.body.to_s unless body.is_a?(Hash)

    Array(body['message'] || body.dig('response', 'message')).join(', ').presence || response.body.to_s
  end
end
