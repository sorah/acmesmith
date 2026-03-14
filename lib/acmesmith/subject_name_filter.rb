require 'acmesmith/domain_name_filter'

module Acmesmith
  class SubjectNameFilter
    def initialize(subject_name_exact: nil, subject_name_suffix: nil, subject_name_regexp: nil)
      @domain_name_filter = DomainNameFilter.new(
        exact: subject_name_exact,
        suffix: subject_name_suffix,
        regexp: subject_name_regexp,
      )
    end

    def match?(domain)
      @domain_name_filter.match?(domain)
    end
  end
end
