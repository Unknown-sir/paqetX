#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

readonly PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly INSTALLER="${PROJECT_DIR}/paqet-x-install.sh"
TMP_DIR="$(mktemp -d -t paqet-x-integration.XXXXXXXX)"
trap 'rm -rf -- "$TMP_DIR"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
assert_file() { [[ -f "$1" ]] || fail "missing file: $1"; }
assert_executable() { [[ -x "$1" ]] || fail "not executable: $1"; }
assert_missing() { [[ ! -e "$1" ]] || fail "unexpected path: $1"; }
assert_contains() { grep -Fq -- "$2" "$1" || { printf 'Expected %s in %s\n' "$2" "$1" >&2; sed -n '1,260p' "$1" >&2 || true; exit 1; }; }
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

TPROXY_ASSET_NAME="hev-socks5-tproxy-linux-x86_64"
TPROXY_ASSET_PATH="${TMP_DIR}/${TPROXY_ASSET_NAME}"
cat > "$TPROXY_ASSET_PATH" <<'TPROXY'
#!/usr/bin/env bash
set -Eeuo pipefail
[[ -n "${1:-}" ]] || exit 2
exit 0
TPROXY
chmod +x "$TPROXY_ASSET_PATH"
TPROXY_SHA="$(sha256sum "$TPROXY_ASSET_PATH" | awk '{print $1}')"
TPROXY_RELEASE_JSON="${TMP_DIR}/tproxy-release.json"
cat > "$TPROXY_RELEASE_JSON" <<JSON
{
  "tag_name": "2.12.0",
  "assets": [
    {
      "name": "${TPROXY_ASSET_NAME}",
      "browser_download_url": "https://github.com/heiher/hev-socks5-tproxy/releases/download/2.12.0/${TPROXY_ASSET_NAME}",
      "digest": "sha256:${TPROXY_SHA}"
    }
  ]
}
JSON

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
  https://api.github.com/repos/heiher/hev-socks5-tproxy/releases/*)
    cp -- "${MOCK_TPROXY_RELEASE_JSON:?}" "${output:?}"
    ;;
  https://github.com/heiher/hev-socks5-tproxy/releases/download/*)
    cp -- "${MOCK_TPROXY_ASSET_PATH:?}" "${output:?}"
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

cat > "${MOCK_BIN}/ss" <<'MOCK_SS'
#!/usr/bin/env bash
set -Eeuo pipefail
# No occupied internal listener ports and no process data; SSH_CONNECTION is tested separately.
exit 0
MOCK_SS

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
  MOCK_TPROXY_RELEASE_JSON="$TPROXY_RELEASE_JSON" \
  MOCK_TPROXY_ASSET_PATH="$TPROXY_ASSET_PATH" \
  MOCK_LOCAL_IP="$local_ip" \
  SSH_CONNECTION="${MOCK_SSH_CONNECTION:-}" \
  NO_COLOR=1 \
  bash "$INSTALLER" "$@"
}

ABROAD_ROOT="${TMP_DIR}/abroad-root"
IRAN_SELECTED_ROOT="${TMP_DIR}/iran-selected-root"
IRAN_ALL_ROOT="${TMP_DIR}/iran-all-root"
BAD_ROOT="${TMP_DIR}/bad-root"
PING_FAIL_ROOT="${TMP_DIR}/ping-fail-root"
UNSAFE_ROOT="${TMP_DIR}/unsafe-root"
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
assert_missing "${ABROAD_ROOT}/usr/local/bin/hev-socks5-tproxy"
assert_contains "${ABROAD_ROOT}/etc/paqet-x/firewall.env" 'ROLE=abroad'
assert_contains "${ABROAD_ROOT}/usr/local/lib/paqet-x/firewall.sh" 'DNAT --to-destination 127.0.0.1'
assert_contains "${TMP_DIR}/abroad.out" 'Save these values for the Iran server'
assert_contains "${TMP_DIR}/abroad.out" "Shared key:   ${KEY}"

run_installer "$IRAN_SELECTED_ROOT" "$RELEASE_JSON" '192.0.2.20' \
  --role iran \
  --foreign-host 203.0.113.10 \
  --port 9999 \
  --key "$KEY" \
  --forward-mode selected \
  --ports 443,8443 \
  --protocol both \
  --ssh-ports 2222 \
  --interface eth0 \
  --local-ip 192.0.2.20 \
  --router-mac aa:bb:cc:dd:ee:ff \
  --yes >"${TMP_DIR}/iran-selected.out"

