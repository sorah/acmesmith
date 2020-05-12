require 'spec_helper'
require 'openssl'

require 'acmesmith/account_key'

RSpec.describe Acmesmith::AccountKey do
  let(:given_private_key) { PRIVATE_KEY_PEM }
  let(:given_passphrase) { nil }

  subject(:account_key) do
    described_class.new(
      given_private_key,
      given_passphrase,
    )
  end

  context "with String" do
    let(:given_private_key) { PRIVATE_KEY_PEM }

    it "works" do
      expect(account_key.private_key).to be_a(OpenSSL::PKey::RSA)
      expect(account_key.private_key.to_pem).to eq(PRIVATE_KEY.to_pem)
    end
  end

  context "with OpenSSL" do
    let(:given_private_key) { PRIVATE_KEY }

    it "works" do
      expect(account_key.private_key).to be_a(OpenSSL::PKey::RSA)
      expect(account_key.private_key.to_pem).to eq(PRIVATE_KEY.to_pem)
    end
  end

  describe "#private_key" do
    let(:given_private_key) { PRIVATE_KEY_PEM_ENCRYPTED }
    subject(:private_key) { account_key.private_key }

    context "when passphrase is not given" do
      let(:given_passphrase) { nil }

      it "raises error" do
        expect { subject }.to raise_error(Acmesmith::AccountKey::PassphraseRequired)
      end
    end

    context "when passphrase is given at initialize" do
      let(:given_passphrase) { PASSPHRASE }
      it "works" do
        expect(private_key).to be_a(OpenSSL::PKey::RSA)
        expect(private_key.to_pem).to eq(PRIVATE_KEY.to_pem)
      end
    end

    context "when passphrase is given later" do
      let(:given_passphrase) { nil }

      before do
        account_key.key_passphrase = PASSPHRASE
      end

      it "works" do
        expect(private_key).to be_a(OpenSSL::PKey::RSA)
        expect(private_key.to_pem).to eq(PRIVATE_KEY.to_pem)
      end
    end

    context "when passphrase is given twice" do
      let(:given_passphrase) { PASSPHRASE }
      it "raises error" do
        expect { account_key.key_passphrase = PASSPHRASE }.to raise_error(Acmesmith::AccountKey::PrivateKeyDecrypted)
      end
    end
  end

  describe "#export" do
    let(:export_passphrase) { nil }
    subject(:export) { account_key.export(export_passphrase) }
    
    it "works" do
      expect(export).to eq(PRIVATE_KEY.to_pem)
    end

    context "with passphrase" do
      let(:export_passphrase) { PASSPHRASE }
      it "works" do
        expect(export).to be_a(String)
        expect { OpenSSL::PKey::RSA.new(export, '') }.to raise_error(OpenSSL::PKey::RSAError)
        expect(OpenSSL::PKey::RSA.new(export, export_passphrase).to_pem).to eq(PRIVATE_KEY.to_pem)
      end
    end
  end
end
