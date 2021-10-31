module Acmesmith
  class DomainNameFilter
    def initialize(exact: nil, suffix: nil, regexp: nil)
      @exact = exact && [*exact].flatten.compact
      @suffix = suffix && [*suffix].flatten.compact
      @regexp = regexp && [*regexp].flatten.compact.map{ |_| Regexp.new(_) }
    end

    def match?(domain)
      if @exact
        return false unless @exact.include?(domain)
      end
      if @suffix
        return false unless @suffix.any? { |suffix| domain.end_with?(suffix) }
      end
      if @regexp
        return false unless @regexp.any? { |regexp| domain.match?(regexp) } 
      end
      true
    end
  end
end
