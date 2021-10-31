require 'acmesmith/certificate'

module Acmesmith
  class CertificateRetrievingService
    # @param acme [Acme::Client]
    # @param common_name [String]
    # @param url [String] ACME Certificate URL
    # @param chain_preferences [Array<Acmesmith::Config::ChainPreference>]
    def initialize(acme, common_name, url, chain_preferences: [])
      @acme = acme
      @url = url
      @chain_preferences = chain_preferences.select { |_| _.filter.match?(common_name) }
    end

    attr_reader :acme
    attr_reader :url
    attr_reader :chain_preferences

    def pem_chain
      response = download(url, format: :pem)
      pem = response.body

      return pem if chain_preferences.empty?

      puts " * Retrieving all chains..."
      alternative_urls = Array(response.headers.dig('link', 'alternate'))
      alternative_chains = alternative_urls.map { |_| CertificateChain.new(download(_, format: :pem).body) }

      chains = [CertificateChain.new(pem), *alternative_chains]

      chains.each_with_index do |chain, i|
        File.write "/tmp/acme-chain.#{i}.pem", chain.pem_chain
        puts "   #{i.succ}. #{chain.to_s}"
      end
      puts

      chain_preferences.each do |rule|
        chains.each_with_index do |chain, i|
          if chain.match?(name: rule.root_issuer_name, key_id: rule.root_issuer_key_id)
            puts " * Chain chosen: ##{i.succ}"
            return chain.pem_chain
          end
        end
      end

      warn " ! Preferred chain is not available, chain chosen: #1"
      chains.first.pem_chain
    end

    class CertificateChain
      def initialize(pem_chain)
        @pem_chain = pem_chain
        @pems = Certificate.split_pems(pem_chain)
        @certificates = @pems.map { |_| OpenSSL::X509::Certificate.new(_) }
      end

      attr_reader :pem_chain
      attr_reader :certificates

      def to_s
        certificates[1..-1].map do |c|
          "s:#{c.subject},i:#{c.issuer}"
        end.join(" | ")
      end

      def match?(name: nil, key_id: nil)
        has_root = top.issuer == top.subject

        if name
          return false unless name == (has_root ? top.subject : top.issuer).to_a.assoc('CN')[1]
        end

        if key_id
          top_key_id = if has_root
            top.extensions.find { |e| e.oid == 'subjectKeyIdentifier' }.value
          else
            top.extensions.find { |e| e.oid == 'authorityKeyIdentifier' }.value&.each_line&.grep(/^keyid:/)&.first&.yield_self { |v| v[6..-1] }&.chomp
          end
          return false unless key_id.downcase == top_key_id.downcase
        end

        true
      end

      def top
        @top ||= find_top()
      end

      private def find_top
        c = certificates.first
        while c
          up = find_issuer(c)
          return c unless up
          c = up
        end
      end

      private def find_issuer(cert)
        return nil if cert.issuer == cert.subject

        aki = cert.extensions.find { |e| e.oid == 'authorityKeyIdentifier' }.value&.each_line&.grep(/^keyid:/)&.first&.yield_self { |v| v[6..-1] }&.chomp
        certificates.find do |c|
          ski = c.extensions.find { |e| e.oid == 'subjectKeyIdentifier' }.value
          ski == aki && cert.issuer == c.subject
        end
      end
    end

    private def download(url, format:)
      # XXX: Use of private API https://github.com/unixcharles/acme-client/blob/5990b3105569a9d791ea011e0c5e57506eb54353/lib/acme/client.rb#L311
      acme.__send__(:download, url, format: format)
    end
  end
end
