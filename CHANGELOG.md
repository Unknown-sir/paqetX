# Changelog

## 5.1.0 — Reference-compatible All Ports release

- Completed Persian and English documentation for the reference-based build.
- Preserved the source project's native selected-port `forward:` behavior.
- Preserved multi-service management, SOCKS5, KCP modes, encryption, MTU, connection count, logs, config editing, cron auto-restart and uninstall.
- Added All Ports forwarding for the Iran client with TCP-only, UDP-only or TCP+UDP selection.
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
