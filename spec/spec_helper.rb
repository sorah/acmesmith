$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'acmesmith/config'
RSpec::Expectations.configuration.on_potential_false_positives = :nothing
