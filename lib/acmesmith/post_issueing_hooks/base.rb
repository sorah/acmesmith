module Acmesmith
  module PostIssueingHooks
    class Base
      def initialize
      end

      def execute(domain)
        raise NotImplementedError
      end

    end
  end
end

