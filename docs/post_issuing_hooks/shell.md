# Post Issuing Hook: Shell

Execute specified command on a shell. Environment variable `${COMMON_NAME}` is available.

```yaml
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


