require 'acmesmith/authorization_service'
require 'acmesmith/certificate'
require 'acmesmith/certificate_retrieving_service'

module Acmesmith
  class OrderingService
    class NotCompleted < StandardError; end

    # @param acme [Acme::Client] ACME client
    # @param common_name [String] Common Name for a ordering certificate
    # @param identifiers [Array<String>] Array of domain names for a ordering certificate. common_name has to be explicitly included in this argument.
    # @param private_key [OpenSSL::PKey::PKey] Private key
    # @param challenge_responder_rules [Array<Acmesmith::Config::ChallengeResponderRule>] responders
    # @param chain_preferences [Array<Acmesmith::Config::ChainPreference>] chain_preferences
    # @param not_before [Time]
    # @param not_after [Time]
    def initialize(acme:, common_name:, identifiers:, private_key:, challenge_responder_rules:, chain_preferences:, not_before: nil, not_after: nil)
      @acme = acme
      @common_name = common_name
      @identifiers = identifiers
      @private_key = private_key
      @challenge_responder_rules = challenge_responder_rules
      @chain_preferences = chain_preferences
      @not_before = not_before
      @not_after = not_after
    end

    attr_reader :acme, :common_name, :identifiers, :private_key, :challenge_responder_rules, :chain_preferences, :not_before, :not_after

    def perform!
      puts "=> Ordering a certificate for the following identifiers:"
      puts
      puts " * CN:  #{common_name}"
      sans.each do |san|
        puts " * SAN: #{san}"
      end

      puts
      puts "=> Placing an order"
      @order = acme.new_order(identifiers: identifiers, not_before: not_before, not_after: not_after)
      puts " * URL: #{order.url}"

      ensure_authorization()

      finalize_order()
      wait_order_for_complete()

      @certificate = Certificate.by_issuance(pem_chain, csr, name: common_name)

      puts
      puts "=> Certificate issued"
      nil
    end

    def ensure_authorization
      return if order.authorizations.empty? || order.status == 'ready'
      puts "=> Looking for required domain authorizations"
      puts
      order.authorizations.map(&:domain).each do |domain|
        puts " * #{domain}"
      end
      puts

      AuthorizationService.new(challenge_responder_rules, order.authorizations).perform!
    end

    def finalize_order
      puts
      puts "=> Finalizing the order"
      puts
      puts csr.csr.to_pem
      puts

      print " * Requesting..."
      order.finalize(csr: csr)
      puts" [ ok ]"
    end

    def wait_order_for_complete
      while %w(ready processing).include?(order.status)
        order.reload()
        puts " * Waiting for complete: status=#{order.status}"
        sleep 2
      end
    end

    # @return String
    def pem_chain
      url = order.certificate_url or raise NotCompleted, "not completed yet"
      CertificateRetrievingService.new(acme, common_name, url, chain_preferences: chain_preferences).pem_chain
    end

    def certificate
      @certificate or raise NotCompleted, "not completed yet"
    end

    # @return Acme::Client::Resources::Order[]
    def order
      @order or raise "BUG: order not yet generated"
    end

    # @return [Array<String>]
    def sans
      identifiers[1..-1]
    end

    # @return [Acme::Client::CertificateRequest]
    def csr
      @csr ||= Acme::Client::CertificateRequest.new(subject: { common_name: common_name }, names: sans, private_key: private_key)
    end
  end
end
