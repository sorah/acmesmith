require 'spec_helper'
require 'aws-sdk-s3'
require 'stringio'

require 'acmesmith/account_key'
require 'acmesmith/certificate'
require 'acmesmith/storages/base'
require 'acmesmith/storages/s3'

RSpec.describe Acmesmith::Storages::S3 do
  let(:aws_access_key) { nil }
    let(:use_kms) { false }
    let(:kms_key_id) { nil }
    let(:kms_key_id_account) { nil }
    let(:kms_key_id_certificate_key) { nil }
    let(:pkcs12_passphrase) { nil }
    let(:pkcs12_common_names) { nil }


  let(:s3) { double(:s3) }

  subject(:storage) do
    described_class.new(
      aws_access_key: aws_access_key,
      bucket: 'bucket',
      prefix: 'prefix/',
      region: 'dummy',
      use_kms: use_kms,
      kms_key_id: kms_key_id,
      kms_key_id_account: kms_key_id_account,
      kms_key_id_certificate_key: kms_key_id_certificate_key,
      pkcs12_passphrase: pkcs12_passphrase,
      pkcs12_common_names: pkcs12_common_names,
    )
  end

  describe ".new" do
    context "with no parameters" do
      before do
        expect(Aws::S3::Client).to receive(:new).with(region: 'dummy').and_return(s3)
      end

      it "uses SDK default" do
        storage
      end
    end

    context "with aws_access_key" do
      let(:aws_access_key) { {'access_key_id' => 'a', 'secret_access_key' => 'b', 'session_token' => 'c'} }

      before do
        akia = double(:akia)
        allow(Aws::Credentials).to receive(:new).with('a', 'b', 'c').and_return(akia)
        expect(Aws::S3::Client).to receive(:new).with(
          region: 'dummy',
          credentials: akia,
        ).and_return(s3)
      end

      it "uses credentials" do
        storage
      end
    end
  end

  context do
    before do
      expect(Aws::S3::Client).to receive(:new).with(region: 'dummy').and_return(s3)
    end

    describe "#get_account_key" do
      subject(:account_key) { storage.get_account_key }

      context "when exists" do
        before do
          expect(s3).to receive(:get_object)
            .with(bucket: 'bucket', key: 'prefix/account.pem')
            .and_return(double(:obj, body: StringIO.new(PRIVATE_KEY_PEM)))
        end

        it "returns a key" do
          expect(account_key).to be_a(Acmesmith::AccountKey)
          expect(account_key.private_key.to_pem).to eq(PRIVATE_KEY_PEM)
        end
      end

      context "when not exists" do
        before do
          expect(s3).to receive(:get_object)
            .with(bucket: 'bucket', key: 'prefix/account.pem')
            .and_raise(Aws::S3::Errors::NoSuchKey.new('',''))
        end

        it "returns a key" do
          expect { account_key }.to raise_error(Acmesmith::Storages::Base::NotExist)
        end
      end
    end

    describe "#put_account_key" do
      subject(:action) { storage.put_account_key(account_key, PASSPHRASE) }
      let(:account_key) { double(:account_key) }
      let(:use_kms) { false }

      context "when key doesn't exists" do

        before do
          expect(s3).to receive(:get_object)
            .with(bucket: 'bucket', key: 'prefix/account.pem')
            .and_raise(Aws::S3::Errors::NoSuchKey.new('',''))

          expect(account_key).to receive(:export).with(PASSPHRASE).and_return(PRIVATE_KEY_PEM_ENCRYPTED)

          kms_options = use_kms ? {server_side_encryption: 'aws:kms'} : {}
          kms_options&.merge!(ssekms_key_id: kms_key_id || kms_key_id_account) if kms_key_id || kms_key_id_account
          expect(s3).to receive(:put_object)
            .with(
              {
                bucket: 'bucket',
                key: 'prefix/account.pem',
                body: PRIVATE_KEY_PEM_ENCRYPTED,
                content_type: 'application/x-pem-file',
              }.merge(kms_options),
            )
            .and_return(nil)
        end


        it "puts a key" do
          action
        end

        context "with kms" do
          let(:use_kms) { true }

          it "puts a key" do
            action
          end

          context "with kms_key_id_acocunt" do
            let(:kms_key_id_account) { 'kmskeyidAccount' }

            it "puts a key" do
              action
            end
          end

          context "with kms_key_id" do
            let(:kms_key_id) { 'kmskeyid' }

            it "puts a key" do
              action
            end
          end
        end
      end

      context "when key exists" do
        before do
          expect(s3).to receive(:get_object)
            .with(bucket: 'bucket', key: 'prefix/account.pem')
            .and_return(double(:obj, body: StringIO.new(PRIVATE_KEY_PEM)))
        end

        it "raises error" do
          expect { action }.to raise_error(Acmesmith::Storages::Base::AlreadyExist)
        end
      end
    end

    describe "#get_certificate" do
      let(:common_name) { 'common-name' }
      let(:version) { 'version' }

      subject(:certificate) { storage.get_certificate(common_name, version: version) }

      context "when certificate exists" do
        before do
          expect(s3).to receive(:get_object)
            .with(bucket: 'bucket', key: "prefix/certs/common-name/#{version}/cert.pem")
            .and_return(double(:obj, body: StringIO.new(PEM_LEAF)))
          expect(s3).to receive(:get_object)
            .with(bucket: 'bucket', key: "prefix/certs/common-name/#{version}/key.pem")
            .and_return(double(:obj, body: StringIO.new(PRIVATE_KEY_PEM)))
          expect(s3).to receive(:get_object)
            .with(bucket: 'bucket', key: "prefix/certs/common-name/#{version}/chain.pem")
            .and_return(double(:obj, body: StringIO.new(PEM_CHAIN)))
        end

        it "loads certificate" do
          expect(certificate).to be_a(Acmesmith::Certificate)
          expect(certificate.certificate.to_pem).to eq(PEM_LEAF)
          expect(certificate.private_key.to_pem).to eq(PRIVATE_KEY_PEM)
          expect(certificate.issuer_pems).to eq(PEM_CHAIN)
        end

        context "with current version" do
          subject(:certificate) { storage.get_certificate(common_name, version: 'current') }

          before do
            expect(s3).to receive(:get_object)
              .with(bucket: 'bucket', key: "prefix/certs/common-name/current")
              .and_return(double(:obj, body: StringIO.new(version)))
          end

          it "loads certificate" do
            expect(certificate).to be_a(Acmesmith::Certificate)
            expect(certificate.certificate.to_pem).to eq(PEM_LEAF)
            expect(certificate.private_key.to_pem).to eq(PRIVATE_KEY_PEM)
            expect(certificate.issuer_pems).to eq(PEM_CHAIN)
          end
        end
      end

      context "when ceritificate not exists" do
        before do
          expect(s3).to receive(:get_object)
            .with(bucket: 'bucket', key: 'prefix/certs/common-name/version/cert.pem')
            .and_raise(Aws::S3::Errors::NoSuchKey.new('',''))
        end

        it "raises error" do
          expect { certificate }.to raise_error(Acmesmith::Storages::Base::NotExist)
        end
      end

      context "when current version not exists" do
        subject(:certificate) { storage.get_certificate(common_name, version: 'current') }

        before do
          expect(s3).to receive(:get_object)
            .with(bucket: 'bucket', key: 'prefix/certs/common-name/current')
            .and_raise(Aws::S3::Errors::NoSuchKey.new('',''))
        end

        it "raises error" do
          expect { certificate }.to raise_error(Acmesmith::Storages::Base::NotExist)
        end
      end
    end

    describe "#put_certificate" do
      let(:certificate) { double(:certificate, common_name: 'common-name', version: 'version') }
      let(:update_current) { false }

      subject(:action) { storage.put_certificate(certificate, PASSPHRASE, update_current: update_current) }
      
      before do
        allow(certificate).to receive(:export).with(PASSPHRASE).and_return(Acmesmith::Certificate::CertificateExport.new(
          certificate: 'certificate',
          chain: 'chain',
          fullchain: 'fullchain',
          private_key: 'private_key',
        ))
        allow(certificate).to receive(:pkcs12).with('pkcs12').and_return(double(:pkcs12, to_der: "pkcs12-der"))

        expect(s3).to receive(:put_object)
          .with(bucket: 'bucket', key: 'prefix/certs/common-name/version/cert.pem', body: "certificate\n", content_type: 'application/x-pem-file')
          .and_return(nil)
        expect(s3).to receive(:put_object)
          .with(bucket: 'bucket', key: 'prefix/certs/common-name/version/chain.pem', body: "chain\n", content_type: 'application/x-pem-file')
          .and_return(nil)
        expect(s3).to receive(:put_object)
          .with(bucket: 'bucket', key: 'prefix/certs/common-name/version/fullchain.pem', body: "fullchain\n", content_type: 'application/x-pem-file')
          .and_return(nil)

        kms_options = use_kms ? {server_side_encryption: 'aws:kms'} : {}
        kms_options&.merge!(ssekms_key_id: kms_key_id || kms_key_id_certificate_key) if kms_key_id || kms_key_id_certificate_key
        expect(s3).to receive(:put_object)
          .with(
            {
              bucket: 'bucket',
              key: 'prefix/certs/common-name/version/key.pem',
              body: "private_key\n",
              content_type: 'application/x-pem-file',
            }.merge(kms_options),
          )
          .and_return(nil)
      end

      it "stores certificate" do
        action
      end

      context "with update_current" do
        let(:update_current) { true }

        before do
          expect(s3).to receive(:put_object)
            .with(bucket: 'bucket', key: 'prefix/certs/common-name/current', body: 'version', content_type: 'text/plain')
            .and_return(nil)
        end

        it "stores certificate" do
          action
        end
      end

      context "with pkcs12" do
        let(:pkcs12_passphrase) { 'pkcs12' }

        context "without pkcs12_common_names" do
          before do
            expect(s3).to receive(:put_object)
              .with(bucket: 'bucket', key: 'prefix/certs/common-name/version/cert.p12', body: "pkcs12-der\n", content_type: 'application/x-pkcs12')
              .and_return(nil)
          end

          it "stores certificate" do
            action
          end
        end

        context "with pkcs12_common_names (match)" do
          let(:pkcs12_common_names) { ['common-name'] }

          before do
            expect(s3).to receive(:put_object)
              .with(bucket: 'bucket', key: 'prefix/certs/common-name/version/cert.p12', body: "pkcs12-der\n", content_type: 'application/x-pkcs12')
              .and_return(nil)
          end

          it "stores certificate" do
            action
          end
        end

        context "with pkcs12_common_names (not match)" do
          let(:pkcs12_common_names) { ['common-name2'] }

          it "stores certificate" do
            action
          end
        end
      end

      context "with kms" do
        let(:use_kms) { true }

        it "puts a key" do
          action
        end

        context "with pkcs12" do
          let(:pkcs12_passphrase) { 'pkcs12' }

          before do
            expect(s3).to receive(:put_object)
              .with(
                bucket: 'bucket', key: 'prefix/certs/common-name/version/cert.p12', body: "pkcs12-der\n", content_type: 'application/x-pkcs12',
                server_side_encryption: 'aws:kms',
              )
              .and_return(nil)
          end

          it "stores certificate" do
            action
          end
        end

        context "with kms_key_id_certificate_key" do
          let(:kms_key_id_account) { 'kmskeyidCertificateKey' }

          it "puts a certificate" do
            action
          end
        end

        context "with kms_key_id" do
          let(:kms_key_id) { 'kmskeyid' }

          it "puts a certificate" do
            action
          end
        end
      end
    end

    describe "#get_current_certificate_version" do
      let(:common_name) { 'common-name' }

      subject(:version) { storage.get_current_certificate_version(common_name) }

      context "when current exists" do
        before do
          expect(s3).to receive(:get_object)
            .with(bucket: 'bucket', key: "prefix/certs/common-name/current")
            .and_return(double(:obj, body: StringIO.new('version')))
        end

        it "returns a version" do
          expect(version).to eq('version')
        end
      end

      context "when current version not exists" do
        before do
          expect(s3).to receive(:get_object)
            .with(bucket: 'bucket', key: 'prefix/certs/common-name/current')
            .and_raise(Aws::S3::Errors::NoSuchKey.new('',''))
        end

        it "raises error" do
          expect { version}.to raise_error(Acmesmith::Storages::Base::NotExist)
        end
      end
    end

    describe "#list_certificates" do
      subject(:list) { storage.list_certificates() }
      before do
        expect(s3).to receive(:list_objects).with(bucket: 'bucket', delimiter: '/', prefix: 'prefix/certs/')
          .and_return([Aws::S3::Types::ListObjectsOutput.new(
            common_prefixes: %w(
              prefix/certs/cert-a/
              prefix/certs/cert-b/
              prefix/certs/cert-c/
            ).map { |pr| Aws::S3::Types::CommonPrefix.new(prefix: pr) },
          )])
      end

      it "returns a list" do
        expect(list).to eq(%w(cert-a cert-b cert-c))
      end
    end

    describe "#list_certificate_versions" do
      subject(:list) { storage.list_certificate_versions('common-name') }
      before do
        expect(s3).to receive(:list_objects).with(bucket: 'bucket', delimiter: '/', prefix: 'prefix/certs/common-name/')
          .and_return([Aws::S3::Types::ListObjectsOutput.new(
            common_prefixes: %w(
              prefix/certs/common-name/a/
              prefix/certs/common-name/b/
              prefix/certs/common-name/c/
            ).map { |pr| Aws::S3::Types::CommonPrefix.new(prefix: pr) },
          )])
      end

      it "returns a list" do
        expect(list).to eq(%w(a b c))
      end
    end
  end
end
