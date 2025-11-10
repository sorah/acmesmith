require 'open3'
require 'acmesmith/post_issuing_hooks/base'

module Acmesmith
  module PostIssuingHooks
    class Shell < Base
      def initialize(command:, ignore_failure: false)
        @command = command
        @ignore_failure = ignore_failure
      end

      def execute
        puts "=> Executing Post Issuing Hook for #{certificate.name.inspect} in #{self.class.name}"
        puts " $ #{@command}"

        status = system({"CERT_NAME" => certificate.name, "COMMON_NAME" => common_name}.compact, @command)

        unless status
          if @ignore_failure
            $stderr.puts " ! execution failed"
          else
            raise "Execution failed"
          end
        end
      end
    end
  end
end
