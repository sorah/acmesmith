module Acmesmith
  class ChallengeResponderFilter
    def initialize(responder, domain_name_exact: nil, domain_name_suffix: nil, domain_name_regexp: nil)
      @responder = responder
      @domain_name_exact = domain_name_exact && [*domain_name_exact].flatten.compact
      @domain_name_suffix = domain_name_suffix && [*domain_name_suffix].flatten.compact
      @domain_name_regexp = domain_name_regexp && [*domain_name_regexp].flatten.compact.map{ |_| Regexp.new(_) }
    end

    def applicable?(domain)
      if @domain_name_exact
        return false unless @domain_name_exact.include?(domain)
      end
      if @domain_name_suffix
        return false unless @domain_name_suffix.any? { |suffix| domain.end_with?(suffix) }
      end
      if @domain_name_regexp
        return false unless @domain_name_regexp.any? { |regexp| domain.match?(regexp) } 
      end
      @responder.applicable?(domain)
    end
  end
end
