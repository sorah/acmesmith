require 'thor'

require 'acmesmith/config'
require 'acmesmith/client'

module Acmesmith
  class Command < Thor
    class_option :config, default: './acmesmith.yml', aliases: %w(-c)
    class_option :passphrase_from_env,  type: :boolean, aliases: %w(-E), default: nil, desc: 'Read $ACMESMITH_ACCOUNT_KEY_PASSPHRASE and $ACMESMITH_CERTIFICATE_KEY_PASSPHRASE for passphrases'

    desc "new-account CONTACT", "Create account key (contact e.g. mailto:xxx@example.org)"
    def new_account(contact)
      puts "=> Creating an account ..."
      key = client.new_account(contact)
      puts "=> Public Key:"
      puts "\n#{key.private_key.public_key.to_pem}"
    end

    desc "authorize DOMAIN [DOMAIN ...]", "(Implementation disabled for v2) Get authz for DOMAIN."
    def authorize(*domains)
      warn "! WARNING: 'acmesmith authorize' is not available"
      warn "!"
      warn "! TL;DR: Go ahead; Just run 'acmesmith order'."
      warn "!"
      warn "! Pre-authorization have not implemented yet in acme-client.gem (v2) library."
      warn "! But, required domain authorizations will be performed automatically when ordering a certificate."
      warn "!"
      warn "! Pro Tips: Let's encrypt doesn't provide pre-authorization as of May 18, 2018."
      warn "!"
      # client.authorize(*domains)
    end

    desc "order NAME [SAN]", "order certificate for CN +NAME+ with SANs +SAN+"
    method_option :show_certificate, type: :boolean, aliases: %w(-s), default: true, desc: 'show an issued certificate in PEM and text when exiting'
    method_option :key_type, type: :string, enum: %w(rsa ec), default: 'rsa', desc: 'key type'
    method_option :rsa_key_size, type: :numeric, default: 2048, desc: 'size of RSA key'
    method_option :elliptic_curve, type: :string, default: 'prime256v1', desc: 'elliptic curve group for EC key'
    def order(name, *sans)
      cert = client.order(
        name, *sans,
        key_type: options[:key_type],
        rsa_key_size: options[:rsa_key_size],
        elliptic_curve: options[:elliptic_curve],
      )
      if options[:show_certificate]
        puts cert.certificate.to_text
        puts cert.certificate.to_pem
      end
    end

    desc "post-issue-hooks NAME", "Run all post-issuing hooks for common name. (for testing purpose)"
    def post_issue_hooks(name)
      client.post_issue_hooks(name)
    end
    map 'post-issue-hooks' => :post_issue_hooks

    desc "list [NAME]", "list certificates or its versions"
    def list(name = nil)
      if name
        puts client.certificate_versions(name)
      else
        puts client.certificates_list
      end
    end

    desc "current NAME", "show current version for certificate"
    def current(name)
      puts client.current(name)
    end

    desc "show-certificate NAME", "show certificate"
    method_option :version, type: :string, default: 'current'
    method_option :type, type: :string, enum: %w(text certificate chain fullchain), default: 'text'
    def show_certificate(name)
      certs = client.get_certificate(name, version: options[:version], type: options[:type])
      puts certs
    end
    map 'show-certiticate' => :show_certificate

    desc 'save-certificate NAME', 'Save certificate to a file'
    method_option :version, type: :string, default: 'current'
    method_option :type, type: :string, enum: %w(certificate chain fullchain), default: 'fullchain'
    method_option :output, type: :string, required: true, banner: 'PATH', desc: 'Path to output file'
    method_option :mode, type: :string, default: '0600', desc: 'Mode (permission) of the output file on create'
    def save_certificate(name)
      client.save_certificate(name, version: options[:version], mode: options[:mode], output: options[:output], type: options[:type])
    end

    desc "show-private-key NAME", "show private key"
    method_option :version, type: :string, default: 'current'
    def show_private_key(name)
      puts client.get_private_key(name, version: options[:version])
    end
    map 'show-private-key' => :show_private_key

    desc 'save-private-key NAME', 'Save private key to a file'
    method_option :version, type: :string, default: 'current'
    method_option :output, type: :string, required: true, banner: 'PATH', desc: 'Path to output file'
    method_option :mode, type: :string, default: '0600', desc: 'Mode (permission) of the output file on create'
    def save_private_key(name)
      client.save_private_key(name, version: options[:version], mode: options[:mode], output: options[:output])
    end

    desc 'save NAME', 'Save (or update) certificate and key files.'
    method_option :version, type: :string, default: 'current'
    method_option :key_mode, type: :string, default: '0600', desc: 'Mode (permission) of the key file on create'
    method_option :certificate_mode, type: :string, default: '0644', desc: 'Mode (permission) of the certificate files on create'
    method_option :version_file, type: :string, required: false, banner: 'PATH', desc: 'Path to save a certificate version for following run (optional)'
    method_option :key_file, type: :string, required: false, banner: 'PATH', desc: 'Path to save a key'
    method_option :fullchain_file, type: :string, required: false , banner: 'PATH', desc: 'Path to save a certficiate and its chain (concatenated)'
    method_option :chain_file, type: :string, required: false , banner: 'PATH', desc: 'Path to save a certificate chain (root and intermediate CA)'
    method_option :certificate_file, type: :string, required: false, banner: 'PATH', desc: 'Path to save a certficiate'
    method_option :atomic, type: :boolean, default: true, desc: 'Enable atomic file update with rename(2)'
    def save(name)
      client.save(
        name,
        version: options[:version],
        key_mode: options[:key_mode],
        certificate_mode: options[:certificate_mode],
        version_file: options[:version_file],
        key_file: options[:key_file],
        fullchain_file: options[:fullchain_file],
        chain_file: options[:chain_file],
        certificate_file: options[:certificate_file],
        atomic: options[:atomic],
        verbose: true,
      )
    end

    desc 'save-pkcs12 NAME', 'Save ceriticate and private key to .p12 file'
    method_option :version, type: :string, default: 'current'
    method_option :output, type: :string, required: true, banner: 'PATH', desc: 'Path to output file'
    method_option :mode, type: :string, default: '0600', desc: 'Mode (permission) of the output file on create'
    def save_pkcs12(name)
      print 'Passphrase: '
      passphrase = $stdin.noecho { $stdin.gets }.chomp
      print "\nPassphrase (confirm): "
      passphrase2 = $stdin.noecho { $stdin.gets }.chomp
      puts

      raise ArgumentError, "Passphrase doesn't match" if passphrase != passphrase2
      client.save_pkcs12(name, version: options[:version], mode: options[:mode], output: options[:output], passphrase: passphrase)
    end

    desc "autorenew [NAMES]", "request renewal of certificates which expires soon"
    method_option :days, type: :numeric, aliases: %w(-d), default: nil, desc: 'specify threshold in days to select certificates to renew'
    method_option :remaining_life, type: :string, aliases: %w(-r), default: '1/3', desc: "Specify threshold based on remaining life. Accepts a percentage ('20%') or fraction ('1/3')"
    def autorenew(*names)
      remaining_life = case options[:remaining_life]
                       when %r{\A\d+/\d+\z}
                         Rational(options[:remaining_life])
                       when %r{\A([\d.]+)%\z}
                         Rational($1.to_f, 100)
                       when nil
                         nil
                       else
                         raise ArgumentError, "invalid format for --remaining-life: it must be in '..%' or '../..'"
                       end
      client.autorenew(days: options[:days], remaining_life: remaining_life, names: names.empty? ? nil : names)
    end

    desc "add-san NAME [ADDITIONAL_SANS]", "request renewal of existing certificate with additional SANs"
    def add_san(name, *add_sans)
      client.add_san(name, *add_sans)
    end

    desc "register CONTACT", "(deprecated, use 'acmesmith new-account')"
    def register(contact)
      warn "!"
      warn "! DEPRECATION WARNING: Use 'acmesmith new-account' command"
      warn "! There is no user-facing breaking changes. It takes the same arguments with 'acmesmith register'."
      warn "!"
      warn "! This is due to change in semantics of ACME v2. ACME v2 defines 'new-account' instead of 'register' in v1."
      warn "!"
      new_account(contact)
    end

    desc "request NAME [SAN]", "(deprecated, use 'acmesmith order')"
    method_option :show_certificate, type: :boolean, aliases: %w(-s), default: true, desc: 'show an issued certificate in PEM and text when exiting'
    def request(name, *sans)
      warn "!"
      warn "! DEPRECATION WARNING: Use 'acmesmith order' command"
      warn "! There is no user-facing breaking changes. It takes the same arguments with 'acmesmith request'."
      warn "!"
      warn "! This is due to change in semantics of ACME v2. ACME v2 defines 'order' instead of 'request' in v1."
      warn "!"
      order(name, *sans)
    end

    private

    def client
      config = Config.load_yaml(options[:config])
      config.merge!("passphrase_from_env" => options[:passphrase_from_env]) unless options[:passphrase_from_env].nil?
      @client = Client.new(config: config)
    end
  end
end
