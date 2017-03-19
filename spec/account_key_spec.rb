require 'acmesmith/account_key'

RSpec.describe Acmesmith::AccountKey do
  describe '#private_key' do
    let(:private_key) { OpenSSL::PKey::RSA.generate(2048) }

    context 'with passphrase' do
      let(:cipher) { OpenSSL::Cipher.new('aes-256-cbc') }
      let(:passphrase) { 'notasecret' }
      let(:exported_private_key) { private_key.export(cipher, passphrase) }
      let(:account_key) { described_class.new(exported_private_key) }

      context 'when correct passphrase is passed' do
        before do
          account_key.key_passphrase = passphrase
        end

        it 'returns private key' do
          expect(account_key.private_key.to_text).to eq(private_key.to_text)
        end
      end

      context 'when wrong passphrase is passed' do
        it 'raises RSAError' do
          expect { account_key.key_passphrase = 'wrong-passphrase' }.to raise_error(OpenSSL::PKey::RSAError)
        end
      end

      context "when passphrase isn't passed" do
        it 'raises PassphraseRequired' do
          expect { account_key.private_key }.to raise_error(Acmesmith::AccountKey::PassphraseRequired)
        end
      end
    end

    context 'without passphrase' do
      let(:exported_private_key) { private_key.export }
      let(:account_key) { described_class.new(exported_private_key) }

      context "when passphrase isn't passed" do
        it 'returns private key' do
          expect(account_key.private_key.to_text).to eq(private_key.to_text)
        end
      end

      context 'when passphrase is passed' do
        it 'raises error' do
          expect { account_key.key_passphrase = 'notasecret' }.to raise_error(/already given/)
        end
      end
    end
  end
end
