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

  it 'should merge and execute post issueing hooks' do

    args = ["post_issue_hooks", "test.example.com", '-c', 'spec/config.mock.yml']
    expect { Acmesmith::Command.start(args) }.to output(/Key for test\.example\.com is issued/).to_stdout

    args = ["post_issue_hooks", "admin.example.com", '-c', 'spec/config.mock.yml']
    expect { Acmesmith::Command.start(args) }.to output(/Running touch \/tmp\/step002-admin\.example\.com/).to_stdout

  end
end
