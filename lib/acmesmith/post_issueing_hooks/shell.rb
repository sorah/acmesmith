require 'erb'
require 'acmesmith/post_issueing_hooks/base'

module Acmesmith
  module PostIssueingHooks
    class Shell < Base
      class HostedZoneNotFound < StandardError; end
      class AmbiguousHostedZones < StandardError; end

      def initialize(common_name:, command:)
        @common_name = common_name
        @command = command
      end

      def execute()
        parsed_command = ERB.new(@command).result(binding)
        puts "=> Executing Post Issueing Hook for #{@common_name} in #{self.class.name}"
        puts "=> Running #{parsed_command}"
        system(parsed_command)
      end
    end
  end
end
