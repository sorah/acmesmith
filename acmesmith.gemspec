# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'acmesmith/version'

Gem::Specification.new do |spec|
  spec.name          = "acmesmith-ruby-client"
  spec.version       = Acmesmith::VERSION
  spec.authors       = ["sorah (Shota Fukumori)", "bitsapien (Rahul C)"]
  spec.email         = ["her@sorah.jp"]

  spec.summary       = %q{ACME client (Let's encrypt client) to manage certificate in multi server environment with cloud services (e.g. AWS)}
  spec.description   = <<-EOF
Acmesmith is an [ACME (Automatic Certificate Management Environment)](https://github.com/ietf-wg-acme/acme) client that works perfect on environment with multiple servers. This client saves certificate and keys on cloud services (e.g. AWS S3) securely, then allow to deploy issued certificates onto your servers smoothly. This works well on [Let's encrypt](https://letsencrypt.org).
  EOF
  spec.homepage      = "https://github.com/bitsapien/acmesmith"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "acme-client"
  spec.add_dependency "aws-sdk", "> 2"
  spec.add_dependency "thor"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
end
