module Acmesmith
  class AuthorizationService
    class NoApplicableChallengeResponder < StandardError; end
    class AuthorizationFailed < StandardError; end

    # @!attribute [r] domain
    #  @return [String] domain name
    # @!attribute [r] authorization
    #  @return [Acme::Client::Resources::Authorization] authz object
    # @!attribute [r] challenge_responder
    #  @return [Acmesmith::ChallengeResponders::Base] responder
    # @!attribute [r] challenge
    #  @return [Acme::Client::Resources::Challenges::Base] challenge
    AuthorizationProcess = Struct.new(:domain, :authorization, :challenge_responder, :challenge, keyword_init: true) do
      def completed?
        invalid? || valid?
      end

      def invalid?
        challenge.status == 'invalid'
      end

      def valid?
        challenge.status == 'valid'
      end

      def responder_id
        challenge_responder.__id__
      end
    end

    # @param challenge_responder_rules [Array<Acmemith::Config::ChallengeReponderRule>] 
    # @param authorizations [Array<Acme::Client::Resources::Authorization>]
    def initialize(challenge_responder_rules, authorizations)
      @challenge_responder_rules = challenge_responder_rules
      @authorizations = authorizations
    end

    attr_reader :challenge_responder_rules, :authorizations

    def perform!
      return if authorizations.empty?

      respond()
      request_validation()
      wait_for_validation()
      cleanup()

      puts "=> Authorized!"
    end

    def respond
      processes_by_responder.each do |responder, ps|
        puts "=> Responsing to the challenges for the following identifier:"
        puts
        puts " * Responder: #{responder.class}"
        puts " * Identifiers:"

        ps.each do |process|
          puts "     - #{process.domain} (#{process.challenge.challenge_type})"
        end

        puts
        responder.respond_all(*ps.map{ |t| [t.domain, t.challenge] })
      end
    end

    def request_validation
      puts "=> Requesting validations..."
      puts
      processes.each do |process|
        print " * #{process.domain} (#{process.challenge.challenge_type}) ..."
        process.challenge.request_validation()
        puts " [ ok ]"
      end
      puts

    end

    def wait_for_validation
      puts "=> Waiting for the validation..."
      puts

      loop do
        processes.each do |process|
          next if process.valid?

          process.challenge.reload

          status = process.challenge.status
          puts " * [#{process.domain}] status: #{status}"

          case
          when process.valid?
            next
          when process.invalid?
            err = process[:challenge].error
            puts " ! [#{process[:domain]}] error: #{err.inspect}"
          end
        end
        break if processes.all?(&:completed?)
        sleep 3
      end

      puts

      invalid_processes = processes.select(&:invalid?)
      unless invalid_processes.empty?
        $stderr.puts ""
        $stderr.puts "!! Some identitiers failed to challenge"
        $stderr.puts ""
        invalid_processes.each do |process|
          $stderr.puts "   - #{process.domain}: #{process.challenge.error.inspect}"
        end
        $stderr.puts ""
        raise AuthorizationFailed, "Some identifiers failed to challenge: #{invalid_processes.map(&:domain).inspect}"
      end

    end

    def cleanup
      processes_by_responder.each do |responder, ps|
        puts "=> Cleaning the responses the challenges for the following identifier:"
        puts
        puts " * Responder:   #{responder.class}"
        puts " * Identifiers:"
        ps.each do |process|
          puts "     - #{process.domain} (#{process.challenge.challenge_type})"
        end
        puts

        responder.cleanup_all(*ps.map{ |t| [t.domain, t.challenge] })
      end
    end

    # @return [Array<AuthorizationProcess>]
    def processes
      @processes ||= authorizations.map do |authz|
        challenge = nil
        responder_rule = challenge_responder_rules.select do |rule|
          rule.filter.applicable?(authz.domain)
        end.find do |rule|
          challenge = authz.challenges.find do |c|
            # OMG, acme-client might return a Hash instead of Acme::Client::Resources::Challenge::* object...
            rule.challenge_responder.support?(c.is_a?(Hash) ? c[:challenge_type] : c.challenge_type)
          end
        end

        unless responder_rule
          raise NoApplicableChallengeResponder, "Cannot find a challenge responder for domain #{authz.domain.inspect}"
        end

        AuthorizationProcess.new(
          domain: authz.domain,
          authorization: authz,
          challenge_responder: responder_rule.challenge_responder,
          challenge: challenge,
        )
      end
    end

    # @return [Array<(Acmesmith::ChallengeResponders::Base, Array<AuthorizationProcess>)>]
    def processes_by_responder
      @processes_by_responder ||= processes.group_by(&:responder_id).map { |_, ps| [ps[0].challenge_responder, ps] }
    end
  end
end
