# Security policy

## Important warning

`Paqet-Xv2` is an opaque third-party binary retained from the reference project. It has not been rebuilt from source in this repository. Its pinned SHA-256 protects against accidental replacement; it does not prove that the binary is safe.

## Safe operation

- Test on disposable VPS instances before production use.
- Keep a second administrative access path while testing All Ports mode.
- Verify the detected SSH exclusions before confirming installation.
- Exclude control panels, databases and monitoring ports that must remain local.
- Restrict provider firewalls to the minimum required source ranges where possible.
- Use a unique, strong tunnel key for each server pair.
- Keep the configuration files root-readable only.
- Do not expose the local SOCKS5 helper ports to public interfaces.
- Review `journalctl`, iptables counters and systemd restart counts after deployment.

## Reporting

Do not include secret keys, server IPs, passwords or full configuration files in public issues. Redact identifying information before sharing logs.