SELECTED_CONFIG="${IRAN_SELECTED_ROOT}/etc/paqet-x/config.yaml"
assert_file "$SELECTED_CONFIG"
assert_contains "$SELECTED_CONFIG" 'role: "client"'
assert_contains "$SELECTED_CONFIG" 'addr: "203.0.113.10:9999"'
assert_contains "$SELECTED_CONFIG" "key: \"${KEY}\""
assert_contains "$SELECTED_CONFIG" 'listen: "0.0.0.0:443"'
assert_contains "$SELECTED_CONFIG" 'target: "127.0.0.1:443"'
assert_contains "$SELECTED_CONFIG" 'protocol: "tcp"'
assert_contains "$SELECTED_CONFIG" 'protocol: "udp"'
assert_not_contains "$SELECTED_CONFIG" 'socks5:'
assert_missing "${IRAN_SELECTED_ROOT}/usr/local/bin/hev-socks5-tproxy"
[[ "$(grep -Fc 'listen: "0.0.0.0:443"' "$SELECTED_CONFIG")" == "2" ]] || fail 'port 443 was not configured for both protocols'
assert_contains "${IRAN_SELECTED_ROOT}/etc/paqet-x/firewall.env" 'FORWARD_PORTS=443/tcp,443/udp,8443/tcp,8443/udp'
assert_contains "${IRAN_SELECTED_ROOT}/etc/paqet-x/install.env" 'FORWARD_MODE=selected'
assert_contains "${TMP_DIR}/iran-selected.out" 'Iran service is listening on the selected forwarding ports'

MOCK_SSH_CONNECTION='198.51.100.20 40000 192.0.2.30 2222' run_installer "$IRAN_ALL_ROOT" "$RELEASE_JSON" '192.0.2.30' \
  --role iran \
  --foreign-host 203.0.113.10 \
  --port 9999 \
  --key "$KEY" \
  --all-ports \
  --exclude-ports 25,3306 \
  --exclude-ports 5432 \
  --protocol both \
  --interface eth0 \
  --local-ip 192.0.2.30 \
  --router-mac aa:bb:cc:dd:ee:ff \
  --yes >"${TMP_DIR}/iran-all.out"

ALL_CONFIG="${IRAN_ALL_ROOT}/etc/paqet-x/config.yaml"
ALL_STATE="${IRAN_ALL_ROOT}/etc/paqet-x/install.env"
ALL_FW_ENV="${IRAN_ALL_ROOT}/etc/paqet-x/firewall.env"
ALL_TPROXY_CONFIG="${IRAN_ALL_ROOT}/etc/paqet-x/tproxy.yaml"
assert_file "$ALL_CONFIG"
assert_contains "$ALL_CONFIG" 'role: "client"'
assert_contains "$ALL_CONFIG" 'socks5:'
assert_contains "$ALL_CONFIG" 'listen: "127.0.0.1:1080"'
assert_not_contains "$ALL_CONFIG" 'forward:'
assert_executable "${IRAN_ALL_ROOT}/usr/local/bin/hev-socks5-tproxy"
assert_file "$ALL_TPROXY_CONFIG"
assert_file "${IRAN_ALL_ROOT}/etc/systemd/system/paqet-x-tproxy.service"
assert_contains "$ALL_TPROXY_CONFIG" 'port: 1080'
assert_contains "$ALL_TPROXY_CONFIG" 'port: 61080'
assert_contains "$ALL_STATE" 'FORWARD_MODE=all'
assert_contains "$ALL_STATE" 'FORWARD_PROTOCOL=both'
assert_contains "$ALL_STATE" 'EXCLUDED_PORTS=25,3306,5432'
assert_contains "$ALL_STATE" 'SSH_PORTS=2222'
assert_contains "$ALL_STATE" 'TPROXY_VERSION=2.12.0'
assert_contains "$ALL_FW_ENV" 'TRANSPORT_PORT=9999'
assert_contains "$ALL_FW_ENV" 'EXCLUDED_PORTS=25,3306,5432'
assert_contains "$ALL_FW_ENV" 'SSH_PORTS=2222'
assert_contains "${IRAN_ALL_ROOT}/usr/local/lib/paqet-x/firewall.sh" 'PAQETX_ALLPORT'
assert_contains "${IRAN_ALL_ROOT}/usr/local/lib/paqet-x/firewall.sh" 'TPROXY --on-port'
assert_contains "${TMP_DIR}/iran-all.out" 'Forward mode:  all'
assert_contains "${TMP_DIR}/iran-all.out" 'SSH excluded:    2222'
assert_contains "${TMP_DIR}/iran-all.out" 'Extra excluded:  25,3306,5432'

