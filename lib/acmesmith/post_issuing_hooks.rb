require 'acmesmith/utils/finder'

module Acmesmith
  module PostIssueingHooks
    def self.find(name)
      warn "!! DEPRECATION WARNING: PostIssueingHooks.find is deprecated, use PostIssuingHooks.find (#{caller[0]})"
      return Utils::Finder.find(self, 'acmesmith/post_issueing_hooks', name)
    end
  end

  module PostIssuingHooks
    def self.find(name)
      begin 
        return Utils::Finder.find(self, 'acmesmith/post_issuing_hooks', name)
      rescue Utils::Finder::NotFound => e
        begin
          klass = Utils::Finder.find(PostIssueingHooks, 'acmesmith/post_issueing_hooks', name)
          warn "!! DEPRECATION WARNING (#{klass}): Placing in acmesmith/post_issueing_hooks/... is deprecated. Move to acmesmith/post_issuing_hooks/..."
          return klass
        rescue Utils::Finder::NotFound
          raise e
        end
      end
    end
  end
end
