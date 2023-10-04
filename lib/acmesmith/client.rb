require 'acmesmith/account_key'
require 'acmesmith/certificate'
require 'acmesmith/authorization_service'
require 'acmesmith/ordering_service'
require 'acmesmith/save_certificate_service'
require 'acme-client'

module Acmesmith
  class Client
    def initialize(config: nil)
      @config ||= config
    end

    def new_account(contact, tos_agreed: true)
      key = AccountKey.generate
      acme = Acme::Client.new(private_key: key.private_key, directory: config.directory, connection_options: config.connection_options, bad_nonce_retry: config.bad_nonce_retry)
      acme.new_account(contact: contact, terms_of_service_agreed: tos_agreed)

      storage.put_account_key(key, account_key_passphrase)

      key
    end

    def order(*identifiers, key_type: 'rsa', rsa_key_size: 2048, elliptic_curve: 'prime256v1', not_before: nil, not_after: nil)
      private_key = generate_private_key(key_type: key_type, rsa_key_size: rsa_key_size, elliptic_curve: elliptic_curve)
      order_with_private_key(*identifiers, private_key: private_key, not_before: not_before, not_after: not_after)
    end

    def authorize(*identifiers)
      raise NotImplementedError, "Domain authorization in advance is still not available in acme-client (v2). Required authorizations will be performed when ordering certificates"
    end

    def post_issue_hooks(common_name)
      cert = storage.get_certificate(common_name)
      execute_post_issue_hooks(cert)
    end

    def execute_post_issue_hooks(certificate)
      hooks = config.post_issuing_hooks(certificate.common_name)
      return if hooks.empty?
      puts "=> Executing post issuing hooks for CN=#{certificate.common_name}"
      hooks.each do |hook|
        hook.run(certificate: certificate)
      end
      puts
    end

    def certificate_versions(common_name)
      storage.list_certificate_versions(common_name).sort
    end

    def certificates_list
      storage.list_certificates.sort
    end

    def current(common_name)
      storage.get_current_certificate_version(common_name)
    end

    def get_certificate(common_name, version: 'current', type: 'text')
      cert = storage.get_certificate(common_name, version: version)

      certs = []
      case type
      when 'text'
        certs << cert.certificate.to_text
        certs << cert.certificate.to_pem
      when 'certificate'
        certs << cert.certificate.to_pem
      when 'chain'
        certs << cert.chain
      when 'fullchain'
        certs << cert.fullchain
      end

      certs
    end

    def save_certificate(common_name, version: 'current', mode: '0600', output:, type: 'fullchain')
      cert = storage.get_certificate(common_name, version: version)
      File.open(output, 'w', mode.to_i(8)) do |f|
        case type
        when 'certificate'
          f.puts cert.certificate.to_pem
        when 'chain'
          f.puts cert.chain
        when 'fullchain'
          f.puts cert.fullchain
        end
      end
    end

    def get_private_key(common_name, version: 'current')
      cert = storage.get_certificate(common_name, version: version)
      cert.key_passphrase = certificate_key_passphrase if certificate_key_passphrase

      cert.private_key.to_pem
    end

    def save_private_key(common_name, version: 'current', mode: '0600', output:)
      cert = storage.get_certificate(common_name, version: version)
      cert.key_passphrase = certificate_key_passphrase if certificate_key_passphrase
      File.open(output, 'w', mode.to_i(8)) do |f|
        f.puts(cert.private_key)
      end
    end

    def save_pkcs12(common_name, version: 'current', mode: '0600', output:, passphrase:)
      cert = storage.get_certificate(common_name, version: version)
      cert.key_passphrase = certificate_key_passphrase if certificate_key_passphrase
      
      p12 = cert.pkcs12(passphrase)
      File.open(output, 'w', mode.to_i(8)) do |f|
        f.puts p12.to_der
      end
    end

    def save(common_name, version: 'current', **kwargs)
      cert = storage.get_certificate(common_name, version: version)
      cert.key_passphrase = certificate_key_passphrase if certificate_key_passphrase

      SaveCertificateService.new(cert, **kwargs).perform!
    end

    def autorenew(days: 7, common_names: nil)
      (common_names || storage.list_certificates).each do |cn|
        puts "=> #{cn}"
        cert = storage.get_certificate(cn)
        not_after = cert.certificate.not_after.utc

        puts "   Not valid after: #{not_after}"
        next unless (cert.certificate.not_after.utc - Time.now.utc) < (days.to_i * 86400)
        puts " * Renewing: CN=#{cert.common_name}, SANs=#{cert.sans.join(',')}"
        order_with_private_key(cert.common_name, *cert.sans, private_key: regenerate_private_key(cert.public_key))
      end
    end

    def add_san(common_name, *add_sans)
      puts "=> reissuing CN=#{common_name} with new SANs #{add_sans.join(?,)}"
      cert = storage.get_certificate(common_name)
      sans = cert.sans + add_sans
      puts " * SANs will be: #{sans.join(?,)}"
      order_with_private_key(cert.common_name, *sans, private_key: regenerate_private_key(cert.public_key))
    end

    private


    def config
      @config
    end

    def storage
      config.storage
    end

    def account_key
      @account_key ||= storage.get_account_key.tap do |x|
        x.key_passphrase = account_key_passphrase if account_key_passphrase
      end
    end

    def acme
      @acme ||= Acme::Client.new(private_key: account_key.private_key, directory: config.directory, connection_options: config.connection_options, bad_nonce_retry: config.bad_nonce_retry)
    end

    def certificate_key_passphrase
      if config['passphrase_from_env']
        ENV['ACMESMITH_CERTIFICATE_KEY_PASSPHRASE'] || config['certificate_key_passphrase']
      else
        config['certificate_key_passphrase']
      end
    end

    def account_key_passphrase
      if config['passphrase_from_env']
        ENV['ACMESMITH_ACCOUNT_KEY_PASSPHRASE'] || config['account_key_passphrase']
      else
        config['account_key_passphrase']
      end
    end

    def order_with_private_key(*identifiers, private_key:, not_before: nil, not_after: nil)
      order = OrderingService.new(
        acme: acme,
        identifiers: identifiers,
        private_key: private_key,
        challenge_responder_rules: config.challenge_responders,
        chain_preferences: config.chain_preferences,
        not_before: not_before,
        not_after: not_after
      )
      order.perform!
      cert = order.certificate

      puts
      print " * securing into the storage ..."
      storage.put_certificate(cert, certificate_key_passphrase)
      puts " [ ok ]"
      puts

      execute_post_issue_hooks(cert)

      cert
    end

    def generate_private_key(key_type:, rsa_key_size:, elliptic_curve:)
      case key_type
      when 'rsa'
        OpenSSL::PKey::RSA.generate(rsa_key_size)
      when 'ec'
        OpenSSL::PKey::EC.generate(elliptic_curve)
      else
        raise ArgumentError, "Key type #{key_type} is not supported"
      end
    end

    # Generate a new key pair with the same type and key size / curve as existing one
    def regenerate_private_key(template)
      case template
      when OpenSSL::PKey::RSA
        OpenSSL::PKey::RSA.generate(template.n.num_bits)
      when OpenSSL::PKey::EC
        OpenSSL::PKey::EC.generate(template.group)
      else
        raise ArgumentError, "Unknown key type: #{template.class}"
      end
    end
  end
end
