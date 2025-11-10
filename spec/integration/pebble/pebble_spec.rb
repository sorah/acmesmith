require 'spec_helper'
require 'fileutils'
require 'open-uri'

# https://github.com/letsencrypt/pebble/

class PebbleRunner
  def self.start
    @pebble = spawn(*%w(docker run --net=host --rm ghcr.io/letsencrypt/pebble:2.8 -config /test/config/pebble-config.json -strict -dnsserver 127.0.0.1:8053))
    @challtestsrv = spawn(*%w(docker run --net=host --rm ghcr.io/letsencrypt/pebble-challtestsrv:2.8 -management :8055 -defaultIPv4 127.0.0.1))
  end

  def self.wait
    begin
      TCPSocket.open('localhost', 14000) do
      end
    rescue => e 
      puts "waiting pebble: #{e}"
      sleep 1
      retry
    end

    begin
      TCPSocket.open('localhost', 8055) do
      end
    rescue => e 
      puts "waiting challtestsrv: #{e}"
      sleep 1
      retry
    end
  end

  def self.stop
    [@pebble, @challtestsrv].each do |pid|
      next unless pid
      Process.kill :TERM, pid
    rescue Errno::ESRCH, Errno::ECHILD
    end
  end
end

RSpec.describe "Integration with Pebble", integration_pebble: true do
  PEBBLE_CONFIG = File.join(__dir__, 'integration_spec_config.yml')

  def cmd(*args)
    ['bin/acmesmith', args.first, '-c', PEBBLE_CONFIG, *args[1..-1]]
  end

  before(:all) do
    FileUtils.rm_rf('./tmp/integration-pebble')
    FileUtils.mkdir_p('./tmp/integration-pebble')

    unless File.exist?('./tmp/pebble.minica.crt')
      File.write './tmp/pebble.minica.crt', URI.open('https://raw.githubusercontent.com/letsencrypt/pebble/refs/tags/v2.8.0/test/certs/pebble.minica.pem', 'r', &:read)
    end

    PebbleRunner.start if ENV['ACMESMITH_CI_START_PEBBLE']
    PebbleRunner.wait
    sleep 5

    system(*cmd("new-account",  "mailto:pebble@example.com"), exception: true)
    system(*cmd("order", "test.invalid"), exception: true)
    system(*cmd("add-san", "test.invalid", "san.invalid"), exception: true)
  end

  it "creates account file" do
    expect { OpenSSL::PKey::RSA.new(File.read('tmp/integration-pebble/account.pem'), '') }.not_to raise_error
  end

  context "test.invalid show-private-key:" do
    it "works" do
      private_key = OpenSSL::PKey::RSA.new(IO.popen(cmd("show-private-key", "test.invalid"), 'r', &:read), '')
      certificate = OpenSSL::X509::Certificate.new(IO.popen(cmd("show-certificate", "--type=certificate", "test.invalid")))
      expect(private_key.public_key.to_pem).to eq(certificate.public_key.to_pem)
    end
  end

  context "test.invalid current:" do
    it "acmesmith current works" do
      current = IO.popen(cmd("current", "test.invalid"), 'r', &:read)
      version_pem = IO.popen(cmd("show-certificate", "--type=fullchain", "--version=#{current.chomp}", "test.invalid"), 'r', &:read)
      current_pem = IO.popen(cmd("show-certificate", "--type=fullchain", "test.invalid"), 'r', &:read)
      expect(version_pem).to eq(current_pem)
    end
  end

  context "test.invalid add-san:" do
    it "works" do
      versions = IO.popen(cmd("list", "test.invalid"), 'r', &:read)
      expect(versions.each_line.count).to eq(2)
      
      first = IO.popen(cmd("show-certificate", "--version=#{versions.lines.sort[0]}", "--type=certificate", "test.invalid"), 'r', &:read)
      current = IO.popen(cmd("show-certificate", "--type=certificate", "test.invalid"), 'r', &:read)

      first_san = OpenSSL::X509::Certificate.new(first).extensions.select { |_| _.oid == 'subjectAltName' }.flat_map do |ext|
        ext.value.split(/,\s*/).select { |_| _.start_with?('DNS:') }.map { |_| _[4..-1] }
      end
      current_san = OpenSSL::X509::Certificate.new(current).extensions.select { |_| _.oid == 'subjectAltName' }.flat_map do |ext|
        ext.value.split(/,\s*/).select { |_| _.start_with?('DNS:') }.map { |_| _[4..-1] }
      end

      expect(first_san).not_to include('san.invalid')
      expect(current_san).to include('san.invalid')
    end
  end

  context "EC key" do
    it "works" do
      system(*cmd("order", "ecdsa.invalid", "--key-type", "ec", "--elliptic-curve", "prime256v1"), exception: true)

      certificate = OpenSSL::X509::Certificate.new(IO.popen(cmd("show-certificate", "--type=certificate", "ecdsa.invalid")))
      expect(certificate.public_key.group.curve_name).to eq "prime256v1"

      system(*cmd("add-san", "ecdsa.invalid", "san.invalid"), exception: true)

      certificate = OpenSSL::X509::Certificate.new(IO.popen(cmd("show-certificate", "--type=certificate", "ecdsa.invalid")))
      expect(certificate.public_key.group.curve_name).to eq "prime256v1"  # new cert has the same curve
    end
  end

  context "RSA3072 key" do
    it "works" do
      system(*cmd("order", "rsa3072.invalid", "--key-type", "rsa", "--rsa-key-size", "3072"), exception: true)

      certificate = OpenSSL::X509::Certificate.new(IO.popen(cmd("show-certificate", "--type=certificate", "rsa3072.invalid")))
      expect(certificate.public_key.n.num_bits).to eq 3072

      system(*cmd("add-san", "rsa3072.invalid", "san.invalid"), exception: true)

      certificate = OpenSSL::X509::Certificate.new(IO.popen(cmd("show-certificate", "--type=certificate", "rsa3072.invalid")))
      expect(certificate.public_key.n.num_bits).to eq 3072  # new cert has the same key length
    end
  end

  context "post_issue_hooks" do
    it "works" do
      system(*cmd("order", "flag.invalid"), exception: true)
      expect(File.exist?('tmp/integration-pebble/flag-flag.invalid')).to eq(true)
    end
  end

  after(:all) do
    PebbleRunner.stop
  end

end
