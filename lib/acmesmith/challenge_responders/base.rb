module Acmesmith
  module ChallengeResponders
    class Base
      # @param type [String] ACME challenge type (dns-01, http-01, ...)
      # @return [true, false] true when given challenge type is supported
      def support?(type)
        raise NotImplementedError
      end

      # @param domain [String] target FQDN for a ACME authorization challenge
      # @return [true, false] true when a responder is able to challenge against given domain name
      def applicable?(domain)
        true
      end

      # @return [true, false] true when implements #respond_all, #cleanup_all
      def cap_respond_all?
        false
      end

      def initialize()
      end

      # Respond to the given challenges (1 or more).
      # @param domain_and_challenges [Array<(String, Acme::Client::Resources::Challenges::Base)>] array of tuple of domain name and ACME challenge
      def respond_all(*domain_and_challenges)
        if cap_respond_all?
          raise NotImplementedError
        else
          domain_and_challenges.each do |dc|
            respond(*dc)
          end
        end
      end

      # Clean up responses for the given challenges (1 or more).
      # @param domain_and_challenges [Array<(String, Acme::Client::Resources::Challenges::Base)>] array of tuple of domain name and ACME challenge
      def cleanup_all(*domain_and_challenges)
        if cap_respond_all?
          raise NotImplementedError
        else
          domain_and_challenges.each do |dc|
            cleanup(*dc)
          end
        end
      end

      # If cap_respond_all? is true, you don't need to implement this method.
      def respond(domain, challenge)
        if cap_respond_all?
          respond_all([domain, challenge])
        else
          raise NotImplementedError
        end
      end

      # If cap_respond_all? is true, you don't need to implement this method.
      def cleanup(domain, challenge)
        if cap_respond_all?
          cleanup_all([domain, challenge])
        else
          raise NotImplementedError
        end
      end
    end
  end
end
