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
grep -Fq 'Uninstall Paqet X completely' "${TMP_DIR}/help.out" || fail 'help does not describe uninstall menu'
grep -Fq 'TCP, UDP, or both' "${TMP_DIR}/help.out" || fail 'help does not describe protocol selection'
grep -Fq 'Paqet X self-test passed' "${TMP_DIR}/self-test.out" || fail 'self-test success text missing'

expect_failure invalid-port 'Invalid Paqet transport port: abc' bash "$INSTALLER" --role abroad --port abc
expect_failure reserved-port 'Do not use port 80 or 443' bash "$INSTALLER" --role abroad --port 443
expect_failure low-port 'transport port must be between 1024 and 65535' bash "$INSTALLER" --role abroad --port 53
expect_failure missing-port-value '--port requires a value' bash "$INSTALLER" --role abroad --port
expect_failure invalid-role 'Invalid role' bash "$INSTALLER" --role middle
expect_failure missing-role-value '--role requires a value' bash "$INSTALLER" --role
expect_failure invalid-forward 'Invalid forward mapping' bash "$INSTALLER" --role iran --forward '1:2:3'
expect_failure duplicate-forward 'Duplicate Iran listener/protocol' bash "$INSTALLER" --role iran --forward 8443:443 --forward 8443:8443
expect_failure invalid-forward-port 'Invalid forwarding port' bash "$INSTALLER" --role iran --ports '443,bad' --protocol tcp
expect_failure invalid-protocol 'Invalid protocol mode' bash "$INSTALLER" --role iran --ports 443 --protocol icmp
expect_failure missing-ports-value '--ports requires a value' bash "$INSTALLER" --role iran --ports
expect_failure missing-protocol-value '--protocol requires a value' bash "$INSTALLER" --role iran --protocol
expect_failure invalid-foreign-host 'Invalid --foreign-host' bash "$INSTALLER" --role iran --foreign-host 'bad host'
expect_failure invalid-listen-ip 'Invalid --listen-ip' bash "$INSTALLER" --role iran --listen-ip 999.1.1.1
expect_failure invalid-target-host 'Invalid --target-host' bash "$INSTALLER" --role iran --target-host 'bad_host'
expect_failure invalid-interface 'Invalid interface name' bash "$INSTALLER" --role abroad --interface 'eth0;bad'
expect_failure invalid-ip 'Invalid local IPv4' bash "$INSTALLER" --role abroad --local-ip 999.1.1.1
expect_failure invalid-mac 'Invalid router MAC' bash "$INSTALLER" --role abroad --router-mac not-a-mac
expect_failure short-key 'Key must be 16-128 safe characters' bash "$INSTALLER" --role abroad --key short
expect_failure uninstall-confirmation 'requires --yes' env PAQETX_TEST_MODE=1 PAQETX_ROOT_PREFIX="${TMP_DIR}/empty-root" bash "$INSTALLER" --uninstall
expect_failure unknown-option 'Unknown option' bash "$INSTALLER" --unknown

printf 'All Paqet X smoke tests passed.\n'
