module Acmesmith
  module PostIssueingHooks
    class Base
      attr_reader :certificate

      def common_name
        certificate.common_name
      end

      def run(certificate:)
        @certificate = certificate
        execute
      end

      def execute
        raise NotImplementedError
      end
    end
  end
end

