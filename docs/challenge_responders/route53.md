# Challenge Responder: Route 53

`route53` responder supports `dns-01` challenge type. This assumes domain NS are managed under Route53 hosted zone.

```yaml
challenge_responders:
  - route53:
      ### AWS Access key (optional, default to aws-sdk standard)
      aws_access_key:
        access_key_id:
        secret_access_key:
        # session_token:

      ### Hosted zone map (optional)
      ##  This specifies an exact hosted zone ID for each domain name.
      ##  Required when you have multiple hosted zones for the same domain name.
      hosted_zone_map: 
        "example.org.": "/hostedzone/DEADBEEF"
```

## IAM Policy

- [docs/vendor/aws.md](../vendor/aws.md): IAM and KMS key policies, and some tips
