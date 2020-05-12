require 'openssl'

module Acmesmith
  class AccountKey
    class PassphraseRequired < StandardError; end
    class PrivateKeyDecrypted < StandardError; end

    # @param bit_length [Integer]
    # @return [Acmesmith::AccountKey]
    def self.generate(bit_length = 2048)
      new OpenSSL::PKey::RSA.new(bit_length)
    end

    # @param private_key [String, OpenSSL::PKey::RSA]
    # @param passphrase [String, nil]
    def initialize(private_key, passphrase = nil)
      case private_key
      when String
        @raw_private_key = private_key
        if passphrase
          self.key_passphrase = passphrase 
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
    end

    # Try to decrypt private_key if encrypted.
    # @param pw [String] passphrase for encrypted PEM
    # @raise [PrivateKeyDecrypted] if private_key is decrypted
    def key_passphrase=(pw)
      raise PrivateKeyDecrypted, 'private_key already given' if @private_key

      @private_key = OpenSSL::PKey::RSA.new(@raw_private_key, pw)

      @raw_private_key = nil
      nil
    end

    # @return [OpenSSL::PKey::RSA]
    # @raise [PassphraseRequired] if private_key is not yet decrypted
    def private_key
      return @private_key if @private_key
      raise PassphraseRequired, 'key_passphrase required'
    end

    # @return [String] PEM
    def export(passphrase, cipher: OpenSSL::Cipher.new('aes-256-cbc'))
      if passphrase
        private_key.export(cipher, passphrase)
      else
        private_key.export
      end
    end
  end
end
