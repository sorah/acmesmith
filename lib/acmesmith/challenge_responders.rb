require 'acmesmith/utils/finder'

module Acmesmith
  module ChallengeResponders
    def self.find(name)
      Utils::Finder.find(self, 'acmesmith/challenge_responders', name)
    end
  end
end
