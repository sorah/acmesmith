require 'acmesmith/post_issuing_hooks/base'

warn "!! DEPRECATION WARNING: PostIssueingHooks::Base is deprecated, use PostIssuingHooks::Base (#{caller[0]})"

module Acmesmith
  module PostIssueingHooks
    Base = PostIssuingHooks::Base
  end
end
