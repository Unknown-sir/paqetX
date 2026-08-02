# Changelog

## 3.0.0 — 2026-08-02

- Simplified the Abroad flow to install only the Paqet server service and print the version, tunnel port, and generated shared key.
- Removed connection-string and Abroad-side forwarding presets.
- Changed the Iran flow to request the Abroad host, tunnel port, shared key, and forwarding ports directly.
- Added the required three-option protocol menu: TCP only, UDP only, or both.
- Added `--ports` and `--protocol tcp|udp|both` for non-interactive installs.
- Added a top-level complete-uninstall menu option and `--uninstall --yes` mode.
- Added `paqetx key` to show the Abroad version, tunnel port, and shared key again.
- Pinned the default upstream version so both sides use the same wire protocol.
- Expanded integration coverage for Abroad-only config, TCP+UDP duplication, reruns, role conflicts, checksum failures, and complete removal.
- Made the Iran installation require a successful retried tunnel health check before reporting completion.

## 2.0.0 — 2026-08-02

- Added explicit Abroad and Iran roles.
- Added the official Paqet client configuration for the Iran entry server.
- Added multiple TCP/UDP port-forward mappings.
- Added systemd, firewall management, configuration preservation, and integration tests.

## 1.0.0 — 2026-08-02

- Initial server-only installer.
- Verified upstream release downloads.
- Automatic network detection, server configuration, systemd, and firewall rules.
