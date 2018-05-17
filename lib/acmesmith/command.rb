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

    desc "order COMMON_NAME [SAN]", "order certificate for CN +COMMON_NAME+ with SANs +SAN+"
    method_option :show_certificate, type: :boolean, aliases: %w(-s), default: true, desc: 'show an issued certificate in PEM and text when exiting'
    def order(common_name, *sans)
      cert = client.order(common_name, *sans)
      if options[:show_certificate]
        puts cert.certificate.to_text
        puts cert.certificate.to_pem
      end
    end

    desc "post-issue-hooks COMMON_NAME", "Run all post-issuing hooks for common name. (for testing purpose)"
    def post_issue_hooks(common_name)
      client.post_issue_hooks(common_name)
    end
    map 'post-issue-hooks' => :post_issue_hooks

    desc "list [COMMON_NAME]", "list certificates or its versions"
    def list(common_name = nil)
      if common_name
        puts client.certificate_versions(common_name)
      else
        puts client.certificates_list
      end
    end

    desc "current COMMON_NAME", "show current version for certificate"
    def current(common_name)
      puts client.current(common_name)
    end

    desc "show-certificate COMMON_NAME", "show certificate"
    method_option :version, type: :string, default: 'current'
    method_option :type, type: :string, enum: %w(text certificate chain fullchain), default: 'text'
    def show_certificate(common_name)
      certs = client.get_certificate(common_name, version: options[:version], type: options[:type])
      puts certs
    end
    map 'show-certiticate' => :show_certificate

    desc 'save-certificate COMMON_NAME', 'Save certificate to a file'
    method_option :version, type: :string, default: 'current'
    method_option :type, type: :string, enum: %w(certificate chain fullchain), default: 'fullchain'
    method_option :output, type: :string, required: true, banner: 'PATH', desc: 'Path to output file'
    method_option :mode, type: :string, default: '0600', desc: 'Mode (permission) of the output file on create'
    def save_certificate(common_name)
      client.save_certificate(common_name, version: options[:version], mode: options[:mode], output: options[:output], type: options[:type])
    end

    desc "show-private-key COMMON_NAME", "show private key"
    method_option :version, type: :string, default: 'current'
    def show_private_key(common_name)
      puts client.get_private_key(common_name, version: options[:version])
    end
    map 'show-private-key' => :show_private_key

    desc 'save-private-key COMMON_NAME', 'Save private key to a file'
    method_option :version, type: :string, default: 'current'
    method_option :output, type: :string, required: true, banner: 'PATH', desc: 'Path to output file'
    method_option :mode, type: :string, default: '0600', desc: 'Mode (permission) of the output file on create'
    def save_private_key(common_name)
      client.save_private_key(common_name, version: options[:version], mode: options[:mode], output: options[:output])
    end

    desc 'save COMMON_NAME', 'Save (or update) certificate and key files.'
    method_option :version, type: :string, default: 'current'
    method_option :key_mode, type: :string, default: '0600', desc: 'Mode (permission) of the key file on create'
    method_option :certificate_mode, type: :string, default: '0644', desc: 'Mode (permission) of the certificate files on create'
    method_option :version_file, type: :string, required: false, banner: 'PATH', desc: 'Path to save a certificate version for following run (optional)'
    method_option :key_file, type: :string, required: false, banner: 'PATH', desc: 'Path to save a key'
    method_option :fullchain_file, type: :string, required: false , banner: 'PATH', desc: 'Path to save a certficiate and its chain (concatenated)'
    method_option :chain_file, type: :string, required: false , banner: 'PATH', desc: 'Path to save a certificate chain (root and intermediate CA)'
    method_option :certificate_file, type: :string, required: false, banner: 'PATH', desc: 'Path to save a certficiate'
    method_option :atomic, type: :boolean, default: true, desc: 'Enable atomic file update with rename(2)'
    def save(common_name)
      client.save(
        common_name,
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

    desc 'save-pkcs12 COMMON_NAME', 'Save ceriticate and private key to .p12 file'
    method_option :version, type: :string, default: 'current'
    method_option :output, type: :string, required: true, banner: 'PATH', desc: 'Path to output file'
    method_option :mode, type: :string, default: '0600', desc: 'Mode (permission) of the output file on create'
    def save_pkcs12(common_name)
      print 'Passphrase: '
      passphrase = $stdin.noecho { $stdin.gets }.chomp
      print "\nPassphrase (confirm): "
      passphrase2 = $stdin.noecho { $stdin.gets }.chomp
      puts

      raise ArgumentError, "Passphrase doesn't match" if passphrase != passphrase2
      client.save_pkcs12(common_name, version: options[:version], mode: options[:mode], output: options[:output], passphrase: passphrase)
    end

    desc "autorenew [COMMON_NAMES]", "request renewal of certificates which expires soon"
    method_option :days, type: :numeric, aliases: %w(-d), default: 7, desc: 'specify threshold in days to select certificates to renew'
    def autorenew(*common_names)
      client.autorenew(days: options[:days], common_names: common_names.empty? ? nil : common_names)
    end

    desc "add-san COMMON_NAME [ADDITIONAL_SANS]", "request renewal of existing certificate with additional SANs"
    def add_san(common_name, *add_sans)
      client.add_san(common_name, *add_sans)
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

    desc "request COMMON_NAME [SAN]", "(deprecated, use 'acmesmith order')"
    method_option :show_certificate, type: :boolean, aliases: %w(-s), default: true, desc: 'show an issued certificate in PEM and text when exiting'
    def request(common_name, *sans)
      warn "!"
      warn "! DEPRECATION WARNING: Use 'acmesmith order' command"
      warn "! There is no user-facing breaking changes. It takes the same arguments with 'acmesmith request'."
      warn "!"
      warn "! This is due to change in semantics of ACME v2. ACME v2 defines 'order' instead of 'request' in v1."
      warn "!"
      order(common_name, *sans)
    end

    private

    def client
      config = Config.load_yaml(options[:config])
      config.merge!("passphrase_from_env" => options[:passphrase_from_env]) unless options[:passphrase_from_env].nil?
      @client = Client.new(config: config)
    end
  end
end
