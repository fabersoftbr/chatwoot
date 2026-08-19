require 'rails_helper'

describe EmailHelper do
  describe '#normalize_email_with_plus_addressing' do
    context 'when email is passed' do
      it 'normalise if plus addressing is present' do
        expect(helper.normalize_email_with_plus_addressing('john+test@acme.inc')).to eq 'john@acme.inc'
      end

      it 'returns original if plus addressing is not present' do
        expect(helper.normalize_email_with_plus_addressing('john@acme.inc')).to eq 'john@acme.inc'
      end

      it 'returns downcased version of email' do
        expect(helper.normalize_email_with_plus_addressing('JoHn+AAsdfss@acme.inc')).to eq 'john@acme.inc'
      end
    end
  end

  describe '#generic_email_domain?' do
    it 'returns true for free mailbox providers' do
      expect(helper.generic_email_domain?('john@gmail.com')).to be(true)
      expect(helper.generic_email_domain?('john@hotmail.com.br')).to be(true)
      expect(helper.generic_email_domain?('john@proton.me')).to be(true)
    end

    it 'returns false for company domains' do
      expect(helper.generic_email_domain?('john@acme.com')).to be(false)
      expect(helper.generic_email_domain?('john@stripe.com')).to be(false)
    end

    it 'ignores case and surrounding whitespace' do
      expect(helper.generic_email_domain?('john@GMAIL.com')).to be(true)
      expect(helper.generic_email_domain?('john@Hotmail.com.BR ')).to be(true)
    end

    it 'does not match a company domain that merely ends with a provider domain' do
      expect(helper.generic_email_domain?('john@notgmail.com')).to be(false)
      expect(helper.generic_email_domain?('john@mail.gmail.com')).to be(false)
    end

    it 'returns false when the address has no domain' do
      expect(helper.generic_email_domain?('')).to be(false)
      expect(helper.generic_email_domain?(nil)).to be(false)
    end
  end
end
