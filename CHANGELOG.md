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
