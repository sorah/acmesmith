# frozen_string_literal: true
require_relative 'lib/acmesmith/version'

Gem::Specification.new do |spec|
  spec.name          = "acmesmith"
  spec.version       = Acmesmith::VERSION
  spec.authors       = ["Sorah Fukumori"]
  spec.email         = ["her@sorah.jp"]

  spec.summary       = %q{ACME client (Let's encrypt client) to manage certificate in multi server environment with cloud services (e.g. AWS)}
  spec.description   = <<-EOF
Acmesmith is an [ACME (Automatic Certificate Management Environment)](https://github.com/ietf-wg-acme/acme) client that works perfect on environment with multiple servers. This client saves certificate and keys on cloud services (e.g. AWS S3) securely, then allow to deploy issued certificates onto your servers smoothly. This works well on [Let's encrypt](https://letsencrypt.org).
  EOF
  spec.homepage      = "https://github.com/sorah/acmesmith"
  spec.license       = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/sorah/acmesmith"
  spec.metadata["changelog_uri"] = "https://github.com/sorah/acmesmith/blob/master/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[script/ Gemfile .gitignore .rspec spec/ .github/])
    end
  end
  spec.bindir = "bin"
  spec.executables = spec.files.grep(%r{\Abin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "acme-client", '>= 2.0.7', '< 3'
  spec.add_dependency "aws-sdk-acm"
  spec.add_dependency "aws-sdk-route53"
  spec.add_dependency "aws-sdk-s3"
  spec.add_dependency "thor"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
end
