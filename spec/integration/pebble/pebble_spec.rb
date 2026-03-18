require 'spec_helper'
require 'fileutils'
require 'open-uri'

# https://github.com/letsencrypt/pebble/

class PebbleRunner
  def self.start
    @pebble = spawn(*%w(docker run --net=host --rm ghcr.io/letsencrypt/pebble:2.10 -config /test/config/pebble-config.json -strict -dnsserver 127.0.0.1:8053))
    @challtestsrv = spawn(*%w(docker run --net=host --rm ghcr.io/letsencrypt/pebble-challtestsrv:2.10 -management :8055 -defaultIPv4 127.0.0.1))
  end

  def self.wait
    ENV['ACMESMITH_ACKNOWLEDGE_PEBBLE_CHALLTESTSRV_IS_INSECURE'] = '1'  # avoid warning message
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

  def ip_sans_from_cert(pem)
    OpenSSL::X509::Certificate.new(pem)
      .extensions
      .select { |_| _.oid == 'subjectAltName' }
      .flat_map { |_| _.value.split(/,\s*/) }
      .filter_map { |_| _[11..] if _.start_with?('IP Address:') }
  end

  def dns_sans_from_cert(pem)
    OpenSSL::X509::Certificate.new(pem)
      .extensions
      .select { |_| _.oid == 'subjectAltName' }
      .flat_map { |_| _.value.split(/,\s*/) }
      .filter_map { |_| _[4..] if _.start_with?('DNS:') }
  end

  def cmd(*args)
    ['bin/acmesmith', args.first, '-c', PEBBLE_CONFIG, *args[1..-1]]
  end

  before(:all) do
    FileUtils.rm_rf('./tmp/integration-pebble')
    FileUtils.mkdir_p('./tmp/integration-pebble')

    unless File.exist?('./tmp/pebble.minica.crt')
      File.write './tmp/pebble.minica.crt', URI.open('https://raw.githubusercontent.com/letsencrypt/pebble/refs/tags/v2.10.0/test/certs/pebble.minica.pem', 'r', &:read)
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

  context "list-profiles" do
    it "succeeds" do
      output = IO.popen(cmd("list-profiles"), 'r', &:read)
      expect($?.success?).to eq(true)
      # Pebble may or may not expose profiles; just verify the command runs
    end
  end

  context "order with profile" do
    it "issues a shorter-lived certificate when matching shortlived profile" do
      system(*cmd("order", "test.shortlived.invalid"), exception: true)
      system(*cmd("order", "test.default.invalid"), exception: true)

      shortlived_cert = OpenSSL::X509::Certificate.new(IO.popen(cmd("show-certificate", "--type=certificate", "test.shortlived.invalid")))
      default_cert = OpenSSL::X509::Certificate.new(IO.popen(cmd("show-certificate", "--type=certificate", "test.default.invalid")))

      shortlived_lifetime = shortlived_cert.not_after - shortlived_cert.not_before
      default_lifetime = default_cert.not_after - default_cert.not_before
      expect(shortlived_lifetime).to be < default_lifetime
    end
  end

  context "post_issue_hooks" do
    it "works" do
      system(*cmd("order", "flag.invalid"), exception: true)
      expect(File.exist?('tmp/integration-pebble/flag-flag.invalid')).to eq(true)
    end
  end

  context 'IP SAN certificate' do
    it 'issues a certificate with an IP SAN' do
      system(*cmd('order', 'ipsan.invalid', '127.0.0.1'), exception: true)

      pem = IO.popen(cmd('show-certificate', '--type=certificate', 'ipsan.invalid'), 'r', &:read)
      expect(ip_sans_from_cert(pem)).to contain_exactly('127.0.0.1')
      expect(dns_sans_from_cert(pem)).to contain_exactly('ipsan.invalid')
    end

    it 'preserves the IP SAN through add-san DNS' do
      system(*cmd('order', 'ipsan-add-dns.invalid', '127.0.0.1', '::1'), exception: true)

      system(*cmd('add-san', 'ipsan-add-dns.invalid', 'another.invalid'), exception: true)
      pem = IO.popen(cmd('show-certificate', '--type=certificate', 'ipsan-add-dns.invalid'), 'r', &:read)
      expect(ip_sans_from_cert(pem)).to contain_exactly('127.0.0.1', '0:0:0:0:0:0:0:1')
      expect(dns_sans_from_cert(pem)).to contain_exactly('ipsan-add-dns.invalid', 'another.invalid')
    end

    it 'preserves the IP SAN through add-san IP' do
      system(*cmd('order', 'ipsan-add-ip.invalid', '127.0.0.1'), exception: true)

      system(*cmd('add-san', 'ipsan-add-ip.invalid', '127.0.0.2', '::1'), exception: true)
      pem = IO.popen(cmd('show-certificate', '--type=certificate', 'ipsan-add-ip.invalid'), 'r', &:read)
      expect(ip_sans_from_cert(pem)).to contain_exactly('127.0.0.1', '127.0.0.2', '0:0:0:0:0:0:0:1')
      expect(dns_sans_from_cert(pem)).to contain_exactly('ipsan-add-ip.invalid')
    end

    it 'preserves the SANs through autorenew' do
      system(*cmd('order', 'ipsan-autorenew.invalid', '127.0.0.1'), exception: true)

      system(*cmd('autorenew', 'ipsan-autorenew.invalid', '--days', '9999'), exception: true)
      pem = IO.popen(cmd('show-certificate', '--type=certificate', 'ipsan-autorenew.invalid'), 'r', &:read)
      expect(ip_sans_from_cert(pem)).to contain_exactly('127.0.0.1')
      expect(dns_sans_from_cert(pem)).to contain_exactly('ipsan-autorenew.invalid')
    end
  end

  after(:all) do
    PebbleRunner.stop
  end

end
