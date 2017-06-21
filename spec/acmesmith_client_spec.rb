require 'spec_helper'

describe Acmesmith do
  it 'has a version number' do
    expect(Acmesmith::VERSION).not_to be nil
  end

  it 'should execute when no hooks are defined' do
    acmesmith_client = Acmesmith::Client.new(config: Acmesmith::Config.load_yaml('spec/config.no_hooks.mock.yml'))
    expect { acmesmith_client.post_issue_hooks("admin.example.com") }.to_not raise_error
  end

  it 'should merge and execute post issueing hooks' do
    acmesmith_client = Acmesmith::Client.new(config: Acmesmith::Config.load_yaml('spec/config.mock.yml'))
    acmesmith_client.post_issue_hooks("admin.example.com")
    content = File.read("/tmp/step003-admin.example.com")
    expect(content).to eq("admin.example.com\n")
  end

  it 'should fail and raise for allow.no.failing.example.com' do
    acmesmith_client = Acmesmith::Client.new(config: Acmesmith::Config.load_yaml('spec/config.mock.yml'))
    expect { acmesmith_client.post_issue_hooks("allow.no.failing.example.com") }.to raise_error
  end

end