# Execute the generated all-port firewall helper against logging mocks. This
# verifies exclusion ordering and policy-routing commands without touching the
# host firewall.
FW_TEST_DIR="${TMP_DIR}/firewall-unit"
FW_TEST_BIN="${FW_TEST_DIR}/bin"
mkdir -p "$FW_TEST_BIN"
FW_TEST_SCRIPT="${FW_TEST_DIR}/firewall.sh"
FW_TEST_ENV="${FW_TEST_DIR}/firewall.env"
FW_TEST_STATE="${FW_TEST_DIR}/firewall.state"
FW_TEST_LOG="${FW_TEST_DIR}/calls.log"
sed \
  -e "s|readonly ENV_FILE=\"/etc/paqet-x/firewall.env\"|readonly ENV_FILE=\"${FW_TEST_ENV}\"|" \
  -e "s|readonly STATE_FILE=\"/run/paqet-x-firewall.state\"|readonly STATE_FILE=\"${FW_TEST_STATE}\"|" \
  "${IRAN_ALL_ROOT}/usr/local/lib/paqet-x/firewall.sh" > "$FW_TEST_SCRIPT"
chmod +x "$FW_TEST_SCRIPT"
cp "$ALL_FW_ENV" "$FW_TEST_ENV"
cat > "${FW_TEST_BIN}/iptables" <<'MOCK_FW_IPTABLES'
#!/usr/bin/env bash
set -Eeuo pipefail
printf 'iptables' >> "${MOCK_FW_LOG:?}"
printf ' %q' "$@" >> "$MOCK_FW_LOG"
printf '\n' >> "$MOCK_FW_LOG"
for arg in "$@"; do
  [[ "$arg" == "-C" ]] && exit 1
