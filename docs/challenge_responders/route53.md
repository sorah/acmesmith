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

      ### Assume IAM role to access Route 53
      # Available options are https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/AssumeRoleCredentials.html
      assume_role:
        role_arn: "arn:aws:iam:::..."

      ### Hosted zone map (optional)
      ##  This specifies an exact hosted zone ID for each domain name.
      ##  Required when you have multiple hosted zones for the same domain name.
      hosted_zone_map: 
        "example.org.": "/hostedzone/DEADBEEF"

      # Restore to original records on cleanup (after domain authorization). Default to false.
      # Useful when you need to keep existing record as long as possible.
      restore_to_original_records: true
```

## IAM Policy

- [docs/vendor/aws.md](../vendor/aws.md): IAM and KMS key policies, and some tips
