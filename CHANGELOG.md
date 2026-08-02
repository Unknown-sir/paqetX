# Changelog

## 2.0.0 — 2026-08-02

- Added explicit Abroad and Iran roles.
- Added guided setup that works through a single piped Bash command.
- Added official Paqet client configuration for the Iran entry server.
- Added multiple TCP/UDP port-forward mappings.
- Added optional SOCKS5 configuration.
- Added portable `paqetx://` connection strings with matching release and KCP settings.
- Added automatic public-IP detection for the abroad server.
- Added Iran-side local firewall rules for forwarded listen ports.
- Added `paqetx` management commands and uninstall support.
- Added configuration migration, preservation, backups, and reconfiguration.
- Added low-port systemd capability for forwarded ports such as 443.
- Expanded validation and self-tests for roles, forwards, tokens, ciphers, and network input.

## 1.0.0 — 2026-08-02

- Initial server-only installer.
- Verified upstream release downloads.
- Automatic network detection, server configuration, systemd, and firewall rules.
