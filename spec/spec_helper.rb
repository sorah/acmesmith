$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'acmesmith/config'
require 'openssl'

ENV['AWS_ACCESS_KEY_ID'] = 'dummy'
ENV['AWS_SECRET_ACCESS_KEY'] = 'dummy'
ENV['AWS_SESSION_TOKEN'] = 'dummy'

PASSPHRASE = 'tonymoris'

PEM_LEAF = File.read(File.join(__dir__, 'leaf.pem'))
LEAF = OpenSSL::X509::Certificate.new(PEM_LEAF)

PEM_CHAIN = File.read(File.join(__dir__, 'chain.pem'))
CHAIN = PEM_CHAIN.each_line.slice_before(/^-----BEGIN CERTIFICATE-----$/).map(&:join).map { |_| OpenSSL::X509::Certificate.new(_) }

PRIVATE_KEY = OpenSSL::PKey::RSA.generate(1024) # don't use 1024 in wild
PRIVATE_KEY_PEM = PRIVATE_KEY.export
PRIVATE_KEY_PEM_ENCRYPTED = PRIVATE_KEY.export(OpenSSL::Cipher.new('aes-256-cbc'), PASSPHRASE)

RSpec.configure do |c|
  c.filter_run_excluding :integration_pebble
end
