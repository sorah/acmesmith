require 'openssl'

module Acmesmith
  class Certificate
    class PrivateKeyDecrypted < StandardError; end
    class PassphraseRequired < StandardError; end

    CertificateExport = Struct.new(:certificate, :chain, :fullchain, :private_key, keyword_init: true)

    # Split string containing multiple PEMs into Array of PEM strings.
    # @param [String]
    # @return [Array<String>]
    def self.split_pems(pems)
      pems.each_line.slice_before(/^-----BEGIN CERTIFICATE-----$/).map(&:join)
    end

    # Return Acmesmith::Certificate by an issued certificate
    # @param pem_chain [String]
    # @param csr [Acme::Client::CertificateRequest]
    # @return [Acmesmith::Certificate]
    def self.by_issuance(pem_chain, csr)
      pems = split_pems(pem_chain)
      new(pems[0], pems[1..-1], csr.private_key, nil, csr)
    end

    # @param certificate [OpenSSL::X509::Certificate, String]
    # @param chain [String, Array<String>, Array<OpenSSL::X509::Certificate>]
    # @param private_key [String, OpenSSL::PKey::PKey]
    # @param key_passphrase [String, nil]
    # @param csr [String, OpenSSL::X509::Request, nil]
    def initialize(certificate, chain, private_key, key_passphrase = nil, csr = nil)
      @certificate = case certificate
                     when OpenSSL::X509::Certificate
                       certificate
                     when String
                       OpenSSL::X509::Certificate.new(certificate)
                     else
                        raise TypeError, 'certificate is expected to be a String or OpenSSL::X509::Certificate'
                     end
      chain = case chain
              when String
                self.class.split_pems(chain)
              when Array
                chain
              when nil
                []
              else
                raise TypeError, 'chain is expected to be an Array<String or OpenSSL::X509::Certificate> or nil'
              end

      @chain = chain.map { |cert|
        case cert
        when OpenSSL::X509::Certificate
          cert
        when String
          OpenSSL::X509::Certificate.new(cert)
        else
          raise TypeError, 'chain is expected to be an Array<String or OpenSSL::X509::Certificate> or nil'
        end
      }

      case private_key
      when String
        @raw_private_key = private_key
        if key_passphrase
          self.key_passphrase = key_passphrase
        else
          begin
            @private_key = OpenSSL::PKey.read(@raw_private_key) { nil }
          rescue OpenSSL::PKey::PKeyError
            # may be encrypted
          end
        end
      when OpenSSL::PKey::PKey
        @private_key = private_key
      else
        raise TypeError, 'private_key is expected to be a String or OpenSSL::PKey::PKey'
      end

      @csr = case csr
             when nil
               nil
             when String
               OpenSSL::X509::Request.new(csr)
             when OpenSSL::X509::Request
               csr
             end
    end

    # @return [OpenSSL::X509::Certificate]
    attr_reader :certificate
    # @return [Array<OpenSSL::X509::Certificate>]
    attr_reader :chain
    # @return [OpenSSL::X509::Request]
    attr_reader :csr

    # Try to decrypt private_key if encrypted.
    # @param pw [String] passphrase for encrypted PEM
    # @raise [PrivateKeyDecrypted] if private_key is decrypted
    def key_passphrase=(pw)
      raise PrivateKeyDecrypted, 'private_key already given' if @private_key

      @private_key = OpenSSL::PKey.read(@raw_private_key, pw)

      @raw_private_key = nil
      nil
    end

    # @return [OpenSSL::PKey::PKey]
    # @raise [PassphraseRequired] if private_key is not yet decrypted
    def private_key
      return @private_key if @private_key
      raise PassphraseRequired, 'key_passphrase required'
    end

    # @return [OpenSSL::PKey::PKey]
    def public_key
      @certificate.public_key
    end

    # @return [String] leaf certificate + full certificate chain
    def fullchain
      "#{certificate.to_pem}\n#{issuer_pems}".gsub(/\n+/,?\n)
    end

    # @return [String] issuer certificate chain
    def issuer_pems
      chain.map(&:to_pem).join("\n")
    end

    # @return [String] common name
    def common_name
      certificate.subject.to_a.assoc('CN')[1]
    end

    # @return [Array<String>] Subject Alternative Names (dNSname)
    def sans
      certificate.extensions.select { |_| _.oid == 'subjectAltName' }.flat_map do |ext|
        ext.value.split(/,\s*/).select { |_| _.start_with?('DNS:') }.map { |_| _[4..-1] }
      end
    end

    # @return [String] Version string (consists of NotBefore time & certificate serial)
    def version
      "#{certificate.not_before.utc.strftime('%Y%m%d-%H%M%S')}_#{certificate.serial.to_i.to_s(16)}"
    end

    # @return [OpenSSL::PKCS12]
    def pkcs12(passphrase)
      OpenSSL::PKCS12.create(passphrase, common_name, private_key, certificate, chain)
    end

    # @return [CertificateExport]
    def export(passphrase, cipher: OpenSSL::Cipher.new('aes-256-cbc'))
      CertificateExport.new.tap do |h|
        h.certificate = certificate.to_pem
        h.chain = issuer_pems
        h.fullchain = fullchain
        h.private_key = if passphrase
          private_key.export(cipher, passphrase)
        else
          private_key.export
        end
      end
    end
  end
end
