require 'acmesmith/post_issueing_hooks/base'

module Acmesmith
  module PostIssueingHooks
    class Sendmail < Base
      class HostedZoneNotFound < StandardError; end
      class AmbiguousHostedZones < StandardError; end

      def initialize(common_name:, recipient:, subject:)
        @common_name = common_name
        @recipient = recipient
        @subject = subject
      end

      def execute
        parsed_subject = ERB.new(@subject).result(binding)
        puts "=> Executing Post Issueing Hook for #{@common_name} in #{self.class.name}"
        puts "=> Sending mail to #{@recipient} with subject '#{parsed_subject}'"
      end

    end
  end
end