done
exit 0
MOCK_FW_IPTABLES
cat > "${FW_TEST_BIN}/ip" <<'MOCK_FW_IP'
#!/usr/bin/env bash
set -Eeuo pipefail
printf 'ip' >> "${MOCK_FW_LOG:?}"
printf ' %q' "$@" >> "$MOCK_FW_LOG"
printf '\n' >> "$MOCK_FW_LOG"
[[ "${1:-}" == "rule" && "${2:-}" == "del" ]] && exit 1
exit 0
MOCK_FW_IP
cat > "${FW_TEST_BIN}/modprobe" <<'MOCK_FW_MODPROBE'
#!/usr/bin/env bash
exit 0
MOCK_FW_MODPROBE
chmod +x "${FW_TEST_BIN}"/*
PATH="${FW_TEST_BIN}:$PATH" MOCK_FW_LOG="$FW_TEST_LOG" "$FW_TEST_SCRIPT" start
assert_contains "$FW_TEST_LOG" '-A PAQETX_ALLPORT -p tcp --dport 9999 -j RETURN'
assert_contains "$FW_TEST_LOG" '-A PAQETX_ALLPORT -p tcp --dport 2222 -j RETURN'
assert_contains "$FW_TEST_LOG" '-A PAQETX_ALLPORT -p tcp --dport 25 -j RETURN'
assert_contains "$FW_TEST_LOG" '-A PAQETX_ALLPORT -p udp --dport 3306 -j RETURN'
assert_contains "$FW_TEST_LOG" '-p tcp -j TPROXY --on-port 61080 --tproxy-mark 1088/0x7ff'
assert_contains "$FW_TEST_LOG" '-p udp -j TPROXY --on-port 61080 --tproxy-mark 1088/0x7ff'
assert_contains "$FW_TEST_LOG" 'ip rule add fwmark 1088/0x7ff table 100'
assert_contains "$FW_TEST_LOG" 'ip route replace local 0.0.0.0/0 dev lo table 100'
PATH="${FW_TEST_BIN}:$PATH" MOCK_FW_LOG="$FW_TEST_LOG" "$FW_TEST_SCRIPT" stop
assert_contains "$FW_TEST_LOG" '-F PAQETX_ALLPORT'
assert_contains "$FW_TEST_LOG" 'ip route flush table 100'

# Verify the Abroad helper includes tunnel protection and owner-scoped local
# destination redirection used by same-port all-port forwarding.
ABROAD_FW_SCRIPT="${FW_TEST_DIR}/abroad-firewall.sh"
cp "${ABROAD_ROOT}/etc/paqet-x/firewall.env" "$FW_TEST_ENV"
sed \
  -e "s|readonly ENV_FILE=\"/etc/paqet-x/firewall.env\"|readonly ENV_FILE=\"${FW_TEST_ENV}\"|" \
  -e "s|readonly STATE_FILE=\"/run/paqet-x-firewall.state\"|readonly STATE_FILE=\"${FW_TEST_STATE}\"|" \
  "${ABROAD_ROOT}/usr/local/lib/paqet-x/firewall.sh" > "$ABROAD_FW_SCRIPT"
chmod +x "$ABROAD_FW_SCRIPT"
: > "$FW_TEST_LOG"
PATH="${FW_TEST_BIN}:$PATH" MOCK_FW_LOG="$FW_TEST_LOG" "$ABROAD_FW_SCRIPT" start
assert_contains "$FW_TEST_LOG" '-t raw -I PREROUTING -p tcp --dport 9999 -j NOTRACK'
assert_contains "$FW_TEST_LOG" '-m owner --uid-owner 65534 -p tcp \! --sport 9999 -j DNAT --to-destination 127.0.0.1'
assert_contains "$FW_TEST_LOG" '-m owner --uid-owner 65534 -p udp -j DNAT --to-destination 127.0.0.1'

CONFIG_SHA_BEFORE="$(sha256sum "$ALL_CONFIG" | awk '{print $1}')"
run_installer "$IRAN_ALL_ROOT" "$RELEASE_JSON" '192.0.2.30' \
  --role iran \
  --foreign-host 198.51.100.9 \
  --ports 2053 \
  --protocol udp \
  --yes >"${TMP_DIR}/rerun.out" 2>"${TMP_DIR}/rerun.err"
CONFIG_SHA_AFTER="$(sha256sum "$ALL_CONFIG" | awk '{print $1}')"
[[ "$CONFIG_SHA_BEFORE" == "$CONFIG_SHA_AFTER" ]] || fail 'normal rerun changed preserved all-port Iran config'
assert_contains "${TMP_DIR}/rerun.err" 'configuration options were ignored'
assert_contains "$ALL_STATE" 'FOREIGN_HOST=203.0.113.10'
assert_contains "$ALL_STATE" 'EXCLUDED_PORTS=25,3306,5432'

if run_installer "$IRAN_ALL_ROOT" "$RELEASE_JSON" '192.0.2.30' \
  --role abroad --yes >"${TMP_DIR}/wrong-role.out" 2>"${TMP_DIR}/wrong-role.err"; then
  fail 'role replacement without reconfigure unexpectedly succeeded'
fi
assert_contains "${TMP_DIR}/wrong-role.err" 'Select Uninstall first, or rerun with --reconfigure'

if run_installer "$UNSAFE_ROOT" "$RELEASE_JSON" '192.0.2.50' \
  --role iran --foreign-host 203.0.113.10 --port 9999 --key "$KEY" \
  --ports 2222 --protocol tcp --ssh-ports 2222 \
  --interface eth0 --local-ip 192.0.2.50 --router-mac aa:bb:cc:dd:ee:ff --yes \
  >"${TMP_DIR}/unsafe.out" 2>"${TMP_DIR}/unsafe.err"; then
  fail 'selected forwarding of the active SSH port unexpectedly succeeded'
fi
assert_contains "${TMP_DIR}/unsafe.err" 'is an active SSH port'

run_installer "$IRAN_ALL_ROOT" "$RELEASE_JSON" '192.0.2.30' \
  --uninstall --yes >"${TMP_DIR}/uninstall.out"
assert_missing "${IRAN_ALL_ROOT}/etc/paqet-x"
assert_missing "${IRAN_ALL_ROOT}/usr/local/bin/paqet"
assert_missing "${IRAN_ALL_ROOT}/usr/local/bin/hev-socks5-tproxy"
assert_missing "${IRAN_ALL_ROOT}/usr/local/sbin/paqetx"
assert_missing "${IRAN_ALL_ROOT}/etc/systemd/system/paqet-x.service"
assert_missing "${IRAN_ALL_ROOT}/etc/systemd/system/paqet-x-tproxy.service"
assert_contains "${TMP_DIR}/uninstall.out" 'completely removed'

if MOCK_PAQET_PING_FAIL=1 run_installer "$PING_FAIL_ROOT" "$RELEASE_JSON" '192.0.2.40' \
  --role iran \
  --foreign-host 203.0.113.10 \
  --port 9999 \
  --key "$KEY" \
  --ports 443 \
  --protocol tcp \
  --ssh-ports 2222 \
  --interface eth0 \
  --local-ip 192.0.2.40 \
  --router-mac aa:bb:cc:dd:ee:ff \
  --yes >"${TMP_DIR}/ping-fail.out" 2>"${TMP_DIR}/ping-fail.err"; then
  fail 'Iran installation unexpectedly reported success when tunnel ping failed'
fi
assert_contains "${TMP_DIR}/ping-fail.err" 'the tunnel check failed'

if run_installer "$BAD_ROOT" "$BAD_RELEASE_JSON" '192.0.2.60' \
  --role abroad \
  --port 9999 \
  --key "$KEY" \
  --interface eth0 \
  --local-ip 192.0.2.60 \
  --router-mac aa:bb:cc:dd:ee:ff \
  --yes >"${TMP_DIR}/bad.out" 2>"${TMP_DIR}/bad.err"; then
  fail 'bad checksum installation unexpectedly succeeded'
fi
assert_contains "${TMP_DIR}/bad.err" 'SHA-256 verification failed'
assert_missing "${BAD_ROOT}/usr/local/bin/paqet"

printf 'Full mocked selected/all-port Abroad/Iran/uninstall integration tests passed.\n'
