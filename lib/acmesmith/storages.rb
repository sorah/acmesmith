require 'acmesmith/utils/finder'

module Acmesmith
  module Storages
    def self.find(name)
      Utils::Finder.find(self, 'acmesmith/storages', name)
    end
  end
end
