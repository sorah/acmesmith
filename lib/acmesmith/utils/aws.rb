module Acmesmith
  module Utils
    module Aws
      def self.addClientCredential(opt, aws_access_key=nil, role_arn=nil)
        opt[:credentials] = ::Aws::Credentials.new(aws_access_key['access_key_id'], aws_access_key['secret_access_key'], aws_access_key['session_token']) if aws_access_key
        opt[:credentials] = ::Aws::AssumeRoleCredentials.new(
          client: ::Aws::STS::Client.new(opt),
          role_arn: role_arn,
          role_session_name: "acmesmith"
        ) if role_arn
        opt
      end
    end
  end
end
