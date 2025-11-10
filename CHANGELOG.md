## v2.8.0 (2025-11-11)

### Updates

- Update gemspec to the latest bundler's provided template. This removes certain irrevant files from a released gem package. [#73](https://github.com/sorah/acmesmith/issues/73)
- Use rubygems.org trusted publishing via GitHub Actions [#73](https://github.com/sorah/acmesmith/issues/73)

## v2.7.1 (2025-08-21)

### Bug fixes

- autorenew: Failed when expired certificates were present. [#72](https://github.com/sorah/acmesmith/issues/72)

## v2.7.0 (2025-04-28)

### Enhancements

- autorenew: gains new option `--remaining-life` (`-r`) to specify threshold in ratio of remaining lifetime to total lifetime, e.g. `1/3`, `50%`.

### New behaviour

- autonenew: in addition to above, the default option is now adjusted to `--reamining-life 1/3` instead of `--days 7`. This conforms to the Let's Encrypt recommendation to renew certificates when its remaining lifetime is less than 1/3 of the total lifetime.
- docker: our provided Docker image now bundles rexml instead of nokogiri for aws-sdk-route53.


## v2.6.1 (2024-12-05)

### Fixes

- route53: restore_to_original_records can have an error when querying existing record sets when it generates a name with leading empty labels (OTOH: double leading dots). [#65](https://github.com/sorah/acmesmith/pull/65)

## v2.6.0 (2023-10-05)

### Enhancement

- order: Gains `--key-type`, `--rsa-key-size`, `--elliptic-curve` options to customize private key generation, and generating EC keys. [#58](https://github.com/sorah/acmesmith/pull/58)
- autorenew: Respect the existing key configuration when regenerating a fresh key pair for renewal.  [#58](https://github.com/sorah/acmesmith/pull/58)

## v2.5.0 (2020-10-09)

### Enhancement

- Gains `chain_preferences` configuration to choose alternate chain. [#47](https://github.com/sorah/acmesmith/pull/47)
- route53: Gains `substitution_map` to allow delegation of `_acme-challenge` via predefined CNAME record. [#53](https://github.com/sorah/acmesmith/pull/53)
- s3: Gains `endpoint` option. [#52](https://github.com/sorah/acmesmith/pull/52)

## v2.4.0 (2020-12-03)

### Enhancement

- route53: Gains `restore_to_original_records` option. When enabled, existing record will be restored after authorizing domain names. Useful when other ACME tools or providers using ACME where requires a certain record to remain as long as possible for their renewal process (e.g. Fastly TLS).

## v2.3.1 (2020-05-12)

### Fixes

- Fixing Docker image build has failed for the release tag. https://github.com/sorah/acmesmith/runs/665853406

## v2.3.0 (2020-05-12)

### Enhancement

- route53: Added support of assuming IAM Role to access Route 53. (requested at [#36](https://github.com/sorah/acmesmith/issues/36) [#37](https://github.com/sorah/acmesmith/pull/37) [#38](https://github.com/sorah/acmesmith/issues/36))

- Added filter for challenge responders. This allows selecting a challenge responder for specific domain names. (indirectly requested at [#36](https://github.com/sorah/acmesmith/issues/36) [#37](https://github.com/sorah/acmesmith/pull/37) [#38](https://github.com/sorah/acmesmith/issues/36))

  ```yaml
  challenge_responders:
    # Use specific IAM role for the domain "example.dev" ...
    - route53:
        assume_role:
          role_arn: 'arn:aws:iam:...'
      filter:
        subject_name_exact:
          - example.dev

    - manual_dns: {}
      filter:
        subject_name_suffix:
          - example.net

    # Default
    - route53: {}
  ```

- config: now accepts `connection_options` and `bad_nonce_retry` for [`Acme::Client`](https://github.com/unixcharles/acme-client).

### Fixes

- Exported PKCS#12 were not included a certificate chain [#35](https://github.com/sorah/acmesmith/pulls/35)
- s3: `use_kms` option was not respected for certificate keys & PKCS#12. It was always `true`.
- A large refactoring of internal components.

## v2.2.0 (2018-08-08)

### Enhancement

- s3: Added `pkcs12_passphrase` and `pkcs12_commonname` options for saving PKCS#12 file into a S3 bucket. This is for scripts which read S3 bucket directly and needs PKCS#12 file.

## v2.1.0 (2018-06-07)

### Changes

- route53: Private hosted zones are now ignored by default. If you really need to use such zones, specify explicitly with `hosted_zone_map`.

## v2.0.3 (2018-05-19)

### Bug fixes

- `route53` couldn't create an appropriate RRSet when ACME server needs multiple authorizations for the single domain.  [#31](https://github.com/sorah/acmesmith/issues/31)

  (In fact, responsing could fail when ordering certificate for `*.example.org` and `example.org` to LE.)

## v2.0.2 (2018-05-18)

### Bug fixes

- `acm` post issuing hook could fail

## v2.0.1 (2018-05-18)

### Bug fixes

- It could fail when encountered a challenge type which is unsupported by `acme-client` gem

## v2.0.0 (2018-05-18)

### Notable changes

- Support ACME v2
- Drop ACME v1 support
- Challenge responder
  - New `dns-01` challenge responder `manual_dns` is bundled for manual DNS intervention.
  - New API to allow challenge responders to respond many challenges at once, for efficiency
    - Added its support to `route53` responder 

#### Compatibility note

- `config['endpoint']` is removed. Use `config['directory']` to specify ACME v2 directory resource URL.
- The deprecated `config['post_issueing_hook']` is removed as planned.

### CLI

#### Compatibility note

- Renamed several subcommands due to the changes in ACME (v2) semantics.

  - `acmesmith register` -> `acmesmith new-account`
  - `acmesmith request` -> `acmesmith order`

  The previous names remain working, but are now marked as deprecated. These will be removed in the future release.

- Place warning for `acmesmith authorize` due to lack of implementation

  (At this moment, LE doesn't provide new-authz API)

### API and Internals

(Interface of `Client` class is still in beta. It's designed to be an external API, but interface are still subject to change)

#### Compatibility note

- `config['endpoint']` is removed. Use `config['directory']` to specify ACME v2 directory resource URL.
- Several renames due to the changes in ACME (v2) semantics.

  - `Client#register` -> `new_account`
  - `Client#request` -> `order`

- Place warning for `Client#authorize` due to lack of implementation

  (At this moment, LE doesn't provide new-authz API)

- `Certificate#chain` now returns `Array<OpenSSL::X509::Certificate>`. Use `Certificate#chain_pems` to retrieve in `String`.

  Note: Value for `:chain` key in a `Hash` returned by `Certificate#export` is kept `String` for Storages plugin compatibility.

#### New Features

- `ChallengeResponders::Base` now allows to respond many challenges at once.
  - Added `#respond_all` and `#cleanup_all()` method to respond many challenges.
  - Added `#cap_respond_all?` method to indicate a responder instance supports this capability or not.
  - Base class now implements `respond`, `cleanup` for classes which implement only the new `*_all` method.



## Prior versions

See https://github.com/sorah/acmesmith/releases
