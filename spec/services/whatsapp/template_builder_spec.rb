require 'rails_helper'

describe Whatsapp::TemplateBuilder do
  def build(overrides = {})
    described_class.new(name: 'boas_vindas', language: 'pt_BR', category: 'UTILITY',
                        body: 'Olá, tudo bem?', examples: [], **overrides).build
  end

  describe '#build' do
    it 'builds a payload with a BODY component when there are no variables' do
      expect(build).to eq(
        name: 'boas_vindas',
        language: 'pt_BR',
        category: 'UTILITY',
        components: [{ type: 'BODY', text: 'Olá, tudo bem?' }]
      )
    end

    it 'attaches example.body_text when the body has variables' do
      payload = build(body: 'Olá {{1}}, pedido {{2}} enviado.', examples: %w[Pedro 1234])

      expect(payload[:components]).to eq(
        [{ type: 'BODY',
           text: 'Olá {{1}}, pedido {{2}} enviado.',
           example: { body_text: [%w[Pedro 1234]] } }]
      )
    end

    it 'accepts a variable used more than once, counting it once' do
      payload = build(body: 'Oi {{1}}, confirma {{1}}?', examples: ['Ana'])

      expect(payload[:components].first[:example]).to eq(body_text: [['Ana']])
    end

    it 'rejects a variable sequence with a hole' do
      expect { build(body: 'Oi {{1}} e {{3}}', examples: %w[a b]) }
        .to raise_error(described_class::InvalidTemplateError, /sequence/i)
    end

    it 'rejects a sequence that does not start at 1' do
      expect { build(body: 'Oi {{2}}', examples: ['a']) }
        .to raise_error(described_class::InvalidTemplateError, /sequence/i)
    end

    it 'rejects when the example count does not match the variable count' do
      expect { build(body: 'Oi {{1}} e {{2}}', examples: ['só um']) }
        .to raise_error(described_class::InvalidTemplateError, /example/i)
    end

    it 'rejects a blank example' do
      expect { build(body: 'Oi {{1}}', examples: ['  ']) }
        .to raise_error(described_class::InvalidTemplateError, /example/i)
    end

    it 'rejects a name that is not lowercase alphanumeric or underscore' do
      expect { build(name: 'Boas Vindas') }
        .to raise_error(described_class::InvalidTemplateError, /name/i)
    end

    it 'rejects a name longer than 512 characters' do
      expect { build(name: "a#{'b' * 512}") }
        .to raise_error(described_class::InvalidTemplateError, /name/i)
    end

    it 'rejects a category Meta does not accept' do
      expect { build(category: 'PROMOTIONAL') }
        .to raise_error(described_class::InvalidTemplateError, /category/i)
    end

    # AUTHENTICATION needs an OTP BUTTONS component plus a security BODY/FOOTER
    # this builder does not emit, so Meta would reject every submission anyway.
    it 'rejects AUTHENTICATION, which it cannot build a valid payload for' do
      expect(described_class::CATEGORIES).not_to include('AUTHENTICATION')
      expect { build(category: 'AUTHENTICATION') }
        .to raise_error(described_class::InvalidTemplateError, /category/i)
    end

    it 'rejects a blank body' do
      expect { build(body: '   ') }
        .to raise_error(described_class::InvalidTemplateError, /body/i)
    end

    it 'rejects a blank language' do
      expect { build(language: '') }
        .to raise_error(described_class::InvalidTemplateError, /language/i)
    end
  end
end
