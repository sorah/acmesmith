require 'acmesmith/challenge_responders/base'

require 'aws-sdk-route53'

module Acmesmith
  module ChallengeResponders
    class Route53 < Base
      class HostedZoneNotFound < StandardError; end
      class AmbiguousHostedZones < StandardError; end

      def support?(type)
        # Acme::Client::Resources::Challenges::DNS01
        type == 'dns-01'
      end

      def initialize(aws_access_key: nil, hosted_zone_map: {})
        @route53 = Aws::Route53::Client.new({region: 'us-east-1'}.tap do |opt| 
          opt[:credentials] = Aws::Credentials.new(aws_access_key['access_key_id'], aws_access_key['secret_access_key'], aws_access_key['session_token']) if aws_access_key
        end)
        @hosted_zone_map = hosted_zone_map
        @hosted_zone_cache = {}
      end

      def respond(domain, challenge)
        puts "=> Responding challenge dns-01 for #{domain} in #{self.class.name}"

        domain = canonical_fqdn(domain)
        record_name = "#{challenge.record_name}.#{domain}"
        record_type = challenge.record_type
        record_content = "\"#{challenge.record_content}\""
        zone_id = find_hosted_zone(domain)

        puts " * UPSERT: #{record_type} #{record_name.inspect}, #{record_content.inspect} on #{zone_id}"
        change_resp =  @route53.change_resource_record_sets(
          hosted_zone_id: zone_id, # required
          change_batch: { # required
            comment: "ACME challenge response",
            changes: [
              {
                action: "UPSERT",
                resource_record_set: { # required
                  name: record_name,  # required
                  type: record_type,
                  ttl: 5,
                  resource_records: [
                    value: record_content
                  ],
                },
              },
            ],
          },
        )

        change_id = change_resp.change_info.id
        puts " * requested change: #{change_id}"

        puts "=> Waiting for change"
        while (resp = @route53.get_change(id: change_id)).change_info.status != 'INSYNC'
          puts " * change #{change_id.inspect} is still #{resp.change_info.status.inspect} ..."
          sleep 5
        end

        puts " * synced!"
      end

      def cleanup(domain, challenge)
        puts "=> Cleaning up challenge dns-01 for #{domain} in #{self.class.name}"

        domain = canonical_fqdn(domain)
        record_name = "#{challenge.record_name}.#{domain}"
        record_type = challenge.record_type
        record_content = "\"#{challenge.record_content}\""
        zone_id = find_hosted_zone(domain)

        puts " * DELETE: #{record_type} #{record_name.inspect}, #{record_content.inspect} on #{zone_id}"
        change_resp =  @route53.change_resource_record_sets(
          hosted_zone_id: zone_id, # required
          change_batch: { # required
            comment: "ACME challenge response: cleanup",
            changes: [
              {
                action: "DELETE", # required, accepts CREATE, DELETE, UPSERT
                resource_record_set: { # required
                  name: record_name,  # required
                  type: record_type,
                  ttl: 5,
                  resource_records: [
                    value: record_content
                  ],
                },
              },
            ],
          },
        )

        change_id = change_resp.change_info.id
        puts " * requested: #{change_id}"
      end

      private

      def canonical_fqdn(domain)
        "#{domain}.".sub(/\.+$/, '')
      end

      def find_hosted_zone(domain)
        labels = domain.split(?.)
        zones = nil
        0.upto(labels.size-1).each do |i|
          zones = hosted_zone_list["#{labels[i .. -1].join(?.)}."]
          break if zones
        end

        raise HostedZoneNotFound, "hosted zone not found for #{domain.inspect}" unless zones
        raise AmbiguousHostedZones, "multiple hosted zones found for #{domain.inspect}: #{zones.inspect}, set @hosted_zone_map to identify" if zones.size != 1
        zones.first
      end

      def hosted_zone_map
        @hosted_zone_map.map { |domain, zone_id|
          ["#{canonical_fqdn(domain)}.", [zone_id]] # XXX:
        }.to_h
      end

      def hosted_zone_list
        @hosted_zone_list ||= begin
          @route53.list_hosted_zones.each.flat_map do |page|
            page.hosted_zones.map {  |zone| [zone.name, zone.id] }
          end.group_by(&:first).map { |domain, kvs| [domain, kvs.map(&:last)] }.to_h.merge(hosted_zone_map)
        end
      end
    end
  end
end
