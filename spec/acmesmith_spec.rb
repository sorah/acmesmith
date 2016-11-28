require 'acmesmith/config'
require 'spec_helper'

describe Acmesmith do
  it 'has a version number' do
    expect(Acmesmith::VERSION).not_to be nil
  end

  it 'display help' do
    args = ["help"]
    opts = {:config => 'spec/config.mock.yml'}

    expect { Acmesmith::Command.start(args,opts)}.to output(/Commands:/).to_stdout
    expect { Acmesmith::Command.start(args,opts)}.to output(/authz/).to_stdout
  end

  it 'execute list' do

    args = ["list"]
    opts = {:config => 'spec/config.mock.yml'}

    cmd =Acmesmith::Command.new
    cmd.execute_post_issue_hooks('test.example.com')


    expect { Acmesmith::Command.start(args,opts)}.to output(/Commands:/).to_stdout
    expect { Acmesmith::Command.start(args,opts)}.to output(/authz/).to_stdout
  end
end
