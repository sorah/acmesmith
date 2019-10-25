require 'acmesmith/challenge_responders/base'
require 'acmesmith/utils/aws'

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

      def cap_respond_all?
        true
      end

      def zone_domain_map
        @zone_domain_map ||= begin
          hosted_zone_list.each.map do |domain, zones|
            raise AmbiguousHostedZones, "multiple hosted zones found for #{domain.inspect}: #{zones.inspect}, set @hosted_zone_map to identify" if zones.size != 1
            [zones.first, domain]
          end.to_h
        end
      end

      def route53_for_zone(zone_id)
        domain = zone_domain_map[zone_id]
        @domain_route53_map.fetch(domain,  @default_route53)
      end

      def initialize(aws_access_key: nil, hosted_zone_map: {})
        @default_route53 = Aws::Route53::Client.new({region: 'us-east-1'}.tap do |opt|
          Acmesmith::Utils::Aws.addClientCredential(opt,aws_access_key)
        end)
        hosted_zone_map.transform_keys! do |domain|
          "#{canonical_fqdn(domain)}."
        end
        @hosted_zone_map = hosted_zone_map.map do |domain, hash_or_zone_id|
          zone_id = hash_or_zone_id.is_a?(Hash) ? hash_or_zone_id["zone_id"] : hash_or_zone_id
          next nil unless zone_id
          [domain, zone_id]
        end.compact.to_h
        arn_route53_cache = {}
        @domain_route53_map = hosted_zone_map.transform_values do |hash_or_zone_id|
          next @default_route53 unless hash_or_zone_id.is_a?(Hash)
          role_arn = hash_or_zone_id["role_arn"]
          next @default_route53 unless role_arn

          next arn_route53_cache[role_arn] if arn_route53_cache[role_arn]
          route53 = Aws::Route53::Client.new({region: 'us-east-1'}.tap do |opt|
            Acmesmith::Utils::Aws.addClientCredential(opt,aws_access_key, role_arn)
          end)
          arn_route53_cache[role_arn] = route53
          route53
        end
      end

      def respond_all(*domain_and_challenges)
        challenges_by_hosted_zone = domain_and_challenges.group_by { |(domain, _)| find_hosted_zone(domain) }

        zone_and_batches = challenges_by_hosted_zone.map do |zone_id, dcs|
          [zone_id, change_batch_for_challenges(dcs, action: 'UPSERT')]
        end

        zone_to_change_ids = request_changing_rrset(zone_and_batches, comment: 'for challenge response')
        wait_for_sync(zone_to_change_ids)
      end

      def cleanup_all(*domain_and_challenges)
        challenges_by_hosted_zone = domain_and_challenges.group_by { |(domain, _)| find_hosted_zone(domain) }

        zone_and_batches = challenges_by_hosted_zone.map do |zone_id, dcs|
          [zone_id, change_batch_for_challenges(dcs, action: 'DELETE', comment: '(cleanup)')]
        end

        request_changing_rrset(zone_and_batches, comment: 'to remove challenge responses')
      end

      private

      def request_changing_rrset(zone_and_batches, comment: nil)
        puts "=> Requesting RRSet change #{comment}"
        puts
        zone_to_change_ids = zone_and_batches.map do |(zone_id, change_batch)|
          puts " * #{zone_id}:"
          change_batch.fetch(:changes).each do |b|
            rrset = b.fetch(:resource_record_set)
            rrset.fetch(:resource_records).each do |rr|
              puts "   - #{b.fetch(:action)}: #{rrset.fetch(:name)} #{rrset.fetch(:ttl)} #{rrset.fetch(:type)} #{rr.fetch(:value)}"
            end
          end
          print "   ... "

          resp =  route53_for_zone(zone_id).change_resource_record_sets(
            hosted_zone_id: zone_id, # required
            change_batch: change_batch,
          )
          change_id = resp.change_info.id

          puts "[ ok ] #{change_id}"
          puts
          [zone_id, change_id]
        end

        zone_to_change_ids.to_h
      end


      def wait_for_sync(zone_to_change_ids)
        puts "=> Waiting for change to be in sync"
        puts

        all_sync = false
        until all_sync
          sleep 4

          all_sync = true
          zone_to_change_ids.each do |zone_id,change_id|
            change = route53_for_zone(zone_id).get_change(id: change_id)

            sync = change.change_info.status == 'INSYNC'
            all_sync = false unless sync

            puts " * #{change_id}: #{change.change_info.status}"
            sleep 0.2
          end
        end
        puts

      end

      def change_batch_for_challenges(domain_and_challenges, comment: nil, action: 'UPSERT')
        changes = domain_and_challenges
          .map do |d, c|
            rrset_for_challenge(d, c)
          end
          .group_by do |_|
            # Reduce changes by name. ACME server may require multiple challenge responses for the same identifier
            _.fetch(:name) 
          end
          .map do |name, cs| 
            cs.inject { |result, change|
              result.merge(resource_records: result.fetch(:resource_records, []) + change.fetch(:resource_records))
            }
          end
          .map do |change|
            {
              action: action,
              resource_record_set: change,
            }
          end

        {
          comment: "ACME challenge response #{comment}",
          changes: changes,
        }
      end

      def rrset_for_challenge(domain, challenge)
        domain = canonical_fqdn(domain)
        {
          name: "#{challenge.record_name}.#{domain}",
          type: challenge.record_type,
          ttl: 5,
          resource_records: [
            value: "\"#{challenge.record_content}\"",
          ],
        }
      end

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

      def get_zone_list_for_route53(route53)
        route53.list_hosted_zones.each.flat_map do |page|
          page.hosted_zones
            .reject { |zone| zone.config.private_zone }
            .map {  |zone| [zone.name, zone.id] }
        end.group_by(&:first).map { |domain, kvs| [domain, kvs.map(&:last)] }.to_h
      end

      def hosted_zone_list
        @hosted_zone_list ||= begin
          route53_clients = @domain_route53_map.values.uniq + [@default_route53] #later one have higher priority
          hosted_zone_lists = route53_clients.map do |route53|
            get_zone_list_for_route53(route53)
          end
          hosted_zone_lists.fetch(0,{}).merge(*hosted_zone_lists[1..-1]).merge(hosted_zone_map)
        end
      end

    end
  end
end
