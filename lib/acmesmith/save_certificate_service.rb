module Acmesmith
  class SaveCertificateService
    def initialize(cert, key_mode: '0600', certificate_mode: '0644', version_file: nil, key_file: nil, fullchain_file: nil, chain_file: nil, certificate_file: nil, atomic: true, verbose: false)
      @cert = cert
      @key_mode = key_mode
      @certificate_mode = certificate_mode
      @version_file = version_file
      @key_file = key_file
      @fullchain_file = fullchain_file
      @chain_file = chain_file
      @certificate_file = certificate_file
      @atomic = atomic
      @verbose = verbose
    end

    attr_reader :cert
    attr_reader :key_mode, :certificate_mode
    attr_reader :version_file, :key_file, :fullchain_file, :chain_file, :certificate_file
    def atomic?; !!@atomic; end

    def perform!
      if local_version == cert.version
        return
      end

      log "Saving certificate #{cert.name.inspect} (ver: #{cert.version})"

      write_file(key_file, key_mode, cert.private_key)
      write_file(certificate_file, certificate_mode, cert.certificate.to_pem)
      write_file(chain_file, certificate_mode, cert.chain)
      write_file(fullchain_file, certificate_mode, cert.fullchain)
      write_file(version_file, certificate_mode, cert.version)
    end

    def local_version
      @local_version ||= begin
        if version_file && File.exist?(version_file)
          File.read(version_file).chomp
        else
          nil
        end
      end
    end

    private

    def log(*args)
      if @verbose
        puts *args
      end
    end

    def write_file(path, mode, body)
      return unless path
      realpath = atomic? ? "#{path}.new" : path
      File.open(realpath, 'w', mode.to_i(8)) do |io|
        io.puts body
      end
      if atomic?
        File.rename realpath, path
      end
    end
  end
end
