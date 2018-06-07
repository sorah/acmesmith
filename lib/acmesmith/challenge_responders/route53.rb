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

      def cap_respond_all?
        true
      end

      def initialize(aws_access_key: nil, hosted_zone_map: {})
        @route53 = Aws::Route53::Client.new({region: 'us-east-1'}.tap do |opt| 
          opt[:credentials] = Aws::Credentials.new(aws_access_key['access_key_id'], aws_access_key['secret_access_key'], aws_access_key['session_token']) if aws_access_key
        end)
        @hosted_zone_map = hosted_zone_map
        @hosted_zone_cache = {}
      end

      def respond_all(*domain_and_challenges)
        challenges_by_hosted_zone = domain_and_challenges.group_by { |(domain, _)| find_hosted_zone(domain) }

        zone_and_batches = challenges_by_hosted_zone.map do |zone_id, dcs|
          [zone_id, change_batch_for_challenges(dcs, action: 'UPSERT')]
        end

        change_ids = request_changing_rrset(zone_and_batches, comment: 'for challenge response')
        wait_for_sync(change_ids)
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
        change_ids = zone_and_batches.map do |(zone_id, change_batch)|
          puts " * #{zone_id}:"
          change_batch.fetch(:changes).each do |b|
            rrset = b.fetch(:resource_record_set)
            rrset.fetch(:resource_records).each do |rr|
              puts "   - #{b.fetch(:action)}: #{rrset.fetch(:name)} #{rrset.fetch(:ttl)} #{rrset.fetch(:type)} #{rr.fetch(:value)}"
            end
          end
          print "   ... "

          resp =  @route53.change_resource_record_sets(
            hosted_zone_id: zone_id, # required
            change_batch: change_batch,
          )
          change_id = resp.change_info.id

          puts "[ ok ] #{change_id}"
          puts
          change_id
        end

        change_ids
      end


      def wait_for_sync(change_ids)
        puts "=> Waiting for change to be in sync"
        puts

        all_sync = false
        until all_sync
          sleep 4

          all_sync = true
          change_ids.each do |id|
            change = @route53.get_change(id: id)

            sync = change.change_info.status == 'INSYNC'
            all_sync = false unless sync

            puts " * #{id}: #{change.change_info.status}"
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

      def hosted_zone_list
        @hosted_zone_list ||= begin
          @route53.list_hosted_zones.each.flat_map do |page|
            page.hosted_zones
              .reject { |zone| zone.config.private_zone }
              .map {  |zone| [zone.name, zone.id] }
          end.group_by(&:first).map { |domain, kvs| [domain, kvs.map(&:last)] }.to_h.merge(hosted_zone_map)
        end
      end
    end
  end
end
