module Acmesmith
  module Storages
    class Base
      class NotExist < StandardError; end
      class AlreadyExist < StandardError; end

      def initialize()
      end

      # @return [Acmesmith::AccountKey]
      def get_account_key
        raise NotImplementedError
      end

      # @param key [Acmesmith::AccountKey]
      # @param passphrase [String, nil]
      def put_account_key(key, passphrase = nil)
        raise NotImplementedError
      end

      # @param cert [Acmesmith::Certificate]
      # @param passphrase [String, nil]
      # @param update_current [true, false]
      def put_certificate(cert, passphrase = nil, update_current: true)
        raise NotImplementedError
      end

      # @param name [String]
      # @param version [String, nil]
      # @return [Acmesmith::Certificate]
      def get_certificate(name, version: 'current')
        raise NotImplementedError
      end

      # @param name [String]
      # @return [String] array of certificate names
      def list_certificates
        raise NotImplementedError
      end

      # @param name [String]
      # @return [String] array of versions
      def list_certificate_versions(name)
        raise NotImplementedError
      end

      # @param name [String]
      # @return [String] current version
      def get_current_certificate_version(name)
        raise NotImplementedError
      end
    end
  end
end
