# Changelog

## 5.2.0 — Dual-protocol exclusion fix

- Made All Ports mode always forward both TCP and UDP; the protocol selector is no longer shown for this mode.
- Fixed user exclusions so every port and range is bypassed for both TCP and UDP before catch-all TPROXY rules.
- Replaced per-service All Ports chains with a single `PQX_ALLPORT` chain.
- Added automatic cleanup of stale `PQX_*` chains left by previous versions, preventing old rules from capturing excluded ports.
- Strengthened firewall verification to require both TCP and UDP TPROXY rules and every exclusion rule.
- Added regression tests that verify excluded TCP/UDP ports precede TPROXY and that legacy chains are removed.

## 5.1.0 — Reference-compatible All Ports release

- Completed Persian and English documentation for the reference-based build.
- Preserved the source project's native selected-port `forward:` behavior.
- Preserved multi-service management, SOCKS5, KCP modes, encryption, MTU, connection count, logs, config editing, cron auto-restart and uninstall.
- Added the initial All Ports forwarding implementation for the Iran client.
- Added automatic tunnel-port and multi-source SSH-port detection and exclusion.
- Added user exclusions supporting ports and ranges.
- Added a forwarding server profile that maps dynamic All Ports requests to the same localhost port without altering native selected forwarding.
- Added per-tunnel firewall units, TPROXY policy routing, loop prevention, rp_filter restoration and full cleanup.
- Added verified HevSocks5TProxy release downloads.
- Retained the supplied opaque `Paqet-Xv2` binary unchanged and pinned its SHA-256.
- Added hardened per-service users and systemd units.
- Added non-destructive integration tests and GitHub Actions.

## 5.0.0 — Initial reference-based rebuild

- Rebuilt the installer around the management workflow of `MrAminiDev/Paqet-X-Nulled`.
