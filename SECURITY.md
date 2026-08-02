# Security Policy

## Sensitive data

`/etc/paqet-x/config.yaml` contains the shared Paqet key and is installed with root-only permissions. Do not publish its contents in issues, screenshots, logs, shell history, or support messages.

Prefer the interactive Iran prompt when entering the key. Passing `--key` on a command line can store it in shell history or briefly expose it in a process listing.

## Release integrity

The installer downloads Paqet only from the official `hanselime/paqet` GitHub releases and requires the release asset to match GitHub's published SHA-256 digest. Archive paths and entry types are validated before extraction.

## Firewall changes

The Abroad role installs the upstream-required NOTRACK and TCP RST suppression rules for the tunnel port. The Iran role opens only the selected local TCP and/or UDP forwarding ports. The uninstall flow removes rules recorded by the project before deleting its files.

## Reporting a vulnerability

Do not open a public issue containing credentials, private IPs, shared keys, generated configurations, or logs with private data. Contact the repository owner privately through the available GitHub profile channels and include a minimal reproduction with secrets removed.

## Scope

This project configures raw-packet networking, systemd, and iptables. Use it only on systems and networks you are authorized to administer.
