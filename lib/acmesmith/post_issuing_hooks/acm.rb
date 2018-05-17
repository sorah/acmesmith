require 'aws-sdk-acm'
require 'acmesmith/post_issuing_hooks/base'

module Acmesmith
  module PostIssuingHooks
    class Acm < Base
      def initialize(certificate_arn: nil, region:)
        @certificate_arn = certificate_arn
        @certificate_arn_set = true if @certificate_arn
        @region = region
      end

      attr_reader :region

      def certificate_arn
        return @certificate_arn if @certificate_arn_set
        @certificate_arn ||= find_certificate_arn
        @certificate_arn_set = true
        @certificate_arn
      end

      def find_certificate_arn
        acm.list_certificates().each do |page|
          page.certificate_summary_list.each do |summary|
            if summary.domain_name == common_name
              tags = acm.list_tags_for_certificate(certificate_arn: summary.certificate_arn).tags
              if tags.find{ |_| _.key == 'Acmesmith' }
                return summary.certificate_arn
              end
            end
          end
        end
      end

      def acm
        @acm ||= Aws::ACM::Client.new(region: region)
      end

      def execute
        puts "=> Importing certificate CN=#{common_name} into AWS ACM (region=#{region})"
        if certificate_arn
          puts " * updating ARN: #{certificate_arn}"
        else
          puts " * Importing as as new certificate"
        end

        resp = acm.import_certificate(
          {
            certificate: certificate.certificate.to_pem,
            private_key: certificate.private_key.to_pem,
            certificate_chain: certificate.issuer_pems,
          }.merge(certificate_arn ? {certificate_arn: certificate_arn} : {})
        )
        unless certificate_arn
          puts " * ARN: #{resp.certificate_arn}"
        end

        acm.add_tags_to_certificate(
          certificate_arn: resp.certificate_arn,
          tags: [key: 'Acmesmith', value: '1'],
        )
      end
    end
  end
end
