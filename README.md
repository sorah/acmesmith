# Acmesmith: A simple, effective ACME v2 client to use with many servers and a cloud

![ci](https://github.com/sorah/acmesmith/workflows/ci/badge.svg?event=push)  <a href='https://ko-fi.com/J3J8CKMUU' target='_blank'><img height='36' style='border:0px;height:36px;' src='https://cdn.ko-fi.com/cdn/kofi3.png?v=3' border='0' alt='Buy Me a Coffee at ko-fi.com' /></a>


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

### Docker

```
docker run -v /path/to/acmesmith.yml:/app/acmesmith.yml:ro sorah/acmesmith:latest
```

[`Dockerfile`](./Dockerfile) is available. Default confguration file is at `/app/acmesmith.yml`.

Pre-built docker images are provided at https://hub.docker.com/r/sorah/acmesmith for your convenience
Built with GitHub Actions & [sorah-rbpkg/dockerfiles](https://github.com/sorah-rbpkg/dockerfiles).

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
directory: https://acme-v02.api.letsencrypt.org/directory # production

storage:
  # configure where to store keys and certificates; described later
  type: s3
  region: 'us-east-1'
  bucket: 'my-acmesmith-bucket'
  prefix: 'prod/'

challenge_responders:
  # configure how to respond ACME challenges; described later
  - route53: {}
```

### Storage

Storage provider stores issued certificates, private keys and ACME account keys.

- Amazon S3: [s3](./docs/storages/s3.md)
- Filesystem: [filesystem](./docs/storages/filesystem.md)
- Google Cloud Storage: [minimum2scp/acmesmith-google-cloud-storage](https://github.com/minimum2scp/acmesmith-google-cloud-storage) _(plugin)_

### Challenge Responders

Challenge responders responds to ACME challenges to prove domain ownership to CA.

- API driven
  - AWS Route 53: [route53](./docs/challenge_responders/route53.md) (`dns-01`)
  - Google Cloud DNS: [nagachika/acmesmith-google-cloud-dns](https://github.com/nagachika/acmesmith-google-cloud-dns) (`dns-01`, _plugin_ )
  - OpenStack Designate v1: [hanazuki/acmesmith-designate](https://github.com/hanazuki/acmesmith-designate) (`dns-01`, _plugin_ )
  - Verisign MDNS REST API: [benkap/acmesmith-verisign](https://github.com/benkap/acmesmith-verisign) (`dns-01`, _plugin_ )
- Generic
  - Static HTTP: [mipmip/acmesmith-http-path](https://github.com/mipmip/acmesmith-http-path) (`http-01`, _plugin_ )

#### Common options

```yaml
challenge_responders:
  ## Multiple responders are accepted.
  ## The first responder that supports a challenge and applicable for given domain name will be used.
  - {RESPONDER_TYPE}:
      {RESPONDER_OPTIONS}

    ### Filter (optional)
    filter:
      subject_name_exact:
        - my-app.example.com
      subject_name_suffix:
        - .example.org
      subject_name_regexp:
        - '\Aapp\d+.example.org\z'

  - {RESPONDER_TYPE}:
      {RESPONDER_OPTIONS}
    ...
```

### Post Issuing Hooks

Post issuing hooks are configurable actions that are executed
when a new certificate has been succesfully issued. The hooks are
sequentially executed in the same order as they are configured, and they
are configurable per certificate's common-name.

- Shell script: [shell](./docs/post_issuing_hooks/shell.md)
- Amazon Certificate Manager (ACM): [acm](./docs/post_issuing_hooks/acm.md)

### Chain preference

If you want to prefer an alternative chain given by CA ([RFC8555 Section 7.4.2.](https://datatracker.ietf.org/doc/html/rfc8555#section-7.4.2)), use the following configuration. Preference may be delcared with common name.

When chain preferences are configured for the common name of an ordered certificate, Acmesmith will retrieve all available alternative chains and evaluate rules in an configured order. The first chain matched to a rule will be used and saved to a storage.

During rule evaluation, a root issuer name and key id are taken from the last available intermediate (Issuer and AKI) provided in a chain, when a chain doesn't have a root certificate (trust anchor).

```yaml
chain_preferences:
  - root_issuer_name: "ISRG Root X1"
    ### Optionally, you may specify CA SKI/AKI:
    # root_issuer_key_id: "79:b4:59:e6:7b:b6:e5:e4:01:73:80:08:88:c8:1a:58:f6:e9:9b:6e"

    ### Filter by common name (optional)
    filter:
      exact:
        - my-app.example.com
      suffix:
        - .example.org
      regexp:
        - '\Aapp\d+.example.org\z'
```

## Vendor dependent notes

- [./docs/vendor/aws.md](./docs/vendor/aws.md): IAM and KMS key policies, and some tips

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/sorah/acmesmith.

### Running tests

unit test:

```
bundle exec rspec
```

integration test using [letsencrypt/pebble](https://github.com/letsencrypt/pebble). needs Docker:

```
ACMESMITH_CI_START_PEBBLE=1 CI=1 bundle exec -t integration_pebble
```

## Writing plugins

Publish as a gem (RubyGems). Files will be loaded automatically from `lib/acmesmith/{plugin_type}/{name}.rb`.

e.g.

- storage: `lib/acmesmith/storages/perfect_storage.rb` & `Acmesmith::Storages::PerfectStorage`
- challenge_responder: `lib/acmesmith/challenge_responders/perfect_authority.rb` & `Acmesmith::Storages::PerfectAuthority`
- post_issuing_hook: `lib/acmesmith/challenge_responders/nice_deploy.rb` & `Acmesmith::Storages::NiceDeploy`

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).



## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

