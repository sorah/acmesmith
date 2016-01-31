module Acmesmith
  module ChallengeResponders
    class Base
      def support?(type)
        raise NotImplementedError
      end

      def initialize()
      end

      def respond(challenge)
        raise NotImplementedError
      end

      def cleanup(challenge)
        raise NotImplementedError
      end
    end
  end
end
