# Changelog

## 4.1.0 — 2026-08-03

- Fixed all-port forwarding on VPS layouts where inbound traffic arrives on an interface different from the default-route interface.
- Replaced the Abroad-side Paqet-owned DNAT workaround with a UID-scoped REDIRECT that preserves the destination port across iptables legacy and nft backends.
- Added loopback, Hev mark, SOCKS5-port, and internal TPROXY-port bypass rules to prevent transparent-proxy recapture.
- Added post-install verification for firewall hooks, TPROXY rules, policy routing, SOCKS5, and transparent TCP/UDP listeners.
- Added `paqetx diagnose` with service state, listeners, policy routes, firewall rules, and packet counters.
- Added migration cleanup for all v4.0 firewall rules and expanded mocked integration coverage for the corrected path.

## 4.0.0 — 2026-08-03

- Added two Iran forwarding modes: selected ports and all ports with exclusions.
- Added automatic SSH-port protection using the current SSH connection, `sshd -T`, active listeners, and SSH configuration files, with port 22 as a safe fallback.
- Added repeatable user-defined exclusions for all-port mode.
- Added TCP-only, UDP-only, and combined TCP+UDP support to all-port mode.
- Implemented all-port forwarding through Paqet SOCKS5, verified HevSocks5TProxy releases, Linux TPROXY, policy routing, and same-port destination handling on Abroad.
- Added a dedicated unprivileged `paqetx` service account and capability-limited systemd units.
- Expanded complete uninstall to remove the transparent-proxy service, helper binary, policy routes, firewall chains, and installer-created service account.
- Added mocked end-to-end coverage for automatic SSH detection, extra exclusions, transparent-proxy installation, reruns, and all-port uninstall.

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
