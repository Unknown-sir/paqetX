#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

readonly PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly INSTALLER="${PROJECT_DIR}/paqet-x-install.sh"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

expect_success() {
  local name="$1"
  shift
  if ! "$@" >"${TMP_DIR}/${name}.out" 2>"${TMP_DIR}/${name}.err"; then
    cat "${TMP_DIR}/${name}.out" "${TMP_DIR}/${name}.err" >&2 || true
    fail "${name} unexpectedly failed"
  fi
}

expect_failure() {
  local name="$1" expected="$2"
  shift 2
  if "$@" >"${TMP_DIR}/${name}.out" 2>"${TMP_DIR}/${name}.err"; then
    fail "${name} unexpectedly succeeded"
  fi
  if ! grep -Fq -- "$expected" "${TMP_DIR}/${name}.out" "${TMP_DIR}/${name}.err"; then
    cat "${TMP_DIR}/${name}.out" "${TMP_DIR}/${name}.err" >&2 || true
    fail "${name} did not include the expected message: ${expected}"
  fi
}

TMP_DIR="$(mktemp -d -t paqet-x-smoke.XXXXXXXX)"
trap 'rm -rf -- "$TMP_DIR"' EXIT

bash -n "$INSTALLER"
expect_success help bash "$INSTALLER" --help
grep -Fq 'Unknown-sir/paqetX' "${TMP_DIR}/help.out" || fail 'help output does not contain the repository URL'

expect_failure invalid-port 'Invalid port: abc' bash "$INSTALLER" --port abc
expect_failure reserved-port 'Do not use port 80 or 443' bash "$INSTALLER" --port 443
expect_failure missing-port-value '--port requires a value' bash "$INSTALLER" --port
expect_failure invalid-version 'Invalid release tag' bash "$INSTALLER" --version '../bad'
expect_failure invalid-interface 'Invalid interface name' bash "$INSTALLER" --interface 'eth0;bad'
expect_failure invalid-ip 'Invalid IPv4 address' bash "$INSTALLER" --local-ip 999.1.1.1
expect_failure invalid-mac 'Invalid router MAC' bash "$INSTALLER" --router-mac not-a-mac
expect_failure short-key 'Key must be 16-128 characters' bash "$INSTALLER" --key short
expect_failure unknown-option 'Unknown option' bash "$INSTALLER" --unknown

printf 'All Paqet X smoke tests passed.\n'
