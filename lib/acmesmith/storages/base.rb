module Acmesmith
  module Storages
    class Base
      class NotExist < StandardError; end
      class AlreadyExist < StandardError; end

      def initialize()
      end

      def get_account_key
        raise NotImplementedError
      end

      def put_account_key(key, passphrase = nil)
        raise NotImplementedError
      end

      def put_certificate(cert, passphrase = nil, update_current: true)
        raise NotImplementedError
      end

      def get_certificate(common_name, version: 'current')
        raise NotImplementedError
      end

      def list_certificates
        raise NotImplementedError
      end

      def list_certificate_versions(common_name)
        raise NotImplementedError
      end

      def get_current_certificate_version(common_name)
        raise NotImplementedError
      end
    end
  end
end
