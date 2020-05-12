module Acmesmith
  class ChallengeResponderFilter
    def initialize(responder, subject_name_exact: nil, subject_name_suffix: nil, subject_name_regexp: nil)
      @responder = responder
      @subject_name_exact = subject_name_exact && [*subject_name_exact].flatten.compact
      @subject_name_suffix = subject_name_suffix && [*subject_name_suffix].flatten.compact
      @subject_name_regexp = subject_name_regexp && [*subject_name_regexp].flatten.compact.map{ |_| Regexp.new(_) }
    end

    def applicable?(domain)
      if @subject_name_exact
        return false unless @subject_name_exact.include?(domain)
      end
      if @subject_name_suffix
        return false unless @subject_name_suffix.any? { |suffix| domain.end_with?(suffix) }
      end
      if @subject_name_regexp
        return false unless @subject_name_regexp.any? { |regexp| domain.match?(regexp) } 
      end
      @responder.applicable?(domain)
    end
  end
end
