require 'acmesmith/account_key'
require 'acmesmith/certificate'
require 'acmesmith/save_certificate_service'
require 'acme-client'

module Acmesmith
  class Client
    def initialize(config: nil)
      @config ||= config
    end

    def new_account(contact, tos_agreed: true)
      key = AccountKey.generate
      acme = Acme::Client.new(private_key: key.private_key, directory: config.fetch('directory'))
      client = acme.new_account(contact: contact, terms_of_service_agreed: tos_agreed)

      storage.put_account_key(key, account_key_passphrase)

      key
    end

    def order(*identifiers, not_before: nil, not_after: nil)
      puts "=> Ordering a certificate for the following identifiers:"
      puts
      identifiers.each do |id|
        puts " * #{id}"
      end
      puts
      puts "=> Generating CSR"
      csr = Acme::Client::CertificateRequest.new(subject: { common_name: identifiers.first }, names: identifiers[1..-1])
      puts "=> Placing an order"
      order = acme.new_order(identifiers: identifiers, not_before: not_before, not_after: not_after)

      unless order.authorizations.empty? || order.status == 'ready'
        puts "=> Looking for required domain authorizations"
        puts
        order.authorizations.map(&:domain).each do |domain|
          puts " * #{domain}"
        end
        puts

        process_authorizations(order.authorizations)
      end

      cert = process_order_finalization(order, csr)

      puts "=> Certificate issued"
      puts
      print " * securing into the storage ..."
      storage.put_certificate(cert, certificate_key_passphrase)
      puts " [ ok ]"
      puts

      execute_post_issue_hooks(cert)

      cert
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
        order(cert.common_name, *cert.sans)
      end
    end

    def add_san(common_name, *add_sans)
      puts "=> reissuing CN=#{common_name} with new SANs #{add_sans.join(?,)}"
      cert = storage.get_certificate(common_name)
      sans = cert.sans + add_sans
      puts " * SANs will be: #{sans.join(?,)}"
      order(cert.common_name, *sans)
    end

    private

    def process_order_finalization(order, csr)
      puts "=> Finalizing the order"
      puts

      print " * Requesting..."
      order.finalize(csr: csr)
      puts" [ ok ]"

      while %w(ready processing).include?(order.status)
        order.reload()
        puts " * Waiting for procession: status=#{order.status}"
        sleep 2
      end
      puts

      Certificate.by_issuance(order.certificate, csr)
    end

    def process_authorizations(authzs)
      targets = authzs.map do |authz|
        challenges = authz.challenges
        challenge = nil
        responder = config.challenge_responders.find do |x|
          challenge = challenges.find { |_| x.support?(_.challenge_type) }
        end
        {domain: authz.domain, authz: authz, responder: responder, challenge: challenge}
      end
      return if targets.empty?

      begin
        targets.each do |target|
          puts "=> Authorizing the identifier '#{target[:domain]}' with:"
          puts
          puts " * Identifier: #{target[:domain]}"
          puts " * Challenge:  #{target[:challenge].challenge_type}"
          puts " * Responder:  #{target[:responder].class}"
          puts

          target[:responder].respond(target[:domain], target[:challenge])
        end

        puts "=> Requesting validations..."
        puts
        targets.each do |target|
          print " * #{target[:domain]} (#{target[:challenge].challenge_type}) ..."
          target[:challenge].request_validation()
          puts " [ ok ]"
        end
        puts

        puts "=> Waiting for the validation..."
        puts

        loop do
          all_valid = true
          any_error = false
          targets.each do |target|
            next if target[:valid]

            target[:challenge].reload
            status = target[:challenge].status

            puts " * [#{target[:domain]}] status: #{status}"

            if status == 'valid'
              target[:valid] = true
              next
            end

            all_valid = false
            if status == 'invalid'
              any_error = true
              err = target[:challenge].error
              puts " ! [#{target[:domain]}] error: #{err.inspect}"
            end
          end
          break if all_valid || any_error
          sleep 3
        end
        puts

        puts "=> Authorized!"

      ensure
        targets.each do |target|
          puts "=> Cleaning challenge for #{target[:domain]}"
          puts
          target[:responder].cleanup(target[:domain], target[:challenge])
        end
        puts
      end
    end



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
      @acme ||= Acme::Client.new(private_key: account_key.private_key, directory: config.fetch('directory'))
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
