require 'acme-client'

module Acmesmith
  class AcmeClient
    # @param account_key [Acmesmith::AccountKey]
    # @param endpoint [String]
    def initialize(account_key, endpoint)
      @acme = Acme::Client.new(private_key: account_key.private_key, endpoint: endpoint)
    end

    # @param contact [String]
    def register(contact)
      retry_once_on_bad_nonce do
        @acme.register(contact: contact)
      end
    end

    # @param domain [String]
    def authorize(domain)
      retry_once_on_bad_nonce do
        @acme.authorize(domain: domain)
      end
    end

    # @param csr [Acme::Client::CertificateRequest]
    def new_certificate(csr)
      retry_once_on_bad_nonce do
        @acme.new_certificate(csr)
      end
    end

    # @param challenge [Acme::Client::Resources::Challenges::Base]
    def request_verification(challenge)
      retry_once_on_bad_nonce do
        challenge.request_verification
      end
    end

    # @param challenge [Acme::Client::Resources::Challenges::Base]
    def verify_status(challenge)
      retry_once_on_bad_nonce do
        challenge.verify_status
      end
    end

    private

    def retry_once_on_bad_nonce(&block)
      retried = false
      begin
        block.call
      rescue Acme::Client::Error::BadNonce => e
        # Let's Encrypt returns badNonce error when the client sends too-old
        # nonce. So retry the request once.
        if retried
          raise e
        else
          retried = true
          retry
        end
      end
    end
  end
end
