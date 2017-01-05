require 'acmesmith/config'
require 'spec_helper'

describe Acmesmith do
  it 'has a version number' do
    expect(Acmesmith::VERSION).not_to be nil
  end

  it 'should display help' do
    args = ["help"]
    expect { Acmesmith::Command.start(args) }.to output(/Commands:/).to_stdout
    expect { Acmesmith::Command.start(args) }.to output(/authz/).to_stdout
  end

  it 'should execute when no hooks are defines' do
    args = ["post_issue_hooks", "admin.example.com", '-c', 'spec/config.no_hooks.mock.yml']
    expect { Acmesmith::Command.start(args) }.to output(//).to_stdout
  end

  it 'should merge and execute post issueing hooks' do
    args = ["post_issue_hooks", "admin.example.com", '-c', 'spec/config.mock.yml']
    expect { Acmesmith::Command.start(args) }.to output(/Running: echo \$COMMON_NAME > \/tmp\/step003-/).to_stdout
    content = File.read("/tmp/step003-admin.example.com")
    expect(content).to eq("admin.example.com\n")
  end

  it 'should fail and raise for allow.no.failing.example.com' do
    args = ["post_issue_hooks", "allow.no.failing.example.com", '-c', 'spec/config.mock.yml']
    expect { Acmesmith::Command.start(args) }.to raise_error(/FATAL/)
  end

  it 'should fail and continue for allow.failing.example.com' do
    args = ["post_issue_hooks", "allow.failing.example.com", '-c', 'spec/config.mock.yml']
    expect { Acmesmith::Command.start(args) }.to output(/WARNING/).to_stderr
  end

end
