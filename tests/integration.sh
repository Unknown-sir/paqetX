#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

readonly PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly INSTALLER="${PROJECT_DIR}/paqet-x-install.sh"
TMP_DIR="$(mktemp -d -t paqet-x-integration.XXXXXXXX)"
trap 'rm -rf -- "$TMP_DIR"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
assert_file() { [[ -f "$1" ]] || fail "missing file: $1"; }
assert_missing() { [[ ! -e "$1" ]] || fail "unexpected path: $1"; }
assert_contains() { grep -Fq -- "$2" "$1" || { printf 'Expected %s in %s\n' "$2" "$1" >&2; sed -n '1,240p' "$1" >&2 || true; exit 1; }; }
assert_not_contains() { ! grep -Fq -- "$2" "$1" || fail "Did not expect $2 in $1"; }

MOCK_BIN="${TMP_DIR}/mock-bin"
ASSET_DIR="${TMP_DIR}/asset"
mkdir -p "$MOCK_BIN" "$ASSET_DIR"

cat > "${ASSET_DIR}/paqet_linux_amd64" <<'PAQET'
#!/usr/bin/env bash
set -Eeuo pipefail
case "${1:-}" in
  version) echo 'paqet v1.0.0-alpha.20' ;;
  ping) [[ "${MOCK_PAQET_PING_FAIL:-0}" == "1" ]] && exit 1; echo 'pong' ;;
  run) sleep 0.01 ;;
  *) echo 'mock paqet' ;;
esac
PAQET
chmod +x "${ASSET_DIR}/paqet_linux_amd64"

ASSET_NAME="paqet-linux-amd64-v1.0.0-alpha.20.tar.gz"
ASSET_PATH="${TMP_DIR}/${ASSET_NAME}"
tar -czf "$ASSET_PATH" -C "$ASSET_DIR" paqet_linux_amd64
ASSET_SHA="$(sha256sum "$ASSET_PATH" | awk '{print $1}')"
RELEASE_JSON="${TMP_DIR}/release.json"
BAD_RELEASE_JSON="${TMP_DIR}/release-bad.json"
cat > "$RELEASE_JSON" <<JSON
{
  "tag_name": "v1.0.0-alpha.20",
  "assets": [
    {
      "name": "${ASSET_NAME}",
      "browser_download_url": "https://github.com/hanselime/paqet/releases/download/v1.0.0-alpha.20/${ASSET_NAME}",
      "digest": "sha256:${ASSET_SHA}"
    }
  ]
}
JSON
sed "s/sha256:${ASSET_SHA}/sha256:$(printf '0%.0s' {1..64})/" "$RELEASE_JSON" > "$BAD_RELEASE_JSON"

cat > "${MOCK_BIN}/curl" <<'MOCK_CURL'
#!/usr/bin/env bash
set -Eeuo pipefail
output=""
url=""
previous=""
for arg in "$@"; do
  if [[ "$previous" == "-o" ]]; then output="$arg"; previous=""; continue; fi
  if [[ "$arg" == "-o" ]]; then previous="-o"; continue; fi
  [[ "$arg" == http://* || "$arg" == https://* ]] && url="$arg"
done
case "$url" in
  https://api.github.com/repos/hanselime/paqet/releases/*)
    cp -- "${MOCK_RELEASE_JSON:?}" "${output:?}"
    ;;
  https://github.com/hanselime/paqet/releases/download/*)
    cp -- "${MOCK_ASSET_PATH:?}" "${output:?}"
    ;;
  *)
    echo "Unexpected mock curl URL: $url" >&2
    exit 2
    ;;
esac
MOCK_CURL

cat > "${MOCK_BIN}/ip" <<'MOCK_IP'
#!/usr/bin/env bash
set -Eeuo pipefail
local_ip="${MOCK_LOCAL_IP:-192.0.2.10}"
case "$*" in
  '-4 route show default') echo 'default via 192.0.2.1 dev eth0 proto static' ;;
  '-4 route get 1.1.1.1') echo "1.1.1.1 via 192.0.2.1 dev eth0 src ${local_ip}" ;;
  '-4 route show default dev eth0') echo 'default via 192.0.2.1 dev eth0 proto static' ;;
  'link show dev eth0') echo '2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP>' ;;
  'neigh show to 192.0.2.1 dev eth0') echo '192.0.2.1 lladdr aa:bb:cc:dd:ee:ff REACHABLE' ;;
  *) echo "Unexpected mock ip args: $*" >&2; exit 2 ;;
