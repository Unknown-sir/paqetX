#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

readonly PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly INSTALLER="${PROJECT_DIR}/paqet-x-install.sh"
TMP_DIR="$(mktemp -d -t paqet-x-smoke.XXXXXXXX)"
trap 'rm -rf -- "$TMP_DIR"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

expect_success() {
  local name="$1"; shift
  if ! "$@" >"${TMP_DIR}/${name}.out" 2>"${TMP_DIR}/${name}.err"; then
    cat "${TMP_DIR}/${name}.out" "${TMP_DIR}/${name}.err" >&2 || true
    fail "${name} unexpectedly failed"
  fi
}

expect_failure() {
  local name="$1" expected="$2"; shift 2
  if "$@" >"${TMP_DIR}/${name}.out" 2>"${TMP_DIR}/${name}.err"; then
    fail "${name} unexpectedly succeeded"
  fi
  if ! grep -Fq -- "$expected" "${TMP_DIR}/${name}.out" "${TMP_DIR}/${name}.err"; then
    cat "${TMP_DIR}/${name}.out" "${TMP_DIR}/${name}.err" >&2 || true
    fail "${name} did not include: ${expected}"
  fi
}

bash -n "$INSTALLER"

python3 - "$INSTALLER" "$TMP_DIR" <<'PY_EMBEDDED'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text()
out_dir = Path(sys.argv[2])
blocks = {
    "embedded-firewall.sh": ("cat > \"$FIREWALL_SCRIPT\" <<'FIREWALL'\n", "\nFIREWALL\n"),
    "embedded-manager.sh": ("cat > \"$MANAGER_PATH\" <<'MANAGER'\n", "\nMANAGER\n"),
}
for filename, (start_marker, end_marker) in blocks.items():
    start = source.index(start_marker) + len(start_marker)
    end = source.index(end_marker, start)
    (out_dir / filename).write_text(source[start:end] + "\n")
PY_EMBEDDED

bash -n "${TMP_DIR}/embedded-firewall.sh"
bash -n "${TMP_DIR}/embedded-manager.sh"

expect_success help bash "$INSTALLER" --help
expect_success self-test bash "$INSTALLER" --self-test
grep -Fq 'Unknown-sir/paqetX' "${TMP_DIR}/help.out" || fail 'help does not contain repository URL'
grep -Fq 'Paqet X self-test passed' "${TMP_DIR}/self-test.out" || fail 'self-test success text missing'

expect_failure invalid-port 'Invalid Paqet transport port: abc' bash "$INSTALLER" --port abc
expect_failure reserved-port 'Do not use port 80 or 443' bash "$INSTALLER" --port 443
expect_failure low-port 'transport port must be between 1024 and 65535' bash "$INSTALLER" --port 53
expect_failure missing-port-value '--port requires a value' bash "$INSTALLER" --port
expect_failure invalid-role 'Invalid role' bash "$INSTALLER" --role middle
expect_failure missing-role-value '--role requires a value' bash "$INSTALLER" --role
expect_failure invalid-forward 'Invalid forward mapping' bash "$INSTALLER" --forward '1:2:3'
expect_failure duplicate-forward 'Duplicate Iran listener/protocol' bash "$INSTALLER" --forward 8443:443 --forward 8443:8443
expect_failure invalid-public-host 'Invalid --public-host' bash "$INSTALLER" --public-host 'bad_host'
expect_failure invalid-foreign-host 'Invalid --foreign-host' bash "$INSTALLER" --foreign-host 'bad host'
expect_failure invalid-listen-ip 'Invalid --listen-ip' bash "$INSTALLER" --listen-ip 999.1.1.1
expect_failure invalid-target-host 'Invalid --target-host' bash "$INSTALLER" --target-host 'bad_host'
expect_failure invalid-socks5 'Invalid SOCKS5 address' bash "$INSTALLER" --socks5 localhost:1080
expect_failure invalid-version 'Invalid release tag' bash "$INSTALLER" --version '../bad'
expect_failure invalid-interface 'Invalid interface name' bash "$INSTALLER" --interface 'eth0;bad'
expect_failure invalid-ip 'Invalid local IPv4' bash "$INSTALLER" --local-ip 999.1.1.1
expect_failure invalid-mac 'Invalid router MAC' bash "$INSTALLER" --router-mac not-a-mac
expect_failure short-key 'Key must be 16-128 safe characters' bash "$INSTALLER" --key short
expect_failure invalid-mode 'Invalid KCP mode' bash "$INSTALLER" --kcp-mode turbo
expect_failure invalid-cipher 'Unsupported KCP cipher' bash "$INSTALLER" --block plaintext
expect_failure invalid-conn '--conn must be 1-256' bash "$INSTALLER" --conn 0
expect_failure invalid-mtu '--mtu must be 50-1500' bash "$INSTALLER" --mtu 2000
expect_failure unknown-option 'Unknown option' bash "$INSTALLER" --unknown

printf 'All Paqet X smoke tests passed.\n'
