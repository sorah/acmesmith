require 'spec_helper'
require 'openssl'

require 'acmesmith/certificate'

RSpec.describe Acmesmith::Certificate do
  let(:given_certificate) { PEM_LEAF }
  let(:given_chain) { PEM_CHAIN }
  let(:given_private_key) { PRIVATE_KEY_PEM }
  let(:given_passphrase) { nil }

  subject(:certificate) do
    described_class.new(
      given_certificate,
      given_chain,
      given_private_key,
      given_passphrase,
    )
  end

  context "with String" do
    let(:given_certificate) { PEM_LEAF }
    let(:given_chain) { PEM_CHAIN }
    let(:given_private_key) { PRIVATE_KEY_PEM }

    it "works" do
      expect(certificate.certificate).to eq(LEAF)
      expect(certificate.chain).to eq(CHAIN)
      expect(certificate.private_key).to be_a(OpenSSL::PKey::RSA)
      expect(certificate.private_key.to_pem).to eq(PRIVATE_KEY.to_pem)
    end
  end

  context "with OpenSSL" do
    let(:given_certificate) { LEAF }
    let(:given_chain) { CHAIN }
    let(:given_private_key) { PRIVATE_KEY }

    it "works" do
      expect(certificate.certificate).to eq(LEAF)
      expect(certificate.chain).to eq(CHAIN)
      expect(certificate.private_key).to be_a(OpenSSL::PKey::RSA)
      expect(certificate.private_key.to_pem).to eq(PRIVATE_KEY.to_pem)
    end
  end

  describe "#private_key" do
    let(:given_private_key) { PRIVATE_KEY_PEM_ENCRYPTED }
    subject(:private_key) { certificate.private_key }

    context "when passphrase is not given" do
      let(:given_passphrase) { nil }

      it "raises error" do
        expect { subject }.to raise_error(Acmesmith::Certificate::PassphraseRequired)
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
        certificate.key_passphrase = PASSPHRASE
      end

      it "works" do
        expect(private_key).to be_a(OpenSSL::PKey::RSA)
        expect(private_key.to_pem).to eq(PRIVATE_KEY.to_pem)
      end
    end

    context "when passphrase is given twice" do
      let(:given_passphrase) { PASSPHRASE }
      it "raises error" do
        expect { certificate.key_passphrase = PASSPHRASE }.to raise_error(Acmesmith::Certificate::PrivateKeyDecrypted)
      end
    end
  end

  describe "#export" do
    let(:export_passphrase) { nil }
    subject(:export) { certificate.export(export_passphrase) }
    
    it "works" do
      expect(export).to be_a(Acmesmith::Certificate::CertificateExport)
      expect(export.certificate).to eq(PEM_LEAF)
      expect(export.chain).to eq(PEM_CHAIN)
      expect(export.fullchain).to eq(PEM_LEAF + PEM_CHAIN)
      expect(export.private_key).to eq(PRIVATE_KEY.to_pem)
    end

    context "with passphrase" do
      let(:export_passphrase) { PASSPHRASE }
      it "works" do
        expect(export).to be_a(Acmesmith::Certificate::CertificateExport)
        expect(export.certificate).to eq(PEM_LEAF)
        expect(export.chain).to eq(PEM_CHAIN)
        expect(export.fullchain).to eq(PEM_LEAF + PEM_CHAIN)
        expect(export.private_key).to be_a(String)
        expect { OpenSSL::PKey::RSA.new(export.private_key, '') }.to raise_error(OpenSSL::PKey::RSAError)
        expect(OpenSSL::PKey::RSA.new(export.private_key, export_passphrase).to_pem).to eq(PRIVATE_KEY.to_pem)
      end
    end
  end

  describe "#fullchain" do
    subject(:fullchain) { certificate.fullchain }
    it { is_expected.to eq("#{PEM_LEAF.chomp}\n#{PEM_CHAIN.chomp}\n") }
  end

  describe "#issuer_pems" do
    subject(:fullchain) { certificate.issuer_pems }
    it { is_expected.to eq(PEM_CHAIN) }
  end

  describe "#common_name" do
    subject(:fullchain) { certificate.common_name }
    it { is_expected.to eq("acmesmith-dev-20200512j.lo.sorah.jp") }
  end

  describe "#name" do
    subject(:fullchain) { certificate.name }
    it { is_expected.to eq("acmesmith-dev-20200512j.lo.sorah.jp") }
  end

  describe "#sans" do
    subject(:fullchain) { certificate.sans }
    it { is_expected.to eq(['acmesmith-dev-20200512j.lo.sorah.jp', 'acmesmith-dev-20200512l.lo.sorah.jp']) }
  end

  describe "#all_sans" do
    subject(:fullchain) { certificate.all_sans }
    it { is_expected.to eq(['DNS:acmesmith-dev-20200512j.lo.sorah.jp', 'DNS:acmesmith-dev-20200512l.lo.sorah.jp']) }
  end

  describe "#version" do
    subject(:fullchain) { certificate.version }
    it { is_expected.to eq("20200511-192010_fa5aa9032181a09b2cebec848658eb2c5f79") }
  end
end
