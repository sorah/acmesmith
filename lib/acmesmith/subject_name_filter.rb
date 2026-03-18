require 'acmesmith/domain_name_filter'
require 'acmesmith/ip_address_filter'

module Acmesmith
  class SubjectNameFilter
    def initialize(subject_name_exact: nil, subject_name_suffix: nil, subject_name_regexp: nil, subject_name_cidr: nil)
      @domain_name_filter = DomainNameFilter.new(
        exact: subject_name_exact,
        suffix: subject_name_suffix,
        regexp: subject_name_regexp,
      ) if subject_name_exact || subject_name_suffix || subject_name_regexp
      @ip_address_filter = IpAddressFilter.new(
        cidr: subject_name_cidr,
      ) if subject_name_cidr
    end

    def match?(name)
      return false if @domain_name_filter && !@domain_name_filter.match?(name)
      return false if @ip_address_filter && !@ip_address_filter.match?(name)
      true
    end
  end
end
