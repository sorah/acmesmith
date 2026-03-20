require 'ipaddr'

module Acmesmith
  class IpAddressFilter
    def initialize(cidr: nil)
      @cidr = cidr && [*cidr].flatten.compact.map { |_| IPAddr.new(_) }
    end

    def match?(ipaddr)
      begin
        ipaddr = IPAddr.new(ipaddr)
      rescue IPAddr::InvalidAddressError
        return false
      end

      if @cidr
        return false unless @cidr.any? { |_| _.include?(ipaddr) }
      end

      true
    end
  end
end
