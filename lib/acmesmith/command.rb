require 'thor'

require 'acmesmith/client'

module Acmesmith
  class Command < Thor
    class_option :config, default: './acmesmith.yml', aliases: %w(-c)
    class_option :passphrase_from_env,  type: :boolean, aliases: %w(-E), default: false, desc: 'Read $ACMESMITH_ACCOUNT_KEY_PASSPHRASE and $ACMESMITH_CERTIFICATE_KEY_PASSPHRASE for passphrases'

    desc "register CONTACT", "Create account key (contact e.g. mailto:xxx@example.org)"
    def register(contact)
      key = acmesmith_client.register(contact)
      puts "Generated:\n#{key.private_key.public_key.to_pem}"
    end

    desc "authorize DOMAIN [DOMAIN ...]", "Get authz for DOMAIN."
    def authorize(*domains)
      acmesmith_client.authorize(*domains)
    end

    desc "request COMMON_NAME [SAN]", "request certificate for CN +COMMON_NAME+ with SANs +SAN+"
    def request(common_name, *sans)
      cert = acmesmith_client.request(common_name, *sans)
      puts cert.certificate.to_text
      puts cert.certificate.to_pem
    end

    desc "post-issue-hooks COMMON_NAME", "Run all post-issueing hooks for common name. (for testing purpose)"
    def post_issue_hooks(common_name)
      acmesmith_client.post_issue_hooks(common_name)
    end
    map 'post-issue-hooks' => :post_issue_hooks

    desc "list [COMMON_NAME]", "list certificates or its versions"
    def list(common_name = nil)
      puts acmesmith_client.list(common_name)
    end

    desc "current COMMON_NAME", "show current version for certificate"
    def current(common_name)
      puts acmesmith_client.current(common_name)
    end

    desc "show-certificate COMMON_NAME", "show certificate"
    method_option :version, type: :string, default: 'current'
    method_option :type, type: :string, enum: %w(text certificate chain fullchain), default: 'text'
    def show_certificate(common_name)
      certs = acmesmith_client.show_certificate(common_name, version: options[:version], type: options[:type])
      puts certs
    end
    map 'show-certiticate' => :show_certificate

    desc 'save-certificate COMMON_NAME', 'Save certificate to a file'
    method_option :version, type: :string, default: 'current'
    method_option :output, type: :string, required: true, banner: 'PATH', desc: 'Path to output file'
    method_option :mode, type: :string, default: '0600', desc: 'Mode (permission) of the output file on create'
    def save_certificate(common_name)
      acmesmith_client.save_certificate(common_name, version: options[:version], mode: options[:mode], output: options[:output])
    end

    desc "show-private-key COMMON_NAME", "show private key"
    method_option :version, type: :string, default: 'current'
    def show_private_key(common_name)
      puts acmesmith_client.show_private_key(common_name, version: options[:version])
    end
    map 'show-private-key' => :show_private_key

    desc 'save-private-key COMMON_NAME', 'Save private key to a file'
    method_option :version, type: :string, default: 'current'
    method_option :output, type: :string, required: true, banner: 'PATH', desc: 'Path to output file'
    method_option :mode, type: :string, default: '0600', desc: 'Mode (permission) of the output file on create'
    def save_private_key(common_name)
      acmesmith_client.save_private_key(common_name, version: options[:version], mode: options[:mode], output: options[:output])
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
      acmesmith_client.save_pkcs12(common_name, version: options[:version], mode: options[:mode], output: options[:output], passphrase: passphrase)
    end

    desc "autorenew", "request renewal of certificates which expires soon"
    method_option :days, type: :numeric, aliases: %w(-d), default: 7, desc: 'specify threshold in days to select certificates to renew'
    def autorenew
      acmesmith_client.autorenew(options[:days])
    end

    desc "add-san COMMON_NAME [ADDITIONAL_SANS]", "request renewal of existing certificate with additional SANs"
    def add_san(common_name, *add_sans)
      acmesmith_client.add_san(common_name, *add_sans)
    end

    private

    def acmesmith_client
      config = Config.load_yaml(options[:config])
      config.merge!("passphrase_from_env" => options[:passphrase_from_env]) unless options[:passphrase_from_env].nil?
      @acmesmith_client = Client.new(config: config)
    end
  end
end
