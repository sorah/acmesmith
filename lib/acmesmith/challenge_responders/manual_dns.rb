require 'acmesmith/challenge_responders/base'

module Acmesmith
  module ChallengeResponders
    class ManualDns < Base
      class HostedZoneNotFound < StandardError; end
      class AmbiguousHostedZones < StandardError; end

      def support?(type)
        # Acme::Client::Resources::Challenges::DNS01
        type == 'dns-01'
      end

      def initialize(options={})
      end

      def respond(domain, challenge)
        puts "=> Responding challenge dns-01 for #{domain}"
        puts

        domain = canonical_fqdn(domain)
        record_name = "#{challenge.record_name}.#{domain}"
        record_type = challenge.record_type
        record_content = "\"#{challenge.record_content}\""

        puts "#{record_name}. 5 IN #{record_type} #{record_content}"

        puts "(Hit enter when DNS record get ready)"
        $stdin.gets
      end

      def cleanup(domain, challenge)
        domain = canonical_fqdn(domain)
        record_name = "#{challenge.record_name}.#{domain}"
        puts "=> It's now okay to delete DNS record for #{record_name}"
      end

      private

      def canonical_fqdn(domain)
        "#{domain}.".sub(/\.+$/, '')
      end
    end
  end
end
