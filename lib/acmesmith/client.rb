require 'acmesmith/account_key'
require 'acmesmith/certificate'

require 'acmesmith/save_certificate_service'

require 'acme-client'

module Acmesmith
  class Client
    def initialize(config: nil)
      @config ||= config
    end

    def register(contact)
      key = AccountKey.generate
      acme = Acme::Client.new(private_key: key.private_key, endpoint: config['endpoint'])
      registration = acme.register(contact: contact)
      registration.agree_terms

      storage.put_account_key(key, account_key_passphrase)

      key
    end

    def authorize(*domains)
      targets = domains.map do |domain|
        authz = acme.authorize(domain: domain)
        challenges = [authz.http01, authz.dns01, authz.tls_sni01].compact
        challenge = nil
        responder = config.challenge_responders.find do |x|
          challenge = challenges.find { |_| x.support?(_.class::CHALLENGE_TYPE) }
        end
        {domain: domain, authz: authz, responder: responder, challenge: challenge}
      end

      begin
        targets.each do |target|
          target[:responder].respond(target[:domain], target[:challenge])
        end

        targets.each do |target|
          puts "=> Requesting verifications..."
          target[:challenge].request_verification
        end
          loop do
            all_valid = true
            targets.each do |target|
              next if target[:valid]

              status = target[:challenge].verify_status
              puts " * [#{target[:domain]}] verify_status: #{status}"

              if status == 'valid'
                target[:valid] = true
                next
              end

              all_valid = false
              if status == "invalid"
                err = target[:challenge].error
                puts " ! [#{target[:domain]}] #{err["type"]}: #{err["detail"]}"
              end
            end
            break if all_valid
            sleep 3
          end
          puts "=> Done"
      ensure
        targets.each do |target|
          target[:responder].cleanup(target[:domain], target[:challenge])
        end
      end
    end

    def request(common_name, *sans)
      csr = Acme::Client::CertificateRequest.new(common_name: common_name, names: sans)
      retried = false
      acme_cert = begin
        acme.new_certificate(csr)
      rescue Acme::Client::Error::Unauthorized => e
        raise unless config.auto_authorize_on_request
        raise if retried

        puts "=> Authorizing unauthorized domain names"
        # https://github.com/letsencrypt/boulder/blob/b9369a481415b3fe31e010b34e2ff570b89e42aa/ra/ra.go#L604
        m = e.message.match(/authorizations for these names not found or expired: ((?:[a-zA-Z0-9_.\-]+(?:,\s+|$))+)/)
        if m && m[1]
          domains = m[1].split(/,\s+/)
        else
          warn " ! Error message on certificate request was #{e.message.inspect} and acmesmith couldn't determine which domain names are unauthorized (maybe a bug)"
          warn " ! Attempting to authorize all domains in this certificate reuqest for now."
          domains = [common_name, *sans]
        end
        puts " * #{domains.join(', ')}"
        authorize(*domains)
        retried = true
        retry
      end

      cert = Certificate.from_acme_client_certificate(acme_cert)
      storage.put_certificate(cert, certificate_key_passphrase)

      execute_post_issue_hooks(cert)

      cert
    end

    def post_issue_hooks(common_name)
      cert = storage.get_certificate(common_name)
      execute_post_issue_hooks(cert)
    end

    def execute_post_issue_hooks(certificate)
      hooks = config.post_issuing_hooks(certificate.common_name)
      hooks.each do |hook|
        hook.run(certificate: certificate)
      end
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
      
      p12 = OpenSSL::PKCS12.create(passphrase, cert.common_name, cert.private_key, cert.certificate)
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
        request(cert.common_name, *cert.sans)
      end
    end

    def add_san(common_name, *add_sans)
      puts "=> reissuing CN=#{common_name} with new SANs #{add_sans.join(?,)}"
      cert = storage.get_certificate(common_name)
      sans = cert.sans + add_sans
      puts " * SANs will be: #{sans.join(?,)}"
      request(cert.common_name, *sans)
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
      @acme ||= Acme::Client.new(private_key: account_key.private_key, endpoint: config['endpoint'])
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
  end
end
