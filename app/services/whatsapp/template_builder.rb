# Turns the flat params the dashboard sends into the `components` payload Meta's
# Graph API expects, and rejects everything Meta would reject — a rejected
# template costs the user a round trip through Meta's review queue, so it is
# cheaper to refuse it here with a readable reason.
class Whatsapp::TemplateBuilder
  InvalidTemplateError = Class.new(StandardError)

  # AUTHENTICATION is deliberately absent: Meta rejects it in the shape this
  # builder emits. An authentication template needs a BODY carrying
  # `add_security_recommendation` and no free text, a FOOTER with
  # `code_expiration_minutes`, and a mandatory OTP BUTTONS component — a
  # different payload and a different form. Do not re-add it here alone.
  CATEGORIES = %w[UTILITY MARKETING].freeze
  NAME_FORMAT = /\A[a-z0-9_]+\z/
  NAME_MAX_LENGTH = 512
  VARIABLE_PATTERN = /\{\{(\d+)\}\}/

  def initialize(name: nil, language: nil, category: nil, body: nil, examples: [])
    @name = name.to_s.strip
    @language = language.to_s.strip
    @category = category.to_s.strip.upcase
    @body = body.to_s
    @examples = Array(examples).map(&:to_s)
  end

  def build
    validate_name!
    validate_language!
    validate_category!
    validate_body!
    validate_variables!

    payload = { name: @name, language: @language, category: @category, components: [body_component] }
    payload[:parameter_format] = 'NAMED' if named_variables.any?
    payload
  end

  private

  # Contact fields written straight into the body, e.g. "Olá {{contact_first_name}}".
  def named_variables
    @named_variables ||= Whatsapp::TemplateVariables.extract(@body)
  end

  # Ordered, de-duplicated variable indexes: "{{1}} e {{1}} e {{2}}" -> [1, 2]
  def variable_indexes
    @variable_indexes ||= @body.scan(VARIABLE_PATTERN).flatten.map(&:to_i).uniq.sort
  end

  def validate_name!
    raise InvalidTemplateError, 'Template name is required' if @name.blank?
    raise InvalidTemplateError, "Template name must be #{NAME_MAX_LENGTH} characters or fewer" if @name.length > NAME_MAX_LENGTH
    return if @name.match?(NAME_FORMAT)

    raise InvalidTemplateError, 'Template name may only contain lowercase letters, numbers and underscores'
  end

  def validate_language!
    raise InvalidTemplateError, 'Template language is required' if @language.blank?
  end

  def validate_category!
    return if CATEGORIES.include?(@category)

    raise InvalidTemplateError, "Template category must be one of: #{CATEGORIES.join(', ')}"
  end

  def validate_body!
    raise InvalidTemplateError, 'Template body is required' if @body.strip.blank?
  end

  def validate_variables!
    validate_named_variables!
    return if named_variables.any?
    return if variable_indexes.empty? && @examples.empty?

    # Meta requires {{1}}..{{n}} with no gaps; a hole makes the template unusable.
    unless variable_indexes == (1..variable_indexes.length).to_a
      raise InvalidTemplateError, 'Template variables must form the sequence {{1}}, {{2}}, ... with no gaps'
    end

    if @examples.length != variable_indexes.length
      raise InvalidTemplateError, "Expected #{variable_indexes.length} example value(s), got #{@examples.length}"
    end

    return if @examples.none? { |example| example.strip.blank? }

    raise InvalidTemplateError, 'Every variable needs a non-blank example value'
  end

  # Meta rejects a body that mixes the two styles, and an unknown name would register a parameter
  # nothing can ever fill, so both are refused here rather than in Meta's review queue.
  def validate_named_variables!
    return if named_variables.empty?

    unsupported = Whatsapp::TemplateVariables.unsupported(named_variables)
    if unsupported.any?
      raise InvalidTemplateError,
            "Unknown template variable(s): #{unsupported.join(', ')}. Available: #{Whatsapp::TemplateVariables.supported.join(', ')}"
    end

    raise InvalidTemplateError, 'A template cannot mix {{1}} variables with contact variables' if variable_indexes.any?

    if @examples.length != named_variables.length
      raise InvalidTemplateError, "Expected #{named_variables.length} example value(s), got #{@examples.length}"
    end

    return if @examples.none? { |example| example.strip.blank? }

    raise InvalidTemplateError, 'Every variable needs a non-blank example value'
  end

  def body_component
    component = { type: 'BODY', text: @body }
    component[:example] = example_component if variable_indexes.any? || named_variables.any?
    component
  end

  def example_component
    return { body_text: [@examples] } if named_variables.empty?

    { body_text_named_params: named_variables.each_with_index.map { |name, index| { param_name: name, example: @examples[index] } } }
  end
end
