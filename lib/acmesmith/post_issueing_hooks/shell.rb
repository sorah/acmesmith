require 'open3'
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
        puts "=> Executing Post Issueing Hook for #{@common_name} in #{self.class.name}"
        puts "=> ENV: COMMON_NAME=#{@common_name}"
        puts "=> Running: #{@command}"

        status = system({"COMMON_NAME" => @common_name}, "#{@command};")

        unless status
          if @ignore_failure
            $stderr.puts "WARNING, command failed"
          else
            raise "FATAL, command failed"
          end
        end
      end
    end
  end
end
