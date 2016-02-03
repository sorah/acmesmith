require 'pathname'

require 'acmesmith/storages/base'
require 'acmesmith/account_key'
require 'acmesmith/certificate'

module Acmesmith
  module Storages
    class Filesystem < Base
      def initialize(path:)
        @path = Pathname(path)
      end

      attr_reader :path

      def get_account_key
        raise NotExist.new("Account key doesn't exist") unless account_key_path.exist?
        AccountKey.new account_key_path.read
      end

      def put_account_key(key, passphrase = nil)
        raise AlreadyExist if account_key_path.exist?
        File.write account_key_path.to_s, key.export(passphrase), 0, perm: 0600
      end

      def put_certificate(cert, passphrase = nil, update_current: true)
        h = cert.export(passphrase)
        certificate_base_path(cert.common_name, cert.version).mkpath
        File.write certificate_path(cert.common_name, cert.version), "#{h[:certificate].rstrip}\n"
        File.write chain_path(cert.common_name, cert.version), "#{h[:chain].rstrip}\n"
        File.write fullchain_path(cert.common_name, cert.version), "#{h[:fullchain].rstrip}\n"
        File.write private_key_path(cert.common_name, cert.version), "#{h[:private_key].rstrip}\n", 0, perm: 0600
        if update_current
          File.symlink(cert.version, certificate_base_path(cert.common_name, 'current.new'))
          File.rename(certificate_base_path(cert.common_name, 'current.new'), certificate_base_path(cert.common_name, 'current'))
        end
      end

      def get_certificate(common_name, version: 'current')
        raise NotExist.new("Certificate for #{common_name.inspect} of #{version} version doesn't exist") unless certificate_base_path(common_name, version).exist?
        certificate = certificate_path(common_name, version).read
        chain = chain_path(common_name, version).read
        private_key = private_key_path(common_name, version).read
        Certificate.new(certificate, chain, private_key)
      end

      def list_certificates
        Dir[path.join('certs', '*').to_s].map { |_| File.basename(_) }
      end

      def list_certificate_versions(common_name)
        Dir[path.join('certs', common_name, '*').to_s].map { |_| File.basename(_) }.reject { |_| _ == 'current' }
      end

      def get_current_certificate_version(common_name)
        path.join('certs', common_name, 'current').readlink
      end

      private

      def account_key_path
        path.join('account.pem')
      end

      def certificate_base_path(cn, ver)
        path.join('certs', cn, ver)
      end

      def certificate_path(cn, ver)
        certificate_base_path(cn, ver).join('cert.pem')
      end

      def private_key_path(cn, ver)
        certificate_base_path(cn, ver).join('key.pem')
      end

      def chain_path(cn, ver)
        certificate_base_path(cn, ver).join('chain.pem')
      end

      def fullchain_path(cn, ver)
        certificate_base_path(cn, ver).join('fullchain.pem')
      end
    end
  end
end
