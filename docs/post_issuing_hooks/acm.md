# Post issuing hook: Amazon Certificate Manager

`acm` imports certificate into AWS ACM.

```yaml
post_issuing_hooks:
  "test.example.com":
    - acm:
        region: us-east-1 # required
        certificate_arn: arn:aws:acm:... # (optional)
```

When `certificate_arn` is not present, `acm` hook attempts to find the certificate ARN from existing certificate list. Certificate with same common name ("domain name" on ACM), and `Acmesmith` tag
 will be used. Otherwise, `acm` hook imports as a new certificate with `Acmesmith` tag.


