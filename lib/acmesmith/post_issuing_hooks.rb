require 'acmesmith/utils/finder'

module Acmesmith
  module PostIssuingHooks
    def self.find(name)
      Utils::Finder.find(self, 'acmesmith/post_issuing_hooks', name)
    end
  end
end
