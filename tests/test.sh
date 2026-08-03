#!/usr/bin/env bash
set -Eeuo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
SCRIPT="$ROOT/install.sh"
BIN="$ROOT/Paqet-Xv2"
EXPECTED_CORE_SHA="4ece7681bdc6f339307c269bec0ca1a2abd2edc4db1d3b8c644b687d91e061d2"

fail(){ echo "FAIL: $*" >&2; exit 1; }
assert_file(){ [[ -f "$1" ]] || fail "missing file $1"; }
assert_grep(){ grep -Eq -- "$1" "$2" || fail "pattern $1 not found in $2"; }
assert_not_grep(){ ! grep -Eq -- "$1" "$2" || fail "unexpected pattern $1 in $2"; }

bash -n "$SCRIPT"
actual=$(sha256sum "$BIN" | awk '{print $1}')
[[ "$actual" == "$EXPECTED_CORE_SHA" ]] || fail "core binary checksum mismatch"
assert_grep 'readonly SCRIPT_VERSION="5\.2\.0"' "$SCRIPT"
assert_grep 'readonly HEV_VERSION="2\.12\.0"' "$SCRIPT"
assert_grep 'readonly PROJECT_REPOSITORY="Unknown-sir/paqetX"' "$SCRIPT"

# Utility functions are sourceable; main menu must not start on source.
# Use a child shell so readonly globals from the real installer cannot collide
# with the path-rewritten installer sourced later in this test.
SCRIPT="$SCRIPT" bash -c '
  set -Eeuo pipefail
  source "$SCRIPT"
  [[ "$(normalize_csv "25, 3306,5000-5010,3306,bad,70000")" == "25,3306,5000-5010" ]]
  csv_contains_port "25,5000-5010" 5005
  validate_ip 203.0.113.10
  ! validate_ip 300.1.1.1
  [[ "$(service_user_for client)" =~ ^pqx-[0-9a-f]{12}$ ]]
  validate_secret_key "abcDEF123._:@+=/-"
  ! validate_secret_key "bad key with spaces"
' || fail "utility functions"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/etc/systemd/system" "$TMP/etc/paqet-x/state" "$TMP/usr/local/libexec/paqet-x" "$TMP/usr/local/bin"
cp "$SCRIPT" "$TMP/test-install.sh"
sed -i \
  -e "s#readonly BIN_DIR=\"/usr/local/bin\"#readonly BIN_DIR=\"$TMP/usr/local/bin\"#" \
  -e "s#readonly INSTALL_DIR=\"/opt/paqet-x\"#readonly INSTALL_DIR=\"$TMP/opt/paqet-x\"#" \
  -e "s#readonly CONFIG_DIR=\"/etc/paqet-x\"#readonly CONFIG_DIR=\"$TMP/etc/paqet-x\"#" \
  -e "s#readonly SERVICE_DIR=\"/etc/systemd/system\"#readonly SERVICE_DIR=\"$TMP/etc/systemd/system\"#" \
  -e "s#readonly LIBEXEC_DIR=\"/usr/local/libexec/paqet-x\"#readonly LIBEXEC_DIR=\"$TMP/usr/local/libexec/paqet-x\"#" \
  "$TMP/test-install.sh"

# shellcheck disable=SC1090
source "$TMP/test-install.sh"
systemctl(){
  case "${1:-}" in is-active) return 0;; *) return 0;; esac
}
show_banner(){ :; }
pause(){ :; }
get_network_info(){ NETWORK_INTERFACE=eth0; LOCAL_IP=192.0.2.10; GATEWAY_IP=192.0.2.1; GATEWAY_MAC=02:00:00:00:00:01; }
get_public_ip(){ echo 198.51.100.20; }
ensure_service_user(){ echo root; }
remove_service_user(){ :; }
install_paqet(){ touch "$BIN_DIR/$BIN_NAME"; chmod +x "$BIN_DIR/$BIN_NAME"; }
install_hev(){ touch "$HEV_BIN"; chmod +x "$HEV_BIN"; }
setup_auto_restart(){ :; }
remove_auto_restart(){ :; }
iptables(){ return 0; }
port_is_listening(){ return 1; }
detect_ssh_ports(){ echo 22,2222; }

# Reconfiguration cleanup must remove the main unit and all helper assets.
touch "$TMP/etc/systemd/system/paqet-x-old.service"       "$TMP/etc/systemd/system/paqet-x-old-firewall.service"       "$TMP/etc/systemd/system/paqet-x-old-tproxy.service"       "$TMP/usr/local/libexec/paqet-x/firewall-old.sh"       "$TMP/etc/paqet-x/old-tproxy.yaml"       "$TMP/etc/paqet-x/state/old.env"
chmod +x "$TMP/usr/local/libexec/paqet-x/firewall-old.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$TMP/usr/local/libexec/paqet-x/firewall-old.sh"
remove_tunnel_assets old
[[ ! -e "$TMP/etc/systemd/system/paqet-x-old.service" ]] || fail "main service cleanup"
[[ ! -e "$TMP/etc/systemd/system/paqet-x-old-firewall.service" ]] || fail "firewall service cleanup"
[[ ! -e "$TMP/etc/systemd/system/paqet-x-old-tproxy.service" ]] || fail "tproxy service cleanup"

