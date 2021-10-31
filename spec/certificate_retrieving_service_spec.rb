require 'spec_helper'
require 'openssl'

require 'acmesmith/certificate_retrieving_service'

RSpec.describe Acmesmith::CertificateRetrievingService::CertificateChain do
  # 1. end-entity
  # 2. s=(STAGING) Artificial Apricot R3, i=(STAGING) Pretend Pear X1
  # 3. s=(STAGING) Pretend Pear X1, i=(STAGING) Doctored Durian Root CA X3
  TEST_CHAIN_1 = <<~EOF
    -----BEGIN CERTIFICATE-----
    MIIFXDCCBESgAwIBAgITAPpyplhpKssE1b2toRhXUlfWbzANBgkqhkiG9w0BAQsF
    ADBZMQswCQYDVQQGEwJVUzEgMB4GA1UEChMXKFNUQUdJTkcpIExldCdzIEVuY3J5
    cHQxKDAmBgNVBAMTHyhTVEFHSU5HKSBBcnRpZmljaWFsIEFwcmljb3QgUjMwHhcN
    MjExMDMxMTkwMTA5WhcNMjIwMTI5MTkwMTA4WjAeMRwwGgYDVQQDExNkZXYyMDIx
    MTEwMWEuMHcwLmNvMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA3TM2
    0x1kfkQB17D6HwgsZIgc1pWpRQpxKsutu+9ugWPpkHbQo55xiageBoyFEu8lh5g0
    WsQ8w8aPobZK/GytQvPinXLGwkByB9thuZBqaxijma1Y9sfozts0aqH4ehrdrMyi
    I6aZ5RsOn9dV3t6zXlDcl2ZebPcmZlTHZQJrzBHuIfBflDZbqGef7FdtasDfZGra
    uqXEUeG3++yiBihQPwJDH+8t3rF1Ijjj2YRGrYmkucLI7a21abkyeYd1LUZs/U9Z
    uTadT0YCr8TYmSssF67P5wSjSrsHm9KXjLwn6JJU5dC4qJFni/wD0FluQnVkQZgP
    V5i6q+S2Rn06i1/NgQIDAQABo4ICVjCCAlIwDgYDVR0PAQH/BAQDAgWgMB0GA1Ud
    JQQWMBQGCCsGAQUFBwMBBggrBgEFBQcDAjAMBgNVHRMBAf8EAjAAMB0GA1UdDgQW
    BBRbuPijqD9LoqIMoyUb3QtMXkf6QDAfBgNVHSMEGDAWgBTecnpI3zHDplDfn4Uj
    31c3S10uZTBdBggrBgEFBQcBAQRRME8wJQYIKwYBBQUHMAGGGWh0dHA6Ly9zdGct
    cjMuby5sZW5jci5vcmcwJgYIKwYBBQUHMAKGGmh0dHA6Ly9zdGctcjMuaS5sZW5j
    ci5vcmcvMB4GA1UdEQQXMBWCE2RldjIwMjExMTAxYS4wdzAuY28wTAYDVR0gBEUw
    QzAIBgZngQwBAgEwNwYLKwYBBAGC3xMBAQEwKDAmBggrBgEFBQcCARYaaHR0cDov
    L2Nwcy5sZXRzZW5jcnlwdC5vcmcwggEEBgorBgEEAdZ5AgQCBIH1BIHyAPAAdgCw
    zIPlpfl9a698CcwoSQSHKsfoixMsY1C3xv0m4WxsdwAAAXzX8QZIAAAEAwBHMEUC
    IQCyLDw5DX5cFUyz7o8QjD1/s5vpPzOLXQE6UcCBMXp4NAIgcLOw3O50DZ0nK2rD
    MSiGTK5cdQTRcwqQcltcxBeDgXsAdgDdmTT8peckgMlWaH2BNJkISbJJ97Vp2Me8
    qz9cwfNuZAAAAXzX8QgeAAAEAwBHMEUCIQDK5IiE6LksDEoQ+fm+obf+dXD8yvbE
    hDgDZQMgkwvTEgIgEGsyglHs6V7X6keAKMmnAqT862tfo1+TCTeBnH22Oh0wDQYJ
    KoZIhvcNAQELBQADggEBAByZRHXVDp1VeZAlLeZS/2bL53hxKkGaUdSXULU2VVag
    jrehvdEsLHJfmm5i70F0SyWpPW4kDVP1tUxQ8uqPGkwVS53cldDRZr5dAM0TTuGh
    O4dTPOj8ziGfwdbD7gkHmgpDUR97pepyfOVgTGY3VaPVDnBfWpVaGZR+79BJc6qu
    dpq74CwWdrDP3jKXeeahvIgqZumUq6pC5CGY/k4GRdfW+KCFk0PqZH75Prxj7L+I
    CqgmIJ4t9U/czcBkA3sFxNGkZR9d8B6xHWYesvetiEah5tDIWybn9kEwqEWzXm4S
    3PBPxeNRAeQxux460FHiLk/CXllnGSlU9yMKa++hw14=
    -----END CERTIFICATE-----

    -----BEGIN CERTIFICATE-----
    MIIFWzCCA0OgAwIBAgIQTfQrldHumzpMLrM7jRBd1jANBgkqhkiG9w0BAQsFADBm
    MQswCQYDVQQGEwJVUzEzMDEGA1UEChMqKFNUQUdJTkcpIEludGVybmV0IFNlY3Vy
    aXR5IFJlc2VhcmNoIEdyb3VwMSIwIAYDVQQDExkoU1RBR0lORykgUHJldGVuZCBQ
    ZWFyIFgxMB4XDTIwMDkwNDAwMDAwMFoXDTI1MDkxNTE2MDAwMFowWTELMAkGA1UE
    BhMCVVMxIDAeBgNVBAoTFyhTVEFHSU5HKSBMZXQncyBFbmNyeXB0MSgwJgYDVQQD
    Ex8oU1RBR0lORykgQXJ0aWZpY2lhbCBBcHJpY290IFIzMIIBIjANBgkqhkiG9w0B
    AQEFAAOCAQ8AMIIBCgKCAQEAu6TR8+74b46mOE1FUwBrvxzEYLck3iasmKrcQkb+
    gy/z9Jy7QNIAl0B9pVKp4YU76JwxF5DOZZhi7vK7SbCkK6FbHlyU5BiDYIxbbfvO
    L/jVGqdsSjNaJQTg3C3XrJja/HA4WCFEMVoT2wDZm8ABC1N+IQe7Q6FEqc8NwmTS
    nmmRQm4TQvr06DP+zgFK/MNubxWWDSbSKKTH5im5j2fZfg+j/tM1bGaczFWw8/lS
    nukyn5J2L+NJYnclzkXoh9nMFnyPmVbfyDPOc4Y25aTzVoeBKXa/cZ5MM+WddjdL
    biWvm19f1sYn1aRaAIrkppv7kkn83vcth8XCG39qC2ZvaQIDAQABo4IBEDCCAQww
    DgYDVR0PAQH/BAQDAgGGMB0GA1UdJQQWMBQGCCsGAQUFBwMCBggrBgEFBQcDATAS
    BgNVHRMBAf8ECDAGAQH/AgEAMB0GA1UdDgQWBBTecnpI3zHDplDfn4Uj31c3S10u
    ZTAfBgNVHSMEGDAWgBS182Xy/rAKkh/7PH3zRKCsYyXDFDA2BggrBgEFBQcBAQQq
    MCgwJgYIKwYBBQUHMAKGGmh0dHA6Ly9zdGcteDEuaS5sZW5jci5vcmcvMCsGA1Ud
    HwQkMCIwIKAeoByGGmh0dHA6Ly9zdGcteDEuYy5sZW5jci5vcmcvMCIGA1UdIAQb
    MBkwCAYGZ4EMAQIBMA0GCysGAQQBgt8TAQEBMA0GCSqGSIb3DQEBCwUAA4ICAQCN
    DLam9yN0EFxxn/3p+ruWO6n/9goCAM5PT6cC6fkjMs4uas6UGXJjr5j7PoTQf3C1
    vuxiIGRJC6qxV7yc6U0X+w0Mj85sHI5DnQVWN5+D1er7mp13JJA0xbAbHa3Rlczn
    y2Q82XKui8WHuWra0gb2KLpfboYj1Ghgkhr3gau83pC/WQ8HfkwcvSwhIYqTqxoZ
    Uq8HIf3M82qS9aKOZE0CEmSyR1zZqQxJUT7emOUapkUN9poJ9zGc+FgRZvdro0XB
    yphWXDaqMYph0DxW/10ig5j4xmmNDjCRmqIKsKoWA52wBTKKXK1na2ty/lW5dhtA
    xkz5rVZFd4sgS4J0O+zm6d5GRkWsNJ4knotGXl8vtS3X40KXeb3A5+/3p0qaD215
    Xq8oSNORfB2oI1kQuyEAJ5xvPTdfwRlyRG3lFYodrRg6poUBD/8fNTXMtzydpRgy
    zUQZh/18F6B/iW6cbiRN9r2Hkh05Om+q0/6w0DdZe+8YrNpfhSObr/1eVZbKGMIY
    qKmyZbBNu5ysENIK5MPc14mUeKmFjpN840VR5zunoU52lqpLDua/qIM8idk86xGW
    xx2ml43DO/Ya/tVZVok0mO0TUjzJIfPqyvr455IsIut4RlCR9Iq0EDTve2/ZwCuG
    hSjpTUFGSiQrR2JK2Evp+o6AETUkBCO1aw0PpQBPDQ==
    -----END CERTIFICATE-----

    -----BEGIN CERTIFICATE-----
    MIIFVDCCBDygAwIBAgIRAO1dW8lt+99NPs1qSY3Rs8cwDQYJKoZIhvcNAQELBQAw
    cTELMAkGA1UEBhMCVVMxMzAxBgNVBAoTKihTVEFHSU5HKSBJbnRlcm5ldCBTZWN1
    cml0eSBSZXNlYXJjaCBHcm91cDEtMCsGA1UEAxMkKFNUQUdJTkcpIERvY3RvcmVk
    IER1cmlhbiBSb290IENBIFgzMB4XDTIxMDEyMDE5MTQwM1oXDTI0MDkzMDE4MTQw
    M1owZjELMAkGA1UEBhMCVVMxMzAxBgNVBAoTKihTVEFHSU5HKSBJbnRlcm5ldCBT
    ZWN1cml0eSBSZXNlYXJjaCBHcm91cDEiMCAGA1UEAxMZKFNUQUdJTkcpIFByZXRl
    bmQgUGVhciBYMTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBALbagEdD
    Ta1QgGBWSYkyMhscZXENOBaVRTMX1hceJENgsL0Ma49D3MilI4KS38mtkmdF6cPW
    nL++fgehT0FbRHZgjOEr8UAN4jH6omjrbTD++VZneTsMVaGamQmDdFl5g1gYaigk
    kmx8OiCO68a4QXg4wSyn6iDipKP8utsE+x1E28SA75HOYqpdrk4HGxuULvlr03wZ
    GTIf/oRt2/c+dYmDoaJhge+GOrLAEQByO7+8+vzOwpNAPEx6LW+crEEZ7eBXih6V
    P19sTGy3yfqK5tPtTdXXCOQMKAp+gCj/VByhmIr+0iNDC540gtvV303WpcbwnkkL
    YC0Ft2cYUyHtkstOfRcRO+K2cZozoSwVPyB8/J9RpcRK3jgnX9lujfwA/pAbP0J2
    UPQFxmWFRQnFjaq6rkqbNEBgLy+kFL1NEsRbvFbKrRi5bYy2lNms2NJPZvdNQbT/
    2dBZKmJqxHkxCuOQFjhJQNeO+Njm1Z1iATS/3rts2yZlqXKsxQUzN6vNbD8KnXRM
    EeOXUYvbV4lqfCf8mS14WEbSiMy87GB5S9ucSV1XUrlTG5UGcMSZOBcEUpisRPEm
    QWUOTWIoDQ5FOia/GI+Ki523r2ruEmbmG37EBSBXdxIdndqrjy+QVAmCebyDx9eV
    EGOIpn26bW5LKerumJxa/CFBaKi4bRvmdJRLAgMBAAGjgfEwge4wDgYDVR0PAQH/
    BAQDAgEGMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFLXzZfL+sAqSH/s8ffNE
    oKxjJcMUMB8GA1UdIwQYMBaAFAhX2onHolN5DE/d4JCPdLriJ3NEMDgGCCsGAQUF
    BwEBBCwwKjAoBggrBgEFBQcwAoYcaHR0cDovL3N0Zy1kc3QzLmkubGVuY3Iub3Jn
    LzAtBgNVHR8EJjAkMCKgIKAehhxodHRwOi8vc3RnLWRzdDMuYy5sZW5jci5vcmcv
    MCIGA1UdIAQbMBkwCAYGZ4EMAQIBMA0GCysGAQQBgt8TAQEBMA0GCSqGSIb3DQEB
    CwUAA4IBAQB7tR8B0eIQSS6MhP5kuvGth+dN02DsIhr0yJtk2ehIcPIqSxRRmHGl
    4u2c3QlvEpeRDp2w7eQdRTlI/WnNhY4JOofpMf2zwABgBWtAu0VooQcZZTpQruig
    F/z6xYkBk3UHkjeqxzMN3d1EqGusxJoqgdTouZ5X5QTTIee9nQ3LEhWnRSXDx7Y0
    ttR1BGfcdqHopO4IBqAhbkKRjF5zj7OD8cG35omywUbZtOJnftiI0nFcRaxbXo0v
    oDfLD0S6+AC2R3tKpqjkNX6/91hrRFglUakyMcZU/xleqbv6+Lr3YD8PsBTub6lI
    oZ2lS38fL18Aon458fbc0BPHtenfhKj5
    -----END CERTIFICATE-----
  EOF

  # 1. end-entity
  # 2. s=(STAGING) Artificial Apricot R3, i=(STAGING) Pretend Pear X1
  TEST_CHAIN_2 = <<~EOF
    -----BEGIN CERTIFICATE-----
    MIIFXDCCBESgAwIBAgITAPpyplhpKssE1b2toRhXUlfWbzANBgkqhkiG9w0BAQsF
    ADBZMQswCQYDVQQGEwJVUzEgMB4GA1UEChMXKFNUQUdJTkcpIExldCdzIEVuY3J5
    cHQxKDAmBgNVBAMTHyhTVEFHSU5HKSBBcnRpZmljaWFsIEFwcmljb3QgUjMwHhcN
    MjExMDMxMTkwMTA5WhcNMjIwMTI5MTkwMTA4WjAeMRwwGgYDVQQDExNkZXYyMDIx
    MTEwMWEuMHcwLmNvMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA3TM2
    0x1kfkQB17D6HwgsZIgc1pWpRQpxKsutu+9ugWPpkHbQo55xiageBoyFEu8lh5g0
    WsQ8w8aPobZK/GytQvPinXLGwkByB9thuZBqaxijma1Y9sfozts0aqH4ehrdrMyi
    I6aZ5RsOn9dV3t6zXlDcl2ZebPcmZlTHZQJrzBHuIfBflDZbqGef7FdtasDfZGra
    uqXEUeG3++yiBihQPwJDH+8t3rF1Ijjj2YRGrYmkucLI7a21abkyeYd1LUZs/U9Z
    uTadT0YCr8TYmSssF67P5wSjSrsHm9KXjLwn6JJU5dC4qJFni/wD0FluQnVkQZgP
    V5i6q+S2Rn06i1/NgQIDAQABo4ICVjCCAlIwDgYDVR0PAQH/BAQDAgWgMB0GA1Ud
    JQQWMBQGCCsGAQUFBwMBBggrBgEFBQcDAjAMBgNVHRMBAf8EAjAAMB0GA1UdDgQW
    BBRbuPijqD9LoqIMoyUb3QtMXkf6QDAfBgNVHSMEGDAWgBTecnpI3zHDplDfn4Uj
    31c3S10uZTBdBggrBgEFBQcBAQRRME8wJQYIKwYBBQUHMAGGGWh0dHA6Ly9zdGct
    cjMuby5sZW5jci5vcmcwJgYIKwYBBQUHMAKGGmh0dHA6Ly9zdGctcjMuaS5sZW5j
    ci5vcmcvMB4GA1UdEQQXMBWCE2RldjIwMjExMTAxYS4wdzAuY28wTAYDVR0gBEUw
    QzAIBgZngQwBAgEwNwYLKwYBBAGC3xMBAQEwKDAmBggrBgEFBQcCARYaaHR0cDov
    L2Nwcy5sZXRzZW5jcnlwdC5vcmcwggEEBgorBgEEAdZ5AgQCBIH1BIHyAPAAdgCw
    zIPlpfl9a698CcwoSQSHKsfoixMsY1C3xv0m4WxsdwAAAXzX8QZIAAAEAwBHMEUC
    IQCyLDw5DX5cFUyz7o8QjD1/s5vpPzOLXQE6UcCBMXp4NAIgcLOw3O50DZ0nK2rD
    MSiGTK5cdQTRcwqQcltcxBeDgXsAdgDdmTT8peckgMlWaH2BNJkISbJJ97Vp2Me8
    qz9cwfNuZAAAAXzX8QgeAAAEAwBHMEUCIQDK5IiE6LksDEoQ+fm+obf+dXD8yvbE
    hDgDZQMgkwvTEgIgEGsyglHs6V7X6keAKMmnAqT862tfo1+TCTeBnH22Oh0wDQYJ
    KoZIhvcNAQELBQADggEBAByZRHXVDp1VeZAlLeZS/2bL53hxKkGaUdSXULU2VVag
    jrehvdEsLHJfmm5i70F0SyWpPW4kDVP1tUxQ8uqPGkwVS53cldDRZr5dAM0TTuGh
    O4dTPOj8ziGfwdbD7gkHmgpDUR97pepyfOVgTGY3VaPVDnBfWpVaGZR+79BJc6qu
    dpq74CwWdrDP3jKXeeahvIgqZumUq6pC5CGY/k4GRdfW+KCFk0PqZH75Prxj7L+I
    CqgmIJ4t9U/czcBkA3sFxNGkZR9d8B6xHWYesvetiEah5tDIWybn9kEwqEWzXm4S
    3PBPxeNRAeQxux460FHiLk/CXllnGSlU9yMKa++hw14=
    -----END CERTIFICATE-----

    -----BEGIN CERTIFICATE-----
    MIIFWzCCA0OgAwIBAgIQTfQrldHumzpMLrM7jRBd1jANBgkqhkiG9w0BAQsFADBm
    MQswCQYDVQQGEwJVUzEzMDEGA1UEChMqKFNUQUdJTkcpIEludGVybmV0IFNlY3Vy
    aXR5IFJlc2VhcmNoIEdyb3VwMSIwIAYDVQQDExkoU1RBR0lORykgUHJldGVuZCBQ
    ZWFyIFgxMB4XDTIwMDkwNDAwMDAwMFoXDTI1MDkxNTE2MDAwMFowWTELMAkGA1UE
    BhMCVVMxIDAeBgNVBAoTFyhTVEFHSU5HKSBMZXQncyBFbmNyeXB0MSgwJgYDVQQD
    Ex8oU1RBR0lORykgQXJ0aWZpY2lhbCBBcHJpY290IFIzMIIBIjANBgkqhkiG9w0B
    AQEFAAOCAQ8AMIIBCgKCAQEAu6TR8+74b46mOE1FUwBrvxzEYLck3iasmKrcQkb+
    gy/z9Jy7QNIAl0B9pVKp4YU76JwxF5DOZZhi7vK7SbCkK6FbHlyU5BiDYIxbbfvO
    L/jVGqdsSjNaJQTg3C3XrJja/HA4WCFEMVoT2wDZm8ABC1N+IQe7Q6FEqc8NwmTS
    nmmRQm4TQvr06DP+zgFK/MNubxWWDSbSKKTH5im5j2fZfg+j/tM1bGaczFWw8/lS
    nukyn5J2L+NJYnclzkXoh9nMFnyPmVbfyDPOc4Y25aTzVoeBKXa/cZ5MM+WddjdL
    biWvm19f1sYn1aRaAIrkppv7kkn83vcth8XCG39qC2ZvaQIDAQABo4IBEDCCAQww
    DgYDVR0PAQH/BAQDAgGGMB0GA1UdJQQWMBQGCCsGAQUFBwMCBggrBgEFBQcDATAS
    BgNVHRMBAf8ECDAGAQH/AgEAMB0GA1UdDgQWBBTecnpI3zHDplDfn4Uj31c3S10u
    ZTAfBgNVHSMEGDAWgBS182Xy/rAKkh/7PH3zRKCsYyXDFDA2BggrBgEFBQcBAQQq
    MCgwJgYIKwYBBQUHMAKGGmh0dHA6Ly9zdGcteDEuaS5sZW5jci5vcmcvMCsGA1Ud
    HwQkMCIwIKAeoByGGmh0dHA6Ly9zdGcteDEuYy5sZW5jci5vcmcvMCIGA1UdIAQb
    MBkwCAYGZ4EMAQIBMA0GCysGAQQBgt8TAQEBMA0GCSqGSIb3DQEBCwUAA4ICAQCN
    DLam9yN0EFxxn/3p+ruWO6n/9goCAM5PT6cC6fkjMs4uas6UGXJjr5j7PoTQf3C1
    vuxiIGRJC6qxV7yc6U0X+w0Mj85sHI5DnQVWN5+D1er7mp13JJA0xbAbHa3Rlczn
    y2Q82XKui8WHuWra0gb2KLpfboYj1Ghgkhr3gau83pC/WQ8HfkwcvSwhIYqTqxoZ
    Uq8HIf3M82qS9aKOZE0CEmSyR1zZqQxJUT7emOUapkUN9poJ9zGc+FgRZvdro0XB
    yphWXDaqMYph0DxW/10ig5j4xmmNDjCRmqIKsKoWA52wBTKKXK1na2ty/lW5dhtA
    xkz5rVZFd4sgS4J0O+zm6d5GRkWsNJ4knotGXl8vtS3X40KXeb3A5+/3p0qaD215
    Xq8oSNORfB2oI1kQuyEAJ5xvPTdfwRlyRG3lFYodrRg6poUBD/8fNTXMtzydpRgy
    zUQZh/18F6B/iW6cbiRN9r2Hkh05Om+q0/6w0DdZe+8YrNpfhSObr/1eVZbKGMIY
    qKmyZbBNu5ysENIK5MPc14mUeKmFjpN840VR5zunoU52lqpLDua/qIM8idk86xGW
    xx2ml43DO/Ya/tVZVok0mO0TUjzJIfPqyvr455IsIut4RlCR9Iq0EDTve2/ZwCuG
    hSjpTUFGSiQrR2JK2Evp+o6AETUkBCO1aw0PpQBPDQ==
    -----END CERTIFICATE-----
  EOF

  let(:test_chain_1) { described_class.new(TEST_CHAIN_1) }
  let(:test_chain_2) { described_class.new(TEST_CHAIN_2) }

  def subject_cn(cert)
    cert.subject.to_a.assoc('CN')[1]
  end

  describe "#top" do
    it "returns a last certificate of given and constructed chain" do
      expect(subject_cn(test_chain_1.top)).to eq '(STAGING) Pretend Pear X1'
      expect(subject_cn(test_chain_2.top)).to eq '(STAGING) Artificial Apricot R3'
    end
  end


  describe "#match?" do
    it "tests against a root issuer name" do
      expect(test_chain_1.match?(name: '(STAGING) Doctored Durian Root CA X3')).to eq true
      expect(test_chain_2.match?(name: '(STAGING) Pretend Pear X1')).to eq true

      expect(test_chain_1.match?(name: '(STAGING) Pretend Pear X1')).to eq false
      expect(test_chain_2.match?(name: '(STAGING) Doctored Durian Root CA X3')).to eq false

      expect(test_chain_1.match?(name: 'dev20211101a.0w0.co')).to eq false
      expect(test_chain_2.match?(name: 'dev20211101a.0w0.co')).to eq false
    end

    it "tests against a root issuer key id" do
      expect(test_chain_1.match?(key_id: '08:57:da:89:c7:a2:53:79:0c:4f:dd:e0:90:8f:74:ba:e2:27:73:44')).to eq true
      expect(test_chain_2.match?(key_id: 'b5:f3:65:f2:fe:b0:0a:92:1f:fb:3c:7d:f3:44:a0:ac:63:25:c3:14')).to eq true

      expect(test_chain_1.match?(key_id: 'b5:f3:65:f2:fe:b0:0a:92:1f:fb:3c:7d:f3:44:a0:ac:63:25:c3:14')).to eq false
      expect(test_chain_2.match?(key_id: '08:57:da:89:c7:a2:53:79:0c:4f:dd:e0:90:8f:74:ba:e2:27:73:44')).to eq false

      expect(test_chain_1.match?(key_id: '5b:b8:f8:a3:a8:3f:4b:a2:a2:0c:a3:25:1b:dd:0b:4c:5e:47:fa:40')).to eq false
      expect(test_chain_2.match?(key_id: '5b:b8:f8:a3:a8:3f:4b:a2:a2:0c:a3:25:1b:dd:0b:4c:5e:47:fa:40')).to eq false
    end
  end
end
