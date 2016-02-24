# Acmesmith: An effective ACME client to operate on multiple servers environment with the cloud

Acmesmith is an [ACME (Automatic Certificate Management Environment)](https://github.com/ietf-wg-acme/acme) client that works perfect on environment with multiple servers. This client saves certificate and keys on cloud services (e.g. AWS S3) securely, then allow to deploy issued certificates onto your servers smoothly. This works well on [Let's encrypt](https://letsencrypt.org).

This tool is written in Ruby, but this saves certificates in simple scheme, so you can fetch certificate by your own simple scripts.

## Features

- ACME client designed to work on multiple servers
- ACME registration, domain authorization, certificate requests 
  - Tested against [Let's encrypt](https://letsencrypt.org)
- Storing keys in several ways
  - Currently AWS S3 is supported
- Challenge response
  - Currently `dns-01` with AWS Route 53 is supported

### Planned

- Automated deployments support (post issurance hook)
- Example shellscripts to fetch certificates

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'acmesmith'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install acmesmith

## Usage

```
$ acmesmith register CONTACT              # Create account key (contact e.g. mailto:xxx@example.org)
```

```
$ acmesmith authorize DOMAIN              # Get authz for DOMAIN.
$ acmesmith request COMMON_NAME [SAN]     # request certificate for CN +COMMON_NAME+ with SANs +SAN+
$ acmesmith add-san COMMON_NAME [SAN]     # re-request existing certificate of CN with additional SAN(s)
```

```
$ acmesmith list [COMMON_NAME]                          # list certificates or its versions
$ acmesmith current COMMON_NAME                         # show current version for certificate
$ acmesmith show-certificate COMMON_NAME                # show certificate
$ acmesmith show-private-key COMMON_NAME                # show private key
$ acmesmith save-certificate COMMON_NAME --output=PATH  # Save certificate to a file
$ acmesmith save-private-key COMMON_NAME --output=PATH  # Save private key to a file
```

```
$ acmesmith autorenew [-d DAYS] # Renew certificates which being expired soon
```

See `acmesmith help [subcommand]` for more help.

## Configuration

See [config.sample.yml](./config.sample.yml) to start. Default configuration file is `./acmesmith.yml`.

``` yaml
endpoint: https://acme-staging.api.letsencrypt.org/
# endpoint: https://acme-v01.api.letsencrypt.org/ # productilon

storage:
  # configure where to store keys and certificates; described later
challenge_responders:
  # configure how to respond ACME challenges; described later

account_key_passphrase: password
certificate_key_passphrase: secret
```

### Storage

#### S3

```
storage:
  type: s3
  region:
  bucket:
  # prefix:
  # aws_access_key: # aws credentials (optional); If omit, default configuration of aws-sdk use will be used.
  #   access_key_id:
  #   secret_access_key:
  #   session_token:
  # use_kms: true
  # kms_key_id: # KMS key id (optional); if omit, default AWS managed key for S3 will be used
  # kms_key_id_account: # KMS key id for account key (optional); This overrides kms_key_id
  # kms_key_id_certificate_key: # KMS key id for private keys for certificates (optional); This oveerides kms_key_id
```

This saves certificates and keys in the following S3 keys:

- `{prefix}/account.pem`: Account private key in pem
- `{prefix}/certs/{common_name}/current`: text file contains current version name
- `{prefix}/certs/{common_name}/{version}/cert.pem`: certificate in pem
- `{prefix}/certs/{common_name}/{version}/key.pem`: private key in pem
- `{prefix}/certs/{common_name}/{version}/chain.pem`: CA chain in pem
- `{prefix}/certs/{common_name}/{version}/fullchain.pem`: certificate + CA chain in pem. This is suitable for some server softwares like nginx.

#### Filesystem

This is not recommended. If you're planning to use this, make sure backing up the keys.

```
storage:
  type: filesystem
  path: /path/to/directory/to/store/keys
```

### Challenge Responders

Challenge responders responds to ACME challenges to prove domain ownership to CA.

#### Route53

Route53 responder supports `dns-01` challenge type. This assumes domain NS are managed under Route53 hosted zone.

```
challenge_responders:
  - route53:
      # aws_access_key: # aws credentials (optional); If omit, default configuration of aws-sdk use will be used.
      #   access_key_id:
      #   secret_access_key:
      #   session_token:
      # hosted_zone_map: # hosted zone map (optional); This is to specify exactly one hosted zone to use. This will be required when there are multiple hosted zone with same domain name. Usually
      #   "example.org.": "/hostedzone/DEADBEEF"
```

## Vendor dependent notes

### AWS

#### IAM policy

##### All access (S3 + Route53 setup)

``` json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:ListBucket"],
      "Resource": ["arn:aws:s3:::{BUCKET-NAME}", "arn:aws:s3:::{BUCKET-NAME}/*"]
    },
    {
      "Effect": "Allow",
      "Action": ["route53:ListHostedZones", "route53:GetChange"],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "route53:ChangeResourceRecordSets",
      "Resource": ["arn:aws:route53:::hostedzone/*"]
    }
  ]
}
```

Note: You can limit allowed hosted zone by modifying `Resource` of `route53:ChangeResourceRecordSets`

##### Only fetching certificates

``` json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject"],
      "Resource": ["arn:aws:s3:::{BUCKET-NAME}/certs/*"]
    },
    {
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": ["arn:aws:s3:::{BUCKET-NAME}"],
      "Condition": {
        "StringEquals": {
          "s3:delimiter": "/"
        },
        "StringLike": {
          "s3:prefix": "certs/*",
        }
      }
    }
  ]
}
```

#### AWS KMS key policy for customer managed keys

If you're going to use `aws_kms_id` option to use customer managed keys instead of AWS managed default KMS key for Amazon S3, use the following policy as base:

Be sure to replace `{S3-REGION}` and `{YOUR-AWS-ACCOUNT-ID}` before applying it.

``` json
{
  "Version": "2012-10-17",
  "Id": "kms-acmesmith-s3-policy",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "*"
      },
      "Action": [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "kms:ViaService": "s3.{S3-REGION}.amazonaws.com",
          "kms:CallerAccount": "{YOUR-AWS-ACCOUNT-ID}"
        }
      }
    },
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::{YOUR-AWS-ACCOUNT-ID}:root"
      },
      "Action": [
        "kms:Describe*",
        "kms:Get*",
        "kms:List*",
        "kms:Put*"
      ],
      "Resource": "*"
    }
  ]
}
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

### Todos

- Tests
- Support post actions (notifying servers, deploying to somewhere, etc...)

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/acmesmith.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

