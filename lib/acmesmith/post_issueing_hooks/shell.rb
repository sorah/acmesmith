require 'open3'
require 'erb'
require 'acmesmith/post_issueing_hooks/base'

module Acmesmith
  module PostIssueingHooks
    class Shell < Base
      class HostedZoneNotFound < StandardError; end
      class AmbiguousHostedZones < StandardError; end

      def initialize(common_name:, command:, ignore_failure:false)
        @common_name = common_name
        @command = command
        @ignore_failure = ignore_failure
      end

      def execute
        parsed_command = ERB.new(@command).result(binding)
        puts "=> Executing Post Issueing Hook for #{@common_name} in #{self.class.name}"
        puts "=> Running: #{parsed_command}"

        stdout, stderr, status = Open3.capture3(parsed_command + ";")

        if status != 0
          if @ignore_failure
            puts "WARNING"
            puts stderr
          else
            raise "FATAL\n#{stderr}"
          end
        else
          puts stdout
        end
      end
    end
  end
end
