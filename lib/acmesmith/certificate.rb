require 'openssl'

module Acmesmith
  class Certificate
    class PassphraseRequired < StandardError; end

    def self.split_pems(pems)
      pems.each_line.slice_before(/^-----BEGIN CERTIFICATE-----$/).map(&:join)
    end

    def self.by_issuance(pem_chain, csr)
      pems = split_pems(pem_chain)
      new(pems[0], pems[1..-1], csr.private_key, nil, csr)
    end

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
            @private_key = OpenSSL::PKey::RSA.new(@raw_private_key) { nil }
          rescue OpenSSL::PKey::RSAError
            # may be encrypted
          end
        end
      when OpenSSL::PKey::RSA
        @private_key = private_key
      else
        raise TypeError, 'private_key is expected to be a String or OpenSSL::PKey::RSA'
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

    attr_reader :certificate, :chain, :csr

    def key_passphrase=(pw)
      raise 'private_key already given' if @private_key

      @private_key = OpenSSL::PKey::RSA.new(@raw_private_key, pw)

      @raw_private_key = nil
      nil
    end

    def private_key
      return @private_key if @private_key
      raise PassphraseRequired, 'key_passphrase required'
    end

    def fullchain
      "#{certificate.to_pem}\n#{issuer_pems}".gsub(/\n+/,?\n)
    end

    def issuer_pems
      chain.map(&:to_pem).join("\n")
    end

    def common_name
      certificate.subject.to_a.assoc('CN')[1]
    end

    def sans
      certificate.extensions.select { |_| _.oid == 'subjectAltName' }.flat_map do |ext|
        ext.value.split(/,\s*/).select { |_| _.start_with?('DNS:') }.map { |_| _[4..-1] }
      end
    end

    def version
      "#{certificate.not_before.utc.strftime('%Y%m%d-%H%M%S')}_#{certificate.serial.to_i.to_s(16)}"
    end

    def pkcs12(passphrase)
      OpenSSL::PKCS12.create(passphrase, common_name, private_key, certificate, chain)
    end

    def export(passphrase, cipher: OpenSSL::Cipher.new('aes-256-cbc'))
      {}.tap do |h|
        h[:certificate] = certificate.to_pem
        h[:chain] = issuer_pems
        h[:fullchain] = fullchain

        h[:private_key] = if passphrase
          private_key.export(cipher, passphrase)
        else
          private_key.export
        end
      end
    end
  end
end
