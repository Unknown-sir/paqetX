# Security Policy

## Sensitive data

`/etc/paqet-x/config.yaml` and `/etc/paqet-x/connection.txt` contain the shared Paqet secret. They are installed with root-only permissions. Do not publish their contents in issues, screenshots, logs, or support messages.

Passing a `paqetx://` token through a command-line argument may store it in shell history or briefly expose it in a process listing. Prefer pasting the token into the interactive prompt.

## Release integrity

The installer downloads Paqet only from the official `hanselime/paqet` GitHub releases and requires the release asset to match GitHub's published SHA-256 digest.

## Reporting a vulnerability

Do not open a public issue containing credentials, connection strings, private IPs, or secret keys. Contact the repository owner privately through the available GitHub profile channels and include a minimal reproduction with secrets removed.

## Scope

This project configures raw-packet networking, systemd, and iptables. Use it only on systems and networks you are authorized to administer.
