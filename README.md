# Acmesmith: A simple, effective ACME v2 client to use with many servers and a cloud

Acmesmith is an [ACME (Automatic Certificate Management Environment)](https://github.com/ietf-wg-acme/acme) client that works perfect on environment with multiple servers. This client saves certificate and keys on cloud services (e.g. AWS S3) securely, then allow to deploy issued certificates onto your servers smoothly. This works well on [Let's encrypt](https://letsencrypt.org).

This tool is written in Ruby, but Acmesmith saves certificates in simple scheme, so you can fetch certificate by your own simple scripts.

## Features

- ACME v2 client designed to work on multiple servers
- ACME registration, domain authorization, certificate requests 
  - Tested against [Let's encrypt](https://letsencrypt.org)
- Storing keys in several ways
- Challenge response
- Many cloud services support
  - AWS S3 storage and Route 53 `dns-01` responder support out-of-the-box
  - 3rd party plugins available for OpenStack designate, Google Cloud DNS, simple http-01, and Google Cloud Storage. See [Plugins](#3rd-party-plugins) below

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
$ acmesmith new-account CONTACT              # Create account key (contact e.g. mailto:xxx@example.org)
```

```
$ acmesmith order COMMON_NAME [SAN]     # request certificate for CN +COMMON_NAME+ with SANs +SAN+
$ acmesmith add-san COMMON_NAME [SAN]     # re-request existing certificate of CN with additional SAN(s)
```

```
$ acmesmith list [COMMON_NAME]                          # list certificates or its versions
$ acmesmith current COMMON_NAME                         # show current version for certificate
$ acmesmith show-certificate COMMON_NAME                # show certificate
$ acmesmith show-private-key COMMON_NAME                # show private key
$ acmesmith save-certificate COMMON_NAME --output=PATH  # Save certificate to a file
$ acmesmith save-private-key COMMON_NAME --output=PATH  # Save private key to a file
$ acmesmith save-pkcs12      COMMON_NAME --output=PATH  # Save certificate and private key to a PKCS12 file
```

```
$ acmesmith autorenew [-d DAYS] # Renew certificates which being expired soon
```

```
# Save (or update) certificate files and key in a one command
$ acmesmith save COMMON_NAME \
      --version-file=/tmp/cert.txt   # Path to save a certificate version for following run 
      --key-file=/tmp/cert.key       # Path to save a key
      --fullchain-file=/tmp/cert.pem # Path to save a certficiate and its chain (concatenated)
```

See `acmesmith help [subcommand]` for more help.

## Configuration

See [config.sample.yml](./config.sample.yml) to start. Default configuration file is `./acmesmith.yml`.

``` yaml
directory: https://acme-staging-v02.api.letsencrypt.org/directory
# directory: https://acme-v02.api.letsencrypt.org/directory # production

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
  # pkcs12_passphrase: # (optional) Set passphrase to generate PKCS#12 file (for scripts that reads S3 bucket directly)
  # pkcs12_common_names: ['example.org'] # (optional) List of common names to limit certificates for generating PKCS#12 file.
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

### Post Issuing Hooks

Post issuing hooks are configurable actions that are executed
when a new certificate has been succesfully issued. The hooks are
sequentially executed in the same order as they are configured, and they
are configurable per certificate's common-name.

#### `shell`

Execute specified command on a shell. Environment variable `${COMMON_NAME}` is available.

```
post_issuing_hooks:
  "test.example.com":
    - shell:
        command: mail -s "New cert for ${COMMON_NAME} has been issued" user@example.com < /dev/null
    - shell:
        command: touch /tmp/certs-has-been-issued-${COMMON_NAME}
  "admin.example.com":
    - shell:
        command: /usr/bin/dosomethingelse ${COMMON_NAME}
```

### `acm`

Import certificate into AWS ACM.

```
post_issuing_hooks:
  "test.example.com":
    - acm:
        region: us-east-1 # required
        certificate_arn: arn:aws:acm:... # (optional)
```

When `certificate_arn` is not present, `acm` hook attempts to find the certificate ARN from existing certificate list. Certificate with same common name ("domain name" on ACM), and `Acmesmith` tag
 will be used. Otherwise, `acm` hook imports as a new certificate with `Acmesmith` tag.

## 3rd party Plugins

### Challenge responders

- [hanazuki/acmesmith-designate](https://github.com/hanazuki/acmesmith-designate) `dns-01` challenge responder with OpenStack-based DNSaaS (Designate v1 API), e.g. for ConoHa.
- [nagachika/acmesmith-google-cloud-dns](https://github.com/nagachika/acmesmith-google-cloud-dns) `dns-01` challenge responder with [Google Cloud DNS](https://cloud.google.com/dns/).
- [mipmip/acmesmith-http-path](https://github.com/mipmip/acmesmith-http-path) - `http-01` challenge reponder if you have write access to the vhost server root.
- [benkap/acmesmith-verisign](https://github.com/benkap/acmesmith-verisign) - `dns-01` challenge responder with Verisign MDNS REST API.

### Storage

- [minimum2scp/acmesmith-google-cloud-storage](https://github.com/minimum2scp/acmesmith-google-cloud-storage) storage using [Google Cloud Storage](https://cloud.google.com/storage/)

## Vendor dependent notes

- [./docs/vendor/aws.md](./docs/vendor/aws.md): IAM and KMS key policies, and some tips

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

