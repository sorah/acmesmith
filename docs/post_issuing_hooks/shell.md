# Post Issuing Hook: Shell

Execute specified command on a shell. Environment variable `${CERT_NAME}` is available.

```yaml
post_issuing_hooks:
  "test.example.com":
    - shell:
        command: mail -s "New cert for ${CERT_NAME} has been issued" user@example.com < /dev/null
    - shell:
        command: touch /tmp/certs-has-been-issued-${CERT_NAME}
  "admin.example.com":
    - shell:
        command: /usr/bin/dosomethingelse ${CERT_NAME}
```

## What happened to `${COMMON_NAME}`?

In modern CA behavior, certificates may be missing CN field, or entire subject field.
It is still available, but we recommend to use `${CERT_NAME}` instead, which obtains a certificate name from certain sources.
