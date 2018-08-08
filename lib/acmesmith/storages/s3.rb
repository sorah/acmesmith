require 'aws-sdk-s3'

require 'acmesmith/storages/base'
require 'acmesmith/account_key'
require 'acmesmith/certificate'

module Acmesmith
  module Storages
    class S3 < Base
      def initialize(aws_access_key: nil, bucket:, prefix: nil, region:, use_kms: true, kms_key_id: nil, kms_key_id_account: nil, kms_key_id_certificate_key: nil, pkcs12_passphrase: nil, pkcs12_common_names: nil)
        @region = region
        @bucket = bucket
        @prefix = prefix
        if @prefix && !@prefix.end_with?('/')
          @prefix += '/'
        end

        @pkcs12_passphrase = pkcs12_passphrase
        @pkcs12_common_names = pkcs12_common_names

        @use_kms = use_kms
        @kms_key_id = kms_key_id
        @kms_key_id_account = kms_key_id_account
        @kms_key_id_certificate_key = kms_key_id_certificate_key

        @s3 = Aws::S3::Client.new({region: region, signature_version: 'v4'}.tap do |opt| 
          opt[:credentials] = Aws::Credentials.new(aws_access_key['access_key_id'], aws_access_key['secret_access_key'], aws_access_key['session_token']) if aws_access_key
        end)
      end

      attr_reader :region, :bucket, :prefix, :use_kms, :kms_key_id, :kms_key_id_account, :kms_key_id_certificate_key

      def get_account_key
        obj = @s3.get_object(bucket: bucket, key: account_key_key)
        AccountKey.new obj.body.read
      rescue Aws::S3::Errors::NoSuchKey
        raise NotExist.new("Account key doesn't exist")
      end

      def account_key_exist?
        begin
          get_account_key
        rescue NotExist
          return false
        else
          return true
        end
      end

      def put_account_key(key, passphrase = nil)
        raise AlreadyExist if account_key_exist?
        params = {
          bucket: bucket,
          key: account_key_key,
          body: key.export(passphrase),
          content_type: 'application/x-pem-file',
        }
        if use_kms
          params[:server_side_encryption] = 'aws:kms'
          key_id = kms_key_id_account || kms_key_id
          params[:ssekms_key_id] = key_id if key_id
        end

        @s3.put_object(params)
      end

      def put_certificate(cert, passphrase = nil, update_current: true)
        h = cert.export(passphrase)

        put = -> (key, body, kms, content_type = 'application/x-pem-file') do
          params = {
            bucket: bucket,
            key: key,
            body: body,
            content_type: content_type,
          }
          if kms
            params[:server_side_encryption] = 'aws:kms'
            key_id = kms_key_id_certificate_key || kms_key_id
            params[:ssekms_key_id] = key_id if key_id
          end
          @s3.put_object(params)
        end

        put.call certificate_key(cert.common_name, cert.version), "#{h[:certificate].rstrip}\n", false
        put.call chain_key(cert.common_name, cert.version), "#{h[:chain].rstrip}\n", false
        put.call fullchain_key(cert.common_name, cert.version), "#{h[:fullchain].rstrip}\n", false
        put.call private_key_key(cert.common_name, cert.version), "#{h[:private_key].rstrip}\n", true

        if generate_pkcs12?(cert)
          put.call pkcs12_key(cert.common_name, cert.version), "#{cert.pkcs12(@pkcs12_passphrase).to_der}\n", true, 'application/x-pkcs12'
        end

        if update_current
          @s3.put_object(
            bucket: bucket,
            key: certificate_current_key(cert.common_name),
            content_type: 'text/plain',
            body: cert.version,
          )
        end
      end

      def get_certificate(common_name, version: 'current')
        version = certificate_current(common_name) if version == 'current'

        certificate = @s3.get_object(bucket: bucket, key: certificate_key(common_name, version)).body.read
        chain = @s3.get_object(bucket: bucket, key: chain_key(common_name, version)).body.read
        private_key = @s3.get_object(bucket: bucket, key: private_key_key(common_name, version)).body.read
        Certificate.new(certificate, chain, private_key)
      rescue Aws::S3::Errors::NoSuchKey
        raise NotExist.new("Certificate for #{common_name.inspect} of #{version} version doesn't exist")
      end

      def list_certificates
        certs_prefix = "#{prefix}certs/"
        @s3.list_objects(
          bucket: bucket,
          delimiter: '/',
          prefix: certs_prefix,
        ).each.flat_map do |page|
          regexp = /\A#{Regexp.escape(certs_prefix)}/
          page.common_prefixes.map { |_| _.prefix.sub(regexp, '').sub(/\/.+\z/, '').sub(/\/\z/, '') }.uniq
        end
      end

      def list_certificate_versions(common_name)
        cert_ver_prefix = "#{prefix}certs/#{common_name}/"
        @s3.list_objects(
          bucket: bucket,
          delimiter: '/',
          prefix: cert_ver_prefix,
        ).each.flat_map do |page|
          regexp = /\A#{Regexp.escape(cert_ver_prefix)}/
          page.common_prefixes.map { |_| _.prefix.sub(regexp, '').sub(/\/.+\z/, '').sub(/\/\z/, '') }.uniq
        end.reject { |_| _ == 'current' }
      end

      def get_current_certificate_version(common_name)
        certificate_current(common_name)
      end

      private

      def account_key_key
        "#{prefix}account.pem"
      end

      def certificate_base_key(cn, ver)
        "#{prefix}certs/#{cn}/#{ver}"
      end

      def certificate_current_key(cn)
        certificate_base_key(cn, 'current')
      end

      def certificate_current(cn)
        @s3.get_object(
          bucket: bucket,
          key: certificate_current_key(cn),
        ).body.read.chomp
      rescue Aws::S3::Errors::NoSuchKey
        raise NotExist.new("Certificate for #{cn.inspect} of current version doesn't exist")
      end

      def certificate_key(cn, ver)
        "#{certificate_base_key(cn, ver)}/cert.pem"
      end

      def private_key_key(cn, ver)
        "#{certificate_base_key(cn, ver)}/key.pem"
      end

      def chain_key(cn, ver)
        "#{certificate_base_key(cn, ver)}/chain.pem"
      end

      def fullchain_key(cn, ver)
        "#{certificate_base_key(cn, ver)}/fullchain.pem"
      end

      def pkcs12_key(cn, ver)
        "#{certificate_base_key(cn, ver)}/cert.p12"
      end

      def generate_pkcs12?(cert)
        if @pkcs12_passphrase
          @pkcs12_common_names.nil? || @pkcs12_common_names.include?(cert.common_name)
        end
      end
    end
  end
end
