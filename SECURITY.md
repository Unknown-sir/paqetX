# Security Policy

## Sensitive data

`/etc/paqet-x/config.yaml` contains the shared Paqet key. Do not publish its contents in issues, screenshots, logs, shell history, or support messages.

Prefer the interactive Iran prompt when entering the key. Passing `--key` on a command line can store it in shell history or briefly expose it in process metadata.

## Release integrity

The installer downloads Paqet only from official `hanselime/paqet` GitHub releases. In all-port mode it also downloads HevSocks5TProxy only from official `heiher/hev-socks5-tproxy` releases. It checks the expected repository release URL and requires the downloaded asset to match GitHub's published SHA-256 digest. Paqet archive paths and entry types are validated before extraction.

## Firewall and routing changes

The Abroad role installs the required Paqet raw-TCP rules plus owner-scoped destination handling for same-port local services. Selected-port Iran mode opens only the recorded TCP/UDP ports. All-port Iran mode creates a dedicated mangle chain, TPROXY mark, and policy-routing table while explicitly excluding the tunnel port, detected SSH ports, and user exclusions.

The uninstall flow removes recorded services, rules, chains, policy routes, binaries, and the dedicated service user when it was created by the installer.

## SSH protection

Automatic detection is defensive but cannot guarantee knowledge of every future SSH configuration. Review the displayed SSH exclusions before relying on all-port mode. Use `--ssh-ports` when SSH is exposed through multiple or unusual ports.

## Provider firewalls

Cloud security groups and external firewalls are outside the operating system and cannot be changed by this installer. Keep administrative access restricted and expose only the ports you intentionally serve.

## Reporting a vulnerability

Do not open a public issue containing credentials, private IPs, shared keys, generated configurations, or logs with private data. Contact the repository owner privately through the available GitHub profile channels and include a minimal reproduction with secrets removed.

## Scope

This project configures raw-packet networking, systemd, iptables, TPROXY, and policy routing. Use it only on systems and networks you are authorized to administer.