esac
MOCK_IP

cat > "${MOCK_BIN}/systemctl" <<'MOCK_SYSTEMCTL'
#!/usr/bin/env bash
set -Eeuo pipefail
case "${1:-}" in
  is-active) exit 0 ;;
  *) exit 0 ;;
esac
MOCK_SYSTEMCTL

for command_name in systemd-analyze journalctl ping; do
  cat > "${MOCK_BIN}/${command_name}" <<'MOCK_OK'
#!/usr/bin/env bash
exit 0
MOCK_OK
done
cat > "${MOCK_BIN}/iptables" <<'MOCK_IPTABLES'
#!/usr/bin/env bash
set -Eeuo pipefail
for arg in "$@"; do
  [[ "$arg" == "-C" ]] && exit 1
done
exit 0
MOCK_IPTABLES
chmod +x "${MOCK_BIN}"/*

run_installer() {
  local root="$1" release_json="$2" local_ip="$3"
  shift 3
  mkdir -p "$root"
  PATH="${MOCK_BIN}:$PATH" \
  PAQETX_TEST_MODE=1 \
  PAQETX_ROOT_PREFIX="$root" \
  MOCK_RELEASE_JSON="$release_json" \
  MOCK_ASSET_PATH="$ASSET_PATH" \
  MOCK_LOCAL_IP="$local_ip" \
  NO_COLOR=1 \
  bash "$INSTALLER" "$@"
}

ABROAD_ROOT="${TMP_DIR}/abroad-root"
IRAN_ROOT="${TMP_DIR}/iran-root"
BAD_ROOT="${TMP_DIR}/bad-root"
PING_FAIL_ROOT="${TMP_DIR}/ping-fail-root"
KEY='0123456789abcdef0123456789abcdef'

run_installer "$ABROAD_ROOT" "$RELEASE_JSON" '192.0.2.10' \
  --role abroad \
  --port 9999 \
  --key "$KEY" \
  --interface eth0 \
  --local-ip 192.0.2.10 \
  --router-mac aa:bb:cc:dd:ee:ff \
  --yes >"${TMP_DIR}/abroad.out"

ABROAD_CONFIG="${ABROAD_ROOT}/etc/paqet-x/config.yaml"
assert_file "$ABROAD_CONFIG"
assert_file "${ABROAD_ROOT}/usr/local/bin/paqet"
assert_file "${ABROAD_ROOT}/usr/local/sbin/paqetx"
assert_contains "$ABROAD_CONFIG" 'role: "server"'
assert_contains "$ABROAD_CONFIG" 'addr: ":9999"'
assert_contains "$ABROAD_CONFIG" "key: \"${KEY}\""
assert_not_contains "$ABROAD_CONFIG" 'forward:'
assert_missing "${ABROAD_ROOT}/etc/paqet-x/connection.txt"
assert_contains "${ABROAD_ROOT}/etc/paqet-x/firewall.env" 'ROLE=abroad'
assert_contains "${ABROAD_ROOT}/etc/paqet-x/firewall.env" 'FORWARD_PORTS='
assert_contains "${TMP_DIR}/abroad.out" 'Save these values for the Iran server'
assert_contains "${TMP_DIR}/abroad.out" "Shared key:   ${KEY}"

run_installer "$IRAN_ROOT" "$RELEASE_JSON" '192.0.2.20' \
  --role iran \
  --foreign-host 203.0.113.10 \
  --port 9999 \
  --key "$KEY" \
  --ports 443,8443 \
  --protocol both \
  --interface eth0 \
  --local-ip 192.0.2.20 \
  --router-mac aa:bb:cc:dd:ee:ff \
  --yes >"${TMP_DIR}/iran.out"

IRAN_CONFIG="${IRAN_ROOT}/etc/paqet-x/config.yaml"
assert_file "$IRAN_CONFIG"
assert_contains "$IRAN_CONFIG" 'role: "client"'
assert_contains "$IRAN_CONFIG" 'addr: "203.0.113.10:9999"'
assert_contains "$IRAN_CONFIG" "key: \"${KEY}\""
assert_contains "$IRAN_CONFIG" 'listen: "0.0.0.0:443"'
assert_contains "$IRAN_CONFIG" 'target: "127.0.0.1:443"'
assert_contains "$IRAN_CONFIG" 'protocol: "tcp"'
assert_contains "$IRAN_CONFIG" 'protocol: "udp"'
[[ "$(grep -Fc 'listen: "0.0.0.0:443"' "$IRAN_CONFIG")" == "2" ]] || fail 'port 443 was not configured for both protocols'
[[ "$(grep -Fc 'listen: "0.0.0.0:8443"' "$IRAN_CONFIG")" == "2" ]] || fail 'port 8443 was not configured for both protocols'
assert_contains "${IRAN_ROOT}/etc/paqet-x/firewall.env" 'FORWARD_PORTS=443/tcp,443/udp,8443/tcp,8443/udp'
assert_contains "${IRAN_ROOT}/etc/paqet-x/install.env" 'FORWARD_SPECS=443:443/tcp,443:443/udp,8443:8443/tcp,8443:8443/udp'
assert_contains "${TMP_DIR}/iran.out" 'Iran service is active'

CONFIG_SHA_BEFORE="$(sha256sum "$IRAN_CONFIG" | awk '{print $1}')"
run_installer "$IRAN_ROOT" "$RELEASE_JSON" '192.0.2.20' \
  --role iran \
  --foreign-host 198.51.100.9 \
  --ports 2053 \
  --protocol udp \
  --yes >"${TMP_DIR}/rerun.out" 2>"${TMP_DIR}/rerun.err"
CONFIG_SHA_AFTER="$(sha256sum "$IRAN_CONFIG" | awk '{print $1}')"
[[ "$CONFIG_SHA_BEFORE" == "$CONFIG_SHA_AFTER" ]] || fail 'normal rerun changed preserved Iran config'
assert_contains "${TMP_DIR}/rerun.err" 'configuration options were ignored'
assert_contains "${IRAN_ROOT}/etc/paqet-x/install.env" 'FOREIGN_HOST=203.0.113.10'

if run_installer "$IRAN_ROOT" "$RELEASE_JSON" '192.0.2.20' \
  --role abroad --yes >"${TMP_DIR}/wrong-role.out" 2>"${TMP_DIR}/wrong-role.err"; then
  fail 'role replacement without reconfigure unexpectedly succeeded'
fi
assert_contains "${TMP_DIR}/wrong-role.err" 'Select Uninstall first, or rerun with --reconfigure'

run_installer "$IRAN_ROOT" "$RELEASE_JSON" '192.0.2.20' \
  --uninstall --yes >"${TMP_DIR}/uninstall.out"
assert_missing "${IRAN_ROOT}/etc/paqet-x"
assert_missing "${IRAN_ROOT}/usr/local/bin/paqet"
assert_missing "${IRAN_ROOT}/usr/local/sbin/paqetx"
assert_missing "${IRAN_ROOT}/etc/systemd/system/paqet-x.service"
assert_contains "${TMP_DIR}/uninstall.out" 'completely removed'

if MOCK_PAQET_PING_FAIL=1 run_installer "$PING_FAIL_ROOT" "$RELEASE_JSON" '192.0.2.40' \
  --role iran \
  --foreign-host 203.0.113.10 \
  --port 9999 \
  --key "$KEY" \
  --ports 443 \
  --protocol tcp \
  --interface eth0 \
  --local-ip 192.0.2.40 \
  --router-mac aa:bb:cc:dd:ee:ff \
  --yes >"${TMP_DIR}/ping-fail.out" 2>"${TMP_DIR}/ping-fail.err"; then
  fail 'Iran installation unexpectedly reported success when tunnel ping failed'
fi
assert_contains "${TMP_DIR}/ping-fail.err" 'the tunnel check failed'

if run_installer "$BAD_ROOT" "$BAD_RELEASE_JSON" '192.0.2.30' \
  --role abroad \
  --port 9999 \
  --key "$KEY" \
  --interface eth0 \
  --local-ip 192.0.2.30 \
  --router-mac aa:bb:cc:dd:ee:ff \
  --yes >"${TMP_DIR}/bad.out" 2>"${TMP_DIR}/bad.err"; then
  fail 'bad checksum installation unexpectedly succeeded'
fi
assert_contains "${TMP_DIR}/bad.err" 'SHA-256 verification failed'
assert_missing "${BAD_ROOT}/usr/local/bin/paqet"

printf 'Full mocked Abroad/Iran/uninstall integration tests passed.\n'
