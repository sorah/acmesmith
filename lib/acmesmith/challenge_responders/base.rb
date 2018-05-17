module Acmesmith
  module ChallengeResponders
    class Base
      # Return supported challenge types
      def support?(type)
        raise NotImplementedError
      end

      # Return 'true' if implements respond_all method.
      def cap_respond_all?
        false
      end

      def initialize()
      end

      # Respond to the given challenges (1 or more).
      def respond_all(*domain_and_challenges)
        if cap_respond_all?
          raise NotImplementedError
        else
          domain_and_challenges.each do |dc|
            respond(*dc)
          end
        end
      end

      # Clean up responses for the given challenges (1 or more).
      def cleanup_all(*domain_and_challenges)
        if cap_respond_all?
          raise NotImplementedError
        else
          domain_and_challenges.each do |dc|
            cleanup(*dc)
          end
        end
      end

      # If cap_respond_all? is true, you don't need to implement this method.
      def respond(domain, challenge)
        if cap_respond_all?
          respond_all([domain, challenge])
        else
          raise NotImplementedError
        end
      end

      # If cap_respond_all? is true, you don't need to implement this method.
      def cleanup(domain, challenge)
        if cap_respond_all?
          cleanup_all([domain, challenge])
        else
          raise NotImplementedError
        end
      end
    end
  end
end
