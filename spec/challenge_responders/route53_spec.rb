require 'spec_helper'
require 'aws-sdk-route53'

require 'acmesmith/challenge_responders/route53'

class Acmesmith::ChallengeResponders::Route53
  def sleep(*); end
  def puts(*); end
  def print(*); end
end

RSpec.describe Acmesmith::ChallengeResponders::Route53 do
  let(:aws_access_key) { nil }
  let(:assume_role) { nil }
  let(:hosted_zone_map) { {} }
  let(:restore_to_original_records) { false }
  let(:substitution_map) { {} }

  let(:r53) { double(:route53) }

  subject(:responder) do
    described_class.new(
      aws_access_key: aws_access_key,
      assume_role: assume_role,
      hosted_zone_map: hosted_zone_map,
      restore_to_original_records: restore_to_original_records,
      substitution_map: substitution_map,
    )
  end


  describe ".new" do
    context "with no parameters" do
      before do
        expect(Aws::Route53::Client).to receive(:new).with(region: 'us-east-1').and_return(r53)
      end

      it "uses SDK default" do
        responder
      end
    end

    context "with aws_access_key" do
      let(:aws_access_key) { {'access_key_id' => 'a', 'secret_access_key' => 'b', 'session_token' => 'c'} }

      before do
        akia = double(:akia)
        allow(Aws::Credentials).to receive(:new).with('a', 'b', 'c').and_return(akia)
        expect(Aws::Route53::Client).to receive(:new).with(
          region: 'us-east-1',
          credentials: akia,
        ).and_return(r53)
      end

      it "uses credentials" do
        responder
      end
    end

    context "with assume_role" do
      let(:assume_role) { {'role_arn' => 'arn:aws:iam:', 'external_id' => 'external_id', 'role_session_name' => 'session'} }
      before do

        sts = double(:sts)
        allow(Aws::STS::Client).to receive(:new).with(region: 'us-east-1').and_return(sts)
        cred = double(:cred)
        expect(Aws::AssumeRoleCredentials).to receive(:new).with(
            client: sts,
            role_arn: 'arn:aws:iam:',
            external_id: 'external_id',
            role_session_name: 'session',
        ).and_return(cred)

        expect(Aws::Route53::Client).to receive(:new).with(
          region: 'us-east-1',
          credentials: cred,
        ).and_return(r53)
      end

      it "uses credentials" do
        responder
      end
    end

    context "with assume_role and access_key" do
      let(:aws_access_key) { {'access_key_id' => 'a', 'secret_access_key' => 'b', 'session_token' => 'c'} }
      let(:assume_role) { {'role_arn' => 'arn:aws:iam:', 'external_id' => 'external_id', 'role_session_name' => 'session'} }
      before do
        akia = double(:akia)
        allow(Aws::Credentials).to receive(:new).with('a', 'b', 'c').and_return(akia)
        sts = double(:sts)
        allow(Aws::STS::Client).to receive(:new).with(region: 'us-east-1', credentials: akia).and_return(sts)
        cred = double(:cred)
        expect(Aws::AssumeRoleCredentials).to receive(:new).with(
            client: sts,
            role_arn: 'arn:aws:iam:',
            external_id: 'external_id',
            role_session_name: 'session',
        ).and_return(cred)

        expect(Aws::Route53::Client).to receive(:new).with(
          region: 'us-east-1',
          credentials: cred,
        ).and_return(r53)
      end

      it "uses credentials" do
        responder
      end
    end
  end

  context do
    before do
      expect(Aws::Route53::Client).to receive(:new).with(region: 'us-east-1').and_return(r53)
    end

    let(:list_hosted_zones) do
      [
        *%w(example.com corp.example.com example.org).map do |_|
          Aws::Route53::Types::HostedZone.new(name: "#{_}.", id: "/hostedzone/#{_}", config: Aws::Route53::Types::HostedZoneConfig.new(private_zone: false))
        end,
        Aws::Route53::Types::HostedZone.new(name: "example.net.", id: "/hostedzone/example.net-true", config: Aws::Route53::Types::HostedZoneConfig.new(private_zone: false)),
        Aws::Route53::Types::HostedZone.new(name: "example.net.", id: "/hostedzone/example.net-dummy", config: Aws::Route53::Types::HostedZoneConfig.new(private_zone: false)),
      ]
    end

    before do
      allow(r53).to receive(:list_hosted_zones).and_return([Aws::Route53::Types::ListHostedZonesResponse.new(
        hosted_zones: list_hosted_zones,
      )])
    end

    def double_challenge()
      double(:challenge, record_name: '_acme-challenge', record_type: 'TXT', record_content: SecureRandom.urlsafe_base64(8))
    end

    def change_object(action:, name:, challenge:)
      {
        action: action,
        resource_record_set: {
          name: "_acme-challenge.#{name}",
          ttl: 5,
          type: 'TXT',
          resource_records: [
            {
              value: %("#{challenge.record_content}"),
            },
          ],
        },
      }
    end

    def expect_change_rrset(hosted_zone_id:, changes:, comment:, wait: true)
      @change_id ||= 0
      @change_id += 1
      expect(r53).to receive(:change_resource_record_sets).with(
        hosted_zone_id: hosted_zone_id,
        change_batch: {
          changes: changes,
          comment: comment,
        },
      ).and_return(Aws::Route53::Types::ChangeResourceRecordSetsResponse.new(
        change_info: Aws::Route53::Types::ChangeInfo.new(id: "/change/#{@change_id}", status: 'PENDING'),
      ))
      if wait
        expect(r53).to receive(:get_change).with(id: "/change/#{@change_id}").and_return(
          Aws::Route53::Types::GetChangeResponse.new(
            change_info: Aws::Route53::Types::ChangeInfo.new(id: "/change/#{@change_id}", status: 'INSYNC')
          )
        )
      end
    end

    describe "#respond_all" do
      subject(:respond_all) { responder.respond_all(*domain_and_challenges) }

      context "for single hosted zone (apex)" do
        let(:domain) { 'corp.example.com' }
        let(:challenge) { double_challenge }
        let(:domain_and_challenges) { [ [domain, challenge] ] }

        before do
          expect_change_rrset(
            hosted_zone_id: '/hostedzone/corp.example.com',
            comment: 'ACME challenge response ',
            changes: [
              change_object(action: 'UPSERT', name: domain, challenge: challenge),
            ],
          )
        end

        it "works" do
          respond_all
        end
      end

      context "for single hosted zone" do
        let(:domain_and_challenges) do
          [
            ['akane.example.com', double_challenge],
            ['yaeka.example.com', double_challenge],
          ]
        end

        before do
          expect_change_rrset(
            hosted_zone_id: '/hostedzone/example.com',
            comment: 'ACME challenge response ',
            changes: domain_and_challenges.map do |(domain,challenge)|
              change_object(action: 'UPSERT', name: domain, challenge: challenge)
            end,
          )
        end

        it "works" do
          respond_all
        end
      end

      context "for multiple hosted zones" do
        let(:domain_and_challenges) do
          [
            ['ibuki.example.com', double_challenge],
            ['kanade.corp.example.com', double_challenge],
          ]
        end

        before do
          expect_change_rrset(
            hosted_zone_id: '/hostedzone/example.com',
            comment: 'ACME challenge response ',
            changes: [
              change_object(action: 'UPSERT', name: domain_and_challenges[0][0], challenge: domain_and_challenges[0][1]),
            ],
          )
          expect_change_rrset(
            hosted_zone_id: '/hostedzone/corp.example.com',
            comment: 'ACME challenge response ',
            changes: [
              change_object(action: 'UPSERT', name: domain_and_challenges[1][0], challenge: domain_and_challenges[1][1]),
            ],
          )
        end

        it "works" do
          respond_all
        end
      end

      context "when hosted zones are ambiguous" do
        let(:domain) { 'botan.example.net' }
        let(:challenge) { double_challenge }
        let(:domain_and_challenges) { [ [domain, challenge] ] }

        it "raises error" do
          expect { respond_all }.to raise_error(Acmesmith::ChallengeResponders::Route53::AmbiguousHostedZones)
        end


        context "with correct hosted zone map" do
          let(:hosted_zone_map) { {"example.net" => "/hostedzone/example.net-true"} }

          before do
            expect_change_rrset(
              hosted_zone_id: '/hostedzone/example.net-true',
              comment: 'ACME challenge response ',
              changes: [
                change_object(action: 'UPSERT', name: domain, challenge: challenge)
              ],
            )
          end

          it "works" do
            respond_all
          end
        end
      end
    end

    describe "#cleanup_all" do
      subject(:cleanup_all) { responder.cleanup_all(*domain_and_challenges) }

      context "for single hosted zone (apex)" do
        let(:domain) { 'corp.example.com' }
        let(:challenge) { double_challenge }
        let(:domain_and_challenges) { [ [domain, challenge] ] }

        before do
          expect_change_rrset(
            hosted_zone_id: '/hostedzone/corp.example.com',
            comment: 'ACME challenge response (cleanup)',
            changes: [
              change_object(action: 'DELETE', name: domain, challenge: challenge),
            ],
            wait: false,
          )
        end

        it "works" do
          cleanup_all
        end
      end

      context "for single hosted zone" do
        let(:domain_and_challenges) do
          [
            ['akane.example.com', double_challenge],
            ['yaeka.example.com', double_challenge],
          ]
        end

        before do
          expect_change_rrset(
            hosted_zone_id: '/hostedzone/example.com',
            comment: 'ACME challenge response (cleanup)',
            changes: domain_and_challenges.map do |(domain,challenge)|
              change_object(action: 'DELETE', name: domain, challenge: challenge)
            end,
            wait: false,
          )
        end

        it "works" do
          cleanup_all
        end
      end

      context "for multiple hosted zones" do
        let(:domain_and_challenges) do
          [
            ['ibuki.example.com', double_challenge],
            ['kanade.corp.example.com', double_challenge],
          ]
        end

        before do
          expect_change_rrset(
            hosted_zone_id: '/hostedzone/example.com',
            comment: 'ACME challenge response (cleanup)',
            changes: [
              change_object(action: 'DELETE', name: domain_and_challenges[0][0], challenge: domain_and_challenges[0][1]),
            ],
            wait: false,
          )
          expect_change_rrset(
            hosted_zone_id: '/hostedzone/corp.example.com',
            comment: 'ACME challenge response (cleanup)',
            changes: [
              change_object(action: 'DELETE', name: domain_and_challenges[1][0], challenge: domain_and_challenges[1][1]),
            ],
            wait: false,
          )
        end

        it "works" do
          cleanup_all
        end
      end

      context "when hosted zones are ambiguous" do
        let(:domain) { 'botan.example.net' }
        let(:challenge) { double_challenge }
        let(:domain_and_challenges) { [ [domain, challenge] ] }

        it "raises error" do
          expect { cleanup_all }.to raise_error(Acmesmith::ChallengeResponders::Route53::AmbiguousHostedZones)
        end


        context "with correct hosted zone map" do
          let(:hosted_zone_map) { {"example.net" => "/hostedzone/example.net-true"} }

          before do
            expect_change_rrset(
              hosted_zone_id: '/hostedzone/example.net-true',
              comment: 'ACME challenge response (cleanup)',
              changes: [
                change_object(action: 'DELETE', name: domain, challenge: challenge)
              ],
              wait: false,
            )
          end

          it "works" do
            cleanup_all
          end
        end
      end
    end

    context "when restore_to_original_records is set" do
      let(:restore_to_original_records) { true }
      let(:domain_and_challenges) do
        [
          ['akane.example.com', double_challenge],
          ['yaeka.example.com', double_challenge],
        ]
      end

      subject(:roundtrip) {
        responder.respond_all(*domain_and_challenges) 
        responder.cleanup_all(*domain_and_challenges) 
      }

      before do
        allow(r53).to receive(:list_resource_record_sets).with(
          hosted_zone_id: '/hostedzone/example.com', 
          start_record_name: '_acme-challenge.akane.example.com.',
          start_record_type: nil,
          start_record_identifier: nil,
          max_items: 10,
        ).and_return(
          Aws::Route53::Types::ListResourceRecordSetsResponse.new(
            resource_record_sets: [
              Aws::Route53::Types::ResourceRecordSet.new(
                name: '_acme-challenge.akane.example.com.',
                type: 'CNAME',
                ttl: 60,
                resource_records: [
                  Aws::Route53::Types::ResourceRecord.new(value: 'delegated-validation.example.net.'),
                ],
              ),
            ],
            next_record_name: '_c.example.com.',
            next_record_type: 'A',
            next_record_identifier: nil,
          ),
        )

        allow(r53).to receive(:list_resource_record_sets).with(
          hosted_zone_id: '/hostedzone/example.com', 
          start_record_name: '_acme-challenge.yaeka.example.com.',
          start_record_type: nil,
          start_record_identifier: nil,
          max_items: 10,
        ).and_return(
          Aws::Route53::Types::ListResourceRecordSetsResponse.new(
            resource_record_sets: [
              Aws::Route53::Types::ResourceRecordSet.new(name: '_b.example.com.'),
            ],
            next_record_name: '_c.example.com.',
            next_record_type: 'A',
            next_record_identifier: nil,
          ),
        )

        expect_change_rrset(
          hosted_zone_id: '/hostedzone/example.com',
          comment: 'ACME challenge response ',
          changes: [
            {
              action: 'DELETE',
              resource_record_set: {
                name: "_acme-challenge.akane.example.com.",
                ttl: 60,
                type: 'CNAME',
                alias_target: nil,
                resource_records: [
                  {
                    value: "delegated-validation.example.net.",
                  },
                ],
              },
            },
            change_object(action: 'UPSERT', name: domain_and_challenges[0][0], challenge: domain_and_challenges[0][1]),
            change_object(action: 'UPSERT', name: domain_and_challenges[1][0], challenge: domain_and_challenges[1][1]),
          ],
        )
        expect_change_rrset(
          hosted_zone_id: '/hostedzone/example.com',
          comment: 'ACME challenge response (cleanup)',
          changes: [
            change_object(action: 'DELETE', name: domain_and_challenges[0][0], challenge: domain_and_challenges[0][1]),
            change_object(action: 'DELETE', name: domain_and_challenges[1][0], challenge: domain_and_challenges[1][1]),
            {
              action: 'CREATE',
              resource_record_set: {
                name: "_acme-challenge.akane.example.com.",
                ttl: 60,
                type: 'CNAME',
                alias_target: nil,
                resource_records: [
                  {
                    value: "delegated-validation.example.net.",
                  },
                ],
              },
            },
          ],
          wait: false,
        )
      end

      it "restores to original records on cleanup" do
        roundtrip
      end
    end

    context "when substitution_map is set" do
      let(:substitution_map) { {"akane.example.com." => "_akane.example.org"} }
      let(:domain_and_challenges) do
        [
          ['akane.example.com', double_challenge],
          ['yaeka.example.com', double_challenge],
        ]
      end

      subject(:roundtrip) {
        responder.respond_all(*domain_and_challenges) 
        responder.cleanup_all(*domain_and_challenges) 
      }

      before do
        expect_change_rrset(
          hosted_zone_id: '/hostedzone/example.org',
          comment: 'ACME challenge response ',
          changes: [
            change_object(action: 'UPSERT', name: "_akane.example.org", challenge: domain_and_challenges[0][1]),
          ],
        )
        expect_change_rrset(
          hosted_zone_id: '/hostedzone/example.com',
          comment: 'ACME challenge response ',
          changes: [
            change_object(action: 'UPSERT', name: domain_and_challenges[1][0], challenge: domain_and_challenges[1][1]),
          ],
        )
        expect_change_rrset(
          hosted_zone_id: '/hostedzone/example.org',
          comment: 'ACME challenge response (cleanup)',
          changes: [
            change_object(action: 'DELETE', name: "_akane.example.org", challenge: domain_and_challenges[0][1]),
          ],
          wait: false,
        )
        expect_change_rrset(
          hosted_zone_id: '/hostedzone/example.com',
          comment: 'ACME challenge response (cleanup)',
          changes: [
            change_object(action: 'DELETE', name: domain_and_challenges[1][0], challenge: domain_and_challenges[1][1]),
          ],
          wait: false,
        )
      end

      it "uses another name for rrset" do
        roundtrip
      end
    end

  end


  describe "#cap_respond_all?" do
    subject { responder.cap_respond_all? }
    it { is_expected.to eq(true) }
  end

  describe "#support?" do
    context "dns-01" do
      subject { responder.support?('dns-01') }
      it { is_expected.to eq(true) }
    end

    context "http-01" do
      subject { responder.support?('http-01') }
      it { is_expected.to eq(false) }
    end
  end
end
