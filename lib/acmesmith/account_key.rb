require 'openssl'

module Acmesmith
  class AccountKey
    class PassphraseRequired < StandardError; end

    def self.generate(bit_length = 2048)
      new OpenSSL::PKey::RSA.new(bit_length)
    end

    def initialize(private_key, passphrase = nil)
      case private_key
      when String
        @raw_private_key = private_key
        if passphrase
          self.key_passphrase = passphrase 
        else
          begin
            @private_key = OpenSSL::PKey::RSA.new(@raw_private_key)
          rescue OpenSSL::PKey::RSAError
            # may be encrypted
          end
        end
      when OpenSSL::PKey::RSA
        @private_key = private_key
      else
        raise TypeError, 'private_key is expected to be a String or OpenSSL::PKey::RSA'
      end
    end

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

    def export(passphrase, cipher: OpenSSL::Cipher.new('aes-256-cbc'))
      if passphrase
        private_key.export(cipher, passphrase)
      else
        private_key.export
      end
    end
  end
end
