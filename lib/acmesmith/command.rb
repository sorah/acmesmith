require 'thor'

require 'acmesmith/config'
require 'acmesmith/account_key'
require 'acmesmith/certificate'
require 'acme/client'

module Acmesmith
  class Command < Thor
    class_option :config, default: './acmesmith.yml', aliases: %w(-c)
    class_option :passphrase_from_env,  type: :boolean, aliases: %w(-E), default: false, desc: 'Read $ACMESMITH_ACCOUNT_KEY_PASSPHRASE and $ACMESMITH_CERTIFICATE_KEY_PASSPHRASE for passphrases'

    desc "register CONTACT", "Create account key (contact e.g. mailto:xxx@example.org)"
    def register(contact)
      key = AccountKey.generate
      acme = Acme::Client.new(private_key: key.private_key, endpoint: config['endpoint'])
      registration = acme.register(contact: contact)
      registration.agree_terms

      storage.put_account_key(key, account_key_passphrase)
      puts "Generated:\n#{key.private_key.public_key.to_pem}"
    end

    desc "authorize DOMAIN", "Get authz for DOMAIN."
    def authorize(domain)
      authz = acme.authorize(domain: domain)

      challenges = [authz.http01, authz.dns01, authz.tls_sni01].compact

      challenge = nil
      responder = config.challenge_responders.find do |x|
        challenge = challenges.find { |_| x.support?(_.class::CHALLENGE_TYPE) }
      end

      responder.respond(domain, challenge)

      puts "=> Requesting verification..."
      challenge.request_verification
      loop do
        status = challenge.verify_status
        puts " * verify_status: #{status}"
        break if status == 'valid'
        sleep 3
      end

      responder.cleanup(domain, challenge)
      puts "=> Done"
    end

    desc "request COMMON_NAME [SAN]", "request certificate for CN +COMMON_NAME+ with SANs +SAN+"
    def request(common_name, *sans)
      csr = Acme::Client::CertificateRequest.new(common_name: common_name, names: sans)
      acme_cert = acme.new_certificate(csr)

      cert = Certificate.from_acme_client_certificate(acme_cert)
      storage.put_certificate(cert, certificate_key_passphrase)

      puts cert.certificate.to_text
      puts cert.certificate.to_pem
    end

    desc "list [COMMON_NAME]", "list certificates or its versions"
    def list(common_name = nil)
      if common_name
        puts storage.list_certificate_versions(common_name).sort
      else
        puts storage.list_certificates.sort
      end
    end

    desc "current COMMON_NAME", "show current version for certificate"
    def current(common_name)
      puts storage.get_current_certificate_version(common_name)
    end

    desc "show-certificate COMMON_NAME", "show certificate"
    method_option :version, type: :string, default: 'current'
    method_option :type, type: :string, enum: %w(text certificate chain fullchain), default: 'text'
    def show_certificate(common_name)
      cert = storage.get_certificate(common_name, version: options[:version])

      case options[:type]
      when 'text'
        puts cert.certificate.to_text
        puts cert.certificate.to_pem
      when 'certificate'
        puts cert.certificate.to_pem
      when 'chain'
        puts cert.chain
      when 'fullchain'
        puts cert.fullchain
      end
    end
    map 'show-certiticate' => :show_certificate

    desc 'save-certificate COMMON_NAME', 'Save certificate to a file'
    method_option :version, type: :string, default: 'current'
    method_option :output, type: :string, required: true, banner: 'PATH', desc: 'Path to output file'
    method_option :mode, type: :string, default: '0600', desc: 'Mode (permission) of the output file on create'
    def save_certificate(common_name)
      cert = storage.get_certificate(common_name, version: options[:version])
      File.open(options[:output], 'w', options[:mode].to_i(8)) do |f|
        f.puts(cert.fullchain)
      end
    end

    desc "show-private-key COMMON_NAME", "show private key"
    method_option :version, type: :string, default: 'current'
    def show_private_key(common_name)
      cert = storage.get_certificate(common_name, version: options[:version])
      cert.key_passphrase = certificate_key_passphrase if certificate_key_passphrase

      puts cert.private_key.to_pem
    end
    map 'show-private-key' => :show_private_key

    desc 'save-private-key COMMON_NAME', 'Save private key to a file'
    method_option :version, type: :string, default: 'current'
    method_option :output, type: :string, required: true, banner: 'PATH', desc: 'Path to output file'
    method_option :mode, type: :string, default: '0600', desc: 'Mode (permission) of the output file on create'
    def save_private_key(common_name)
      cert = storage.get_certificate(common_name, version: options[:version])
      cert.key_passphrase = certificate_key_passphrase if certificate_key_passphrase
      File.open(options[:output], 'w', options[:mode].to_i(8)) do |f|
        f.puts(cert.private_key)
      end
    end

    desc "autorenew", "request renewal of certificates which expires soon"
    method_option :days, aliases: %w(-d), default: 7, desc: 'specify threshold in days to select certificates to renew'
    def autorenew
      storage.list_certificates.each do |cn|
        puts "=> #{cn}"
        cert = storage.get_certificate(cn)
        not_after = cert.certificate.not_after.utc

        puts "   Not valid after: #{not_after}"
        next unless (cert.certificate.not_after.utc - Time.now.utc) < (options[:days].to_i * 86400)
        puts " * Renewing: CN=#{cert.common_name}, SANs=#{cert.sans.join(',')}"
        request(cert.common_name, *cert.sans)
      end
    end

    private

    def config
      @config ||= Config.load_yaml(options[:config])
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
      @acme ||= Acme::Client.new(private_key: account_key.private_key, endpoint: config['endpoint'])
    end

    def certificate_key_passphrase
      if options[:passphrase_from_env]
        ENV['ACMESMITH_CERTIFICATE_KEY_PASSPHRASE'] || config['certificate_key_passphrase']
      else
        config['certificate_key_passphrase']
      end
    end

    def account_key_passphrase
      if options[:passphrase_from_env]
        ENV['ACMESMITH_ACCOUNT_KEY_PASSPHRASE'] || config['account_key_passphrase']
      else
        config['account_key_passphrase']
      end
    end
  end
end
