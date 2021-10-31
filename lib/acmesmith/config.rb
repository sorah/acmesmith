require 'yaml'
require 'acmesmith/storages'
require 'acmesmith/challenge_responders'
require 'acmesmith/challenge_responder_filter'
require 'acmesmith/domain_name_filter'
require 'acmesmith/post_issuing_hooks'

module Acmesmith
  class Config
    ChallengeResponderRule = Struct.new(:challenge_responder, :filter, keyword_init: true)
    ChainPreference = Struct.new(:root_issuer_name, :root_issuer_key_id, :filter, keyword_init: true)

    def self.load_yaml(path)
      new YAML.load_file(path)
    end

    def initialize(config)
      @config = config
      validate
    end

    def validate
      unless @config['storage']
        raise ArgumentError, "config['storage'] must be provided"
      end

      if @config['endpoint'] and !@config['directory']
        raise ArgumentError, "config['directory'] must be provided, e.g. https://acme-v02.api.letsencrypt.org/directory or https://acme-staging-v02.api.letsencrypt.org/directory\n\nNOTE: We have dropped ACME v1 support since acmesmith v2.0.0. Specify v2 directory API URL using config['directory']."
      end

      unless @config['directory']
        raise ArgumentError, "config['directory'] must be provided, e.g. https://acme-v02.api.letsencrypt.org/directory or https://acme-staging-v02.api.letsencrypt.org/directory"
      end

      if @config.key?('chain_preferences') && !@config.fetch('chain_preferences').kind_of?(Array)
        raise ArgumentError, "config['chain_preferences'] must be an Array"
      end
    end

    def [](key)
      @config[key]
    end

    def fetch(*args)
      @config.fetch(*args)
    end

    def merge!(pair)
      @config.merge!(pair)
    end

    def directory
      @config.fetch('directory')
    end

    def connection_options
      @config['connection_options'] || {}
    end

    def bad_nonce_retry
      @config['bad_nonce_retry'] || 0
    end

    def account_key_passphrase
      @config['account_key_passphrase']
    end

    def certificate_key_passphrase
      @config['certificate_key_passphrase']
    end

    def auto_authorize_on_request
      @config.fetch('auto_authorize_on_request', true)
    end

    def storage
      @storage ||= begin
        c = @config['storage'].dup
        Storages.find(c.delete('type')).new(**c.map{ |k,v| [k.to_sym, v]}.to_h)
      end
    end

    def post_issuing_hooks(common_name)
      if @config.key?('post_issuing_hooks') && @config['post_issuing_hooks'].key?(common_name)
        specs = @config['post_issuing_hooks'][common_name]
        specs.flat_map do |specs_sub|
          specs_sub.map do |k, v|
            PostIssuingHooks.find(k).new(**v.map{ |k_,v_| [k_.to_sym, v_]}.to_h)
          end
        end
      else
        []
      end
    end

    def challenge_responders
      @challenge_responders ||= begin
        specs = @config['challenge_responders'].kind_of?(Hash) ? @config['challenge_responders'].map { |k,v| [k => v] } : @config['challenge_responders']
        specs.flat_map do |specs_sub|
          specs_sub = specs_sub.dup
          filter = (specs_sub.delete('filter') || {}).map { |k,v| [k.to_sym, v] }.to_h
          specs_sub.map do |k,v|
            responder = ChallengeResponders.find(k).new(**v.map{ |k_,v_| [k_.to_sym, v_]}.to_h)
            ChallengeResponderRule.new(
              challenge_responder: responder,
              filter: ChallengeResponderFilter.new(responder, **filter),
            )
          end
        end
      end
    end

    def chain_preferences
      @preferred_chains ||= begin
        specs = @config['chain_preferences'] || []
        specs.flat_map do |spec|
          filter = spec.fetch('filter', {}).map { |k,v| [k.to_sym, v] }.to_h
          ChainPreference.new(
            root_issuer_name: spec['root_issuer_name'],
            root_issuer_key_id: spec['root_issuer_key_id'],
            filter: DomainNameFilter.new(**filter),
          )
        end
      end
    end

    # def post_actions
    # end
  end
end
