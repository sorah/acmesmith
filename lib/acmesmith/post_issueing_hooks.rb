require 'acmesmith/utils/finder'

module Acmesmith
  module PostIssueingHooks
    def self.find(name)
      Utils::Finder.find(self, 'acmesmith/post_issueing_hooks', name)
    end
  end
end
