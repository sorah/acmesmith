require 'acmesmith/challenge_responders/base'
require 'net/http'
require 'uri'
require 'json'

module Acmesmith
  module ChallengeResponders
    class PebbleChalltestsrvDns < Base
      def support?(type)
        # Acme::Client::Resources::Challenges::DNS01
        type == 'dns-01'
      end

      def initialize(url: 'http://localhost:8055')
        warn_test
        @url = URI.parse(url)
      end

      attr_reader :url

      def respond(domain, challenge)
        warn_test

        Net::HTTP.post(
          URI.join(url,"/set-txt"),
          {
            host: "#{challenge.record_name}.#{domain}.",
            value: challenge.record_content,
          }.to_json,
        ).value
      end

      def cleanup(domain, challenge)
        warn_test

        Net::HTTP.post(
          URI.join(url,"/clear-txt"),
          {
            host: "#{challenge.record_name}.#{domain}.",
          }.to_json,
        ).value
      end

      def warn_test
        unless ENV['CI']
          $stderr.puts '!!!!!!!!! WARNING WARNING WARNING !!!!!!!!!'
          $stderr.puts '!!!! pebble-challtestsrv command is for TEST USAGE ONLY. It is trivially insecure, offering no authentication. Only use pebble-challtestsrv in a controlled test environment.'
          $stderr.puts '!!!! https://github.com/letsencrypt/pebble/blob/master/cmd/pebble-challtestsrv/README.md'
        end
      end
    end
  end
end