# Generate firewall assets and verify their syntax and important behavior.
create_firewall_assets serverf server 9999 forward tcp '' '' '' '' root ''
create_firewall_assets servers server 9999 socks5 tcp '' '' '' '' root ''
create_firewall_assets selected client 9999 selected tcp '' '' '' '' root '443/tcp,53/udp'
create_firewall_assets allclient client 9999 all both '25,3306,5000-5010,22,2222,9999' '22,2222' 1088 1080 root ''
for f in "$TMP/usr/local/libexec/paqet-x"/*.sh; do bash -n "$f"; done
assert_grep "MODE='forward'" "$TMP/usr/local/libexec/paqet-x/firewall-serverf.sh"
assert_grep '\[ "\$ROLE" = server \] && \[ "\$MODE" = forward \]' "$TMP/usr/local/libexec/paqet-x/firewall-serverf.sh"
assert_grep "FORWARDS='443/tcp,53/udp'" "$TMP/usr/local/libexec/paqet-x/firewall-selected.sh"
assert_grep 'add filter INPUT -p "\$proto" --dport "\$port" -j ACCEPT' "$TMP/usr/local/libexec/paqet-x/firewall-selected.sh"
assert_grep 'ALLPORT_CHAIN=.PQX_ALLPORT.' "$TMP/usr/local/libexec/paqet-x/firewall-allclient.sh"
assert_grep '\[ "\$MODE" != all \] \|\| CHAIN="\$ALLPORT_CHAIN"' "$TMP/usr/local/libexec/paqet-x/firewall-allclient.sh"
assert_grep 'tcp --sport "\$TUNNEL_PORT" -j RETURN' "$TMP/usr/local/libexec/paqet-x/firewall-allclient.sh"
assert_grep 'TPROXY --on-ip 127.0.0.1' "$TMP/usr/local/libexec/paqet-x/firewall-allclient.sh"
assert_grep '5000.*5001|BASH_REMATCH' "$TMP/usr/local/libexec/paqet-x/firewall-allclient.sh"
assert_grep 'TABLE=.10088.' "$TMP/usr/local/libexec/paqet-x/firewall-allclient.sh"

# Run generated firewall starts with command mocks and inspect actual commands.
MOCK="$TMP/mockbin"; mkdir -p "$MOCK"; LOG="$TMP/firewall.log"; export LOG
cat > "$MOCK/iptables" <<'MOCK'
#!/usr/bin/env bash
printf 'iptables' >> "$LOG"; printf ' %q' "$@" >> "$LOG"; printf '\n' >> "$LOG"
for a in "$@"; do
  if [[ "$a" == -S ]]; then
    printf '%s\n' '-N PQX_deadbeef0000' '-N PQX_ALLPORT'
    exit 0
  fi
done
for a in "$@"; do [[ "$a" == -C || "$a" == -D ]] && exit 1; done
exit 0
MOCK
cat > "$MOCK/ip" <<'MOCK'
#!/usr/bin/env bash
printf 'ip' >> "$LOG"; printf ' %q' "$@" >> "$LOG"; printf '\n' >> "$LOG"
[[ "${1:-}" == rule && "${2:-}" == del ]] && exit 1
exit 0
MOCK
for cmd in sysctl modprobe; do
cat > "$MOCK/$cmd" <<MOCK
#!/usr/bin/env bash
printf '$cmd' >> "\$LOG"; printf ' %q' "\$@" >> "\$LOG"; printf '\n' >> "\$LOG"
exit 0
MOCK
done
chmod +x "$MOCK"/*
PATH="$MOCK:$PATH" "$TMP/usr/local/libexec/paqet-x/firewall-serverf.sh" start
assert_grep 'nat.*-I.*OUTPUT.*--uid-owner.*--sport.*REDIRECT' "$LOG"
: > "$LOG"
PATH="$MOCK:$PATH" "$TMP/usr/local/libexec/paqet-x/firewall-servers.sh" start
assert_not_grep 'nat.*-I.*OUTPUT.*REDIRECT' "$LOG"
: > "$LOG"
PATH="$MOCK:$PATH" "$TMP/usr/local/libexec/paqet-x/firewall-selected.sh" start
assert_grep 'filter.*-I.*INPUT.*--dport.*443.*ACCEPT' "$LOG"
assert_grep 'filter.*-I.*INPUT.*--dport.*53.*ACCEPT' "$LOG"
: > "$LOG"
PATH="$MOCK:$PATH" "$TMP/usr/local/libexec/paqet-x/firewall-allclient.sh" start
assert_grep 'mangle.*--sport.*9999.*RETURN' "$LOG"
assert_grep 'mangle.*--dport.*22.*RETURN' "$LOG"
assert_grep 'mangle.*--dport.*2222.*RETURN' "$LOG"
assert_grep 'mangle.*--dport.*5000:5010.*RETURN' "$LOG"
assert_grep 'mangle.*-p.*tcp.*TPROXY' "$LOG"
assert_grep 'mangle.*-p.*udp.*TPROXY' "$LOG"
assert_grep 'mangle.*-F.*PQX_deadbeef0000' "$LOG"
assert_grep 'mangle.*-X.*PQX_deadbeef0000' "$LOG"
assert_grep 'ip rule add fwmark.*10088' "$LOG"
tcp_ex=$(grep -nE 'mangle.*-A.*PQX_ALLPORT.*-p.*tcp.*--dport.*25.*RETURN' "$LOG" | head -1 | cut -d: -f1)
tcp_tp=$(grep -nE 'mangle.*-A.*PQX_ALLPORT.*-p.*tcp.*TPROXY' "$LOG" | head -1 | cut -d: -f1)
udp_ex=$(grep -nE 'mangle.*-A.*PQX_ALLPORT.*-p.*udp.*--dport.*25.*RETURN' "$LOG" | head -1 | cut -d: -f1)
udp_tp=$(grep -nE 'mangle.*-A.*PQX_ALLPORT.*-p.*udp.*TPROXY' "$LOG" | head -1 | cut -d: -f1)
[[ -n "$tcp_ex" && -n "$tcp_tp" && "$tcp_ex" -lt "$tcp_tp" ]] || fail "TCP exclusion must precede TPROXY"
[[ -n "$udp_ex" && -n "$udp_tp" && "$udp_ex" -lt "$udp_tp" ]] || fail "UDP exclusion must precede TPROXY"

# Integration: generate server, selected client, and all-port client configs using mocked host actions.
rm -f "$TMP/etc/paqet-x"/*.yaml "$TMP/etc/paqet-x/state"/*.env 2>/dev/null || true
printf '%s\n' \
  server 9999 secret123 '' '' '' '' 1 \
  | configure_server >/dev/null 2>&1
assert_file "$TMP/etc/paqet-x/server.yaml"
assert_grep '^role: "server"' "$TMP/etc/paqet-x/server.yaml"
assert_grep '^MODE=forward$' "$TMP/etc/paqet-x/state/server.env"

printf '%s\n' \
  selected 203.0.113.10 9999 secret123 '' '' '' '' 1 1 '443,53' 1 2 \
  | configure_client >/dev/null 2>&1
assert_file "$TMP/etc/paqet-x/selected.yaml"
assert_grep '^forward:' "$TMP/etc/paqet-x/selected.yaml"
assert_grep 'listen: "0.0.0.0:443"' "$TMP/etc/paqet-x/selected.yaml"
assert_grep 'protocol: "udp"' "$TMP/etc/paqet-x/selected.yaml"

printf '%s\n' \
  all 203.0.113.10 9999 secret123 '' '' '' '' 1 2 '25,3306,5000-5010' y \
  | configure_client >/dev/null 2>&1
assert_file "$TMP/etc/paqet-x/all.yaml"
assert_grep '^socks5:' "$TMP/etc/paqet-x/all.yaml"
assert_not_grep '^forward:' "$TMP/etc/paqet-x/all.yaml"
assert_grep '^MODE=all$' "$TMP/etc/paqet-x/state/all.env"
assert_grep '^PROTOCOL=both$' "$TMP/etc/paqet-x/state/all.env"
assert_grep '^SSH_PORTS=22,2222$' "$TMP/etc/paqet-x/state/all.env"
assert_grep 'EXCLUSIONS=.*25.*3306.*5000-5010.*9999.*22.*2222' "$TMP/etc/paqet-x/state/all.env"
assert_file "$TMP/etc/paqet-x/all-tproxy.yaml"
python - <<PY
import yaml
for path in [
    '$TMP/etc/paqet-x/server.yaml',
    '$TMP/etc/paqet-x/selected.yaml',
    '$TMP/etc/paqet-x/all.yaml',
    '$TMP/etc/paqet-x/all-tproxy.yaml',
]:
    with open(path, encoding='utf-8') as f:
        data=yaml.safe_load(f)
    assert isinstance(data, dict), path
PY

echo "All tests passed"
