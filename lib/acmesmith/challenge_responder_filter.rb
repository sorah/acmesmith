require 'acmesmith/subject_name_filter'

module Acmesmith
  class ChallengeResponderFilter
    def initialize(responder, **filter)
      @responder = responder
      @subject_name_filter = SubjectNameFilter.new(**filter)
    end

    def applicable?(domain)
      @subject_name_filter.match?(domain) && @responder.applicable?(domain)
    end
  end
end
