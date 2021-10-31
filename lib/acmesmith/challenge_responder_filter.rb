require 'acmesmith/domain_name_filter'

module Acmesmith
  class ChallengeResponderFilter
    def initialize(responder, subject_name_exact: nil, subject_name_suffix: nil, subject_name_regexp: nil)
      @responder = responder
      @domain_name_filter = DomainNameFilter.new(
        exact: subject_name_exact,
        suffix: subject_name_suffix,
        regexp: subject_name_regexp,
      )
    end

    def applicable?(domain)
      @domain_name_filter.match?(domain) && @responder.applicable?(domain)
    end
  end
end
