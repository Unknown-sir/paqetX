#!/usr/bin/env bash
# Paqet X — guided dual-server installer with explicit Abroad, Iran, and uninstall flows.
# Repository: https://github.com/Unknown-sir/paqetX
# Upstream core: https://github.com/hanselime/paqet

set -Eeuo pipefail
IFS=$'\n\t'
umask 077

readonly INSTALLER_VERSION="4.2.0"
readonly INSTALLER_REPOSITORY="Unknown-sir/paqetX"
readonly UPSTREAM_REPOSITORY="hanselime/paqet"
readonly API_BASE="https://api.github.com/repos/${UPSTREAM_REPOSITORY}"
readonly TPROXY_REPOSITORY="heiher/hev-socks5-tproxy"
readonly TPROXY_API_BASE="https://api.github.com/repos/${TPROXY_REPOSITORY}"
readonly DEFAULT_TPROXY_VERSION="2.12.0"
readonly SERVICE_USER="paqetx"

# Internal test isolation. A root prefix is rejected unless explicit test mode is enabled.
ROOT_PREFIX="${PAQETX_ROOT_PREFIX:-}"
if [[ -n "$ROOT_PREFIX" ]]; then
  if [[ "${PAQETX_TEST_MODE:-0}" != "1" || "$ROOT_PREFIX" != /* || "$ROOT_PREFIX" == "/" ]]; then
    printf 'Invalid PAQETX_ROOT_PREFIX test configuration.
' >&2
    exit 2
  fi
  ROOT_PREFIX="${ROOT_PREFIX%/}"
fi
readonly ROOT_PREFIX

readonly BIN_PATH="${ROOT_PREFIX}/usr/local/bin/paqet"
readonly MANAGER_PATH="${ROOT_PREFIX}/usr/local/sbin/paqetx"
readonly TPROXY_BIN_PATH="${ROOT_PREFIX}/usr/local/bin/hev-socks5-tproxy"
readonly CONFIG_DIR="${ROOT_PREFIX}/etc/paqet-x"
readonly CONFIG_PATH="${CONFIG_DIR}/config.yaml"
readonly TPROXY_CONFIG_PATH="${CONFIG_DIR}/tproxy.yaml"
readonly LEGACY_CONFIG_PATH="${CONFIG_DIR}/server.yaml"
readonly STATE_PATH="${CONFIG_DIR}/install.env"
readonly LEGACY_TOKEN_PATH="${CONFIG_DIR}/connection.txt"
readonly FIREWALL_ENV="${CONFIG_DIR}/firewall.env"
readonly LIB_DIR="${ROOT_PREFIX}/usr/local/lib/paqet-x"
readonly FIREWALL_SCRIPT="${LIB_DIR}/firewall.sh"
readonly STATE_DIR="${ROOT_PREFIX}/var/lib/paqet-x"
readonly VERSION_FILE="${STATE_DIR}/version"
readonly FIREWALL_RUNTIME_STATE="${ROOT_PREFIX}/run/paqet-x-firewall.state"
readonly SERVICE_NAME="paqet-x.service"
readonly FIREWALL_SERVICE_NAME="paqet-x-firewall.service"
readonly TPROXY_SERVICE_NAME="paqet-x-tproxy.service"
readonly SERVICE_PATH="${ROOT_PREFIX}/etc/systemd/system/${SERVICE_NAME}"
readonly FIREWALL_SERVICE_PATH="${ROOT_PREFIX}/etc/systemd/system/${FIREWALL_SERVICE_NAME}"
readonly TPROXY_SERVICE_PATH="${ROOT_PREFIX}/etc/systemd/system/${TPROXY_SERVICE_NAME}"
readonly GITHUB_API_VERSION="2026-03-10"
readonly DEFAULT_PAQET_VERSION="v1.0.0-alpha.20"

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  readonly RED=$'\033[0;31m'
  readonly GREEN=$'\033[0;32m'
  readonly YELLOW=$'\033[1;33m'
  readonly BLUE=$'\033[0;34m'
  readonly BOLD=$'\033[1m'
  readonly RESET=$'\033[0m'
else
  readonly RED="" GREEN="" YELLOW="" BLUE="" BOLD="" RESET=""
fi

TMP_DIR=""
CURRENT_STEP="initialization"
STEP_NUMBER=0
TOTAL_STEPS=9

log_info()    { printf '%s[INFO]%s %s\n' "$BLUE" "$RESET" "$*"; }
log_success() { printf '%s[ OK ]%s %s\n' "$GREEN" "$RESET" "$*"; }
log_warn()    { printf '%s[WARN]%s %s\n' "$YELLOW" "$RESET" "$*" >&2; }
log_error()   { printf '%s[FAIL]%s %s\n' "$RED" "$RESET" "$*" >&2; }
die()         { log_error "$*"; exit 1; }

step() {
  STEP_NUMBER=$((STEP_NUMBER + 1))
  CURRENT_STEP="$*"
  printf '\n%s[%d/%d]%s %s%s%s\n' "$BLUE" "$STEP_NUMBER" "$TOTAL_STEPS" "$RESET" "$BOLD" "$*" "$RESET"
}

cleanup() {
  if [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]]; then
    rm -rf -- "$TMP_DIR"
  fi
  return 0
}

on_error() {
  local code=$?
  local line_no="${BASH_LINENO[0]:-unknown}"
  log_error "Installation stopped during: ${CURRENT_STEP}"
  log_error "Line ${line_no}: ${BASH_COMMAND:-unknown} (exit ${code})"
  exit "$code"
}

trap cleanup EXIT
trap on_error ERR

usage() {
  cat <<'USAGE'
Paqet X guided installer

Run interactively:
  curl -fsSL https://raw.githubusercontent.com/Unknown-sir/paqetX/main/paqet-x-install.sh | sudo bash

Interactive menu:
  1) Install Abroad server
  2) Install Iran server
  3) Uninstall Paqet X completely
  4) Exit

Installation flow:
  Abroad: installs only the Paqet server service, asks for the tunnel port,
          generates the shared key, and prints both values.
  Iran:   asks for the Abroad host, tunnel port, shared key, protocol, and one
          forwarding mode:
          - selected ports supplied by the user; or
          - every TCP/UDP port except the tunnel port, automatically detected
            SSH ports, and additional exclusions supplied by the user.

Non-interactive examples:
  # Abroad server
  sudo bash paqet-x-install.sh --role abroad --port 9999 --yes

  # Iran: selected ports, TCP and UDP
  sudo bash paqet-x-install.sh --role iran \
    --foreign-host 203.0.113.10 --port 9999 \
    --key 'PASTE-KEY-FROM-ABROAD' \
    --forward-mode selected --ports 443,8443 --protocol both --yes

  # Iran: all TCP and UDP ports except auto-detected SSH, tunnel, and exclusions
  sudo bash paqet-x-install.sh --role iran \
    --foreign-host 203.0.113.10 --port 9999 \
    --key 'PASTE-KEY-FROM-ABROAD' \
    --all-ports --exclude-ports 25,3306,5432 --protocol both --yes

  # Remove all installed Paqet X files, helpers, users, and firewall rules
  sudo bash paqet-x-install.sh --uninstall --yes

Options:
  --role ROLE                 abroad|iran (aliases: server|client|kharej|foreign)
  --port PORT                 Paqet tunnel/transport port, 1024-65535; not 80/443
  --foreign-host HOST         Public IPv4/DNS name of the Abroad server (Iran only)
  --key KEY                   Shared key printed by the Abroad installation
  --forward-mode MODE         selected|all (Iran only)
  --all-ports                 Alias for --forward-mode all
  --ports LIST                Comma-separated selected ports, e.g. 443,8443,2053
  --protocol MODE             tcp|udp|both (default: tcp with --yes)
  --exclude-ports LIST        Additional ports excluded from all-port mode
                              (repeatable; comma-separated)
  --ssh-ports LIST            Override auto-detected SSH ports (advanced)
  --forward SPEC              Advanced selected mapping: PORT, LOCAL:TARGET,
                              or LOCAL:TARGET/protocol
  --listen-ip IPV4            Selected-mode listener address (default: 0.0.0.0)
  --interface NAME            Override detected network interface
  --local-ip IPV4             Override detected local IPv4
  --router-mac MAC            Override detected gateway MAC
  --no-open-forward-ports     Do not add local INPUT rules in selected mode
  --reconfigure               Back up and replace an existing configuration
  --force-config              Alias for --reconfigure
  --uninstall                 Remove services, binaries, config, state, user,
                              routing rules, and firewall rules
  --no-start                  Install files without starting services
  --yes                       Accept defaults or confirm uninstall without prompting
  --help                      Show this help

All-port mode notes:
  Paqet itself exposes individual port forwards only. Paqet X therefore enables
  Paqet's local SOCKS5 listener plus the verified HevSocks5TProxy helper and
  Linux TPROXY rules. Incoming traffic keeps its original port number, while the
  Abroad Paqet service redirects Paqet-created destination sockets to
  127.0.0.1 on the same port. Tunnel packets are explicitly bypassed on both
  hosts to prevent transparent-proxy recapture and reconnect loops.

Rerun behavior:
  A normal rerun preserves the existing role and configuration. Use
  --reconfigure to replace it, or select Uninstall from the interactive menu.
USAGE
}
trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

validate_boolean() { [[ "$2" == "0" || "$2" == "1" ]] || die "$1 must be 0 or 1"; }

validate_port() {
  local port="$1"
  [[ "$port" =~ ^[0-9]+$ ]] || return 1
  ((10#$port >= 1 && 10#$port <= 65535))
}

validate_transport_port() {
  local port="$1"
  validate_port "$port" || die "Invalid Paqet transport port: ${port}"
  [[ "$port" != "80" && "$port" != "443" ]] || die "Do not use port 80 or 443 as the Paqet transport port"
  ((10#$port >= 1024)) || die "Paqet transport port must be between 1024 and 65535"
}

validate_ipv4() {
  local ip="$1" part
  local -a octets
  IFS='.' read -r -a octets <<<"$ip"
  ((${#octets[@]} == 4)) || return 1
  for part in "${octets[@]}"; do
    [[ "$part" =~ ^[0-9]{1,3}$ ]] || return 1
    ((10#$part >= 0 && 10#$part <= 255)) || return 1
  done
}

validate_host() {
  local host="$1"
  [[ ${#host} -ge 1 && ${#host} -le 253 ]] || return 1
  [[ "$host" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]] || return 1
  [[ "$host" != *".."* ]]
}

validate_interface() { [[ "$1" =~ ^[A-Za-z0-9_.:@-]+$ ]]; }
validate_mac() { [[ "$1" =~ ^([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}$ ]]; }
validate_key() { [[ "$1" =~ ^[A-Za-z0-9._~-]{16,128}$ ]]; }
validate_release_tag() { [[ "$1" == "latest" || "$1" =~ ^v?[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]]; }
validate_kcp_mode() { [[ "$1" == "normal" || "$1" == "fast" || "$1" == "fast2" || "$1" == "fast3" ]]; }
validate_block() {
  case "$1" in
    aes|aes-128|aes-128-gcm|aes-192|salsa20|blowfish|twofish|cast5|3des|tea|xtea|xor|sm4) return 0 ;;
    *) return 1 ;;
  esac
}

normalize_role() {
  case "${1,,}" in
    abroad|server|kharej|foreign|outside) printf 'abroad' ;;
    iran|client|entry) printf 'iran' ;;
    *) return 1 ;;
  esac
}

normalize_forward_mode() {
  case "${1,,}" in
    selected|select|ports|manual|1) printf 'selected' ;;
    all|all-ports|every|2) printf 'all' ;;
    *) return 1 ;;
  esac
}

append_unique_port() {
  local array_name="$1" raw="$2" port existing
  local -n target_array="$array_name"
  raw="$(trim "$raw")"
  validate_port "$raw" || die "Invalid port: ${raw}"
  port="$((10#$raw))"
  for existing in "${target_array[@]:-}"; do
    [[ "$existing" == "$port" ]] && return 0
  done
  target_array+=("$port")
}

append_port_list() {
  local array_name="$1" value="$2" item
  local -a parts=()
  IFS=',' read -r -a parts <<<"$value"
  for item in "${parts[@]}"; do
    item="$(trim "$item")"
    [[ -n "$item" ]] || continue
    append_unique_port "$array_name" "$item"
  done
}

ports_csv() {
  local array_name="$1" joined="" port
  local -n values="$array_name"
  for port in "${values[@]:-}"; do
    [[ -n "$joined" ]] && joined+=","
    joined+="$port"
  done
  printf '%s' "$joined"
}

port_is_listed() {
  local needle="$1" array_name="$2" port
  local -n values="$array_name"
  for port in "${values[@]:-}"; do
    [[ "$port" == "$needle" ]] && return 0
  done
  return 1
}

canonical_forward() {
  local raw spec protocol="tcp" listen_port target_port
  raw="$(trim "$1")"
  [[ -n "$raw" ]] || return 1

  if [[ "$raw" =~ ^(.+)/(tcp|udp)$ ]]; then
    spec="${BASH_REMATCH[1]}"
    protocol="${BASH_REMATCH[2]}"
  elif [[ "$raw" == */* ]]; then
    return 1
  else
    spec="$raw"
  fi

  if [[ "$spec" =~ ^([0-9]+):([0-9]+)$ ]]; then
    listen_port="${BASH_REMATCH[1]}"
    target_port="${BASH_REMATCH[2]}"
  elif [[ "$spec" =~ ^[0-9]+$ ]]; then
    listen_port="$spec"
    target_port="$spec"
  else
    return 1
  fi

  if ! validate_port "$listen_port" || ! validate_port "$target_port"; then return 1; fi
  printf '%s:%s/%s' "$((10#$listen_port))" "$((10#$target_port))" "$protocol"
}

append_forward_values() {
  local value="$1" item canonical existing
  local -a parts
  IFS=',' read -r -a parts <<<"$value"
  for item in "${parts[@]}"; do
    item="$(trim "$item")"
    [[ -n "$item" ]] || continue
    canonical="$(canonical_forward "$item")" || die "Invalid forward mapping: ${item}. Use PORT or LOCAL:TARGET[/tcp|udp]"
    for existing in "${FORWARD_SPECS[@]}"; do
      if [[ "${existing%%:*}/${existing##*/}" == "${canonical%%:*}/${canonical##*/}" ]]; then
        die "Duplicate Iran listener/protocol in forward mappings: ${canonical}"
      fi
    done
    FORWARD_SPECS+=("$canonical")
  done
}

forward_specs_csv() {
  local joined="" spec
  for spec in "${FORWARD_SPECS[@]}"; do
    [[ -n "$joined" ]] && joined+=","
    joined+="$spec"
  done
  printf '%s' "$joined"
}

tty_available() { [[ -r /dev/tty && -w /dev/tty ]] && [[ -t 0 || -t 1 || -t 2 ]]; }

prompt_value() {
  local __var="$1" label="$2" default="${3:-}" secret="${4:-0}" answer=""
  tty_available || die "Interactive input is unavailable. Supply all required options explicitly"
  if [[ -n "$default" ]]; then
    printf '%s [%s]: ' "$label" "$default" > /dev/tty
  else
    printf '%s: ' "$label" > /dev/tty
  fi
  if [[ "$secret" == "1" ]]; then
    IFS= read -r -s answer < /dev/tty
    printf '\n' > /dev/tty
  else
    IFS= read -r answer < /dev/tty
  fi
  [[ -n "$answer" ]] || answer="$default"
  printf -v "$__var" '%s' "$answer"
}

prompt_action() {
  local choice=""
  tty_available || die "Interactive input is unavailable. Use --role abroad, --role iran, or --uninstall"
  cat > /dev/tty <<'MENU'

Paqet X / پکت ایکس
  1) Install Abroad / نصب سرور خارج
  2) Install Iran / نصب سرور ایران
  3) Uninstall completely / حذف کامل
  4) Exit / خروج
MENU
  while true; do
    printf 'Choice [1-4]: ' > /dev/tty
    IFS= read -r choice < /dev/tty
    case "$choice" in
      1) printf 'install:abroad'; return 0 ;;
      2) printf 'install:iran'; return 0 ;;
      3) printf 'uninstall:'; return 0 ;;
      4) printf 'exit:'; return 0 ;;
      *) printf 'Please enter 1, 2, 3, or 4.\n' > /dev/tty ;;
    esac
  done
}

prompt_forward_mode() {
  local choice=""
  tty_available || die "Forward mode is required in non-interactive mode: --forward-mode selected|all"
  cat > /dev/tty <<'MENU'

Select forwarding mode / روش فوروارد را انتخاب کنید:
  1) Selected ports / پورت‌های انتخابی
  2) All ports except tunnel, SSH, and exclusions / همه پورت‌ها به‌جز تونل، SSH و استثناها
MENU
  while true; do
    printf 'Choice [1-2]: ' > /dev/tty
    IFS= read -r choice < /dev/tty
    case "$choice" in
      1) printf 'selected'; return 0 ;;
      2) printf 'all'; return 0 ;;
      *) printf 'Please enter 1 or 2.\n' > /dev/tty ;;
    esac
  done
}

prompt_protocol() {
  local choice=""
  tty_available || die "Protocol is required in non-interactive mode: --protocol tcp|udp|both"
  cat > /dev/tty <<'MENU'

Select forwarding protocol / پروتکل فوروارد را انتخاب کنید:
  1) TCP only / فقط TCP
  2) UDP only / فقط UDP
  3) TCP + UDP / هر دو
MENU
  while true; do
    printf 'Choice [1-3]: ' > /dev/tty
    IFS= read -r choice < /dev/tty
    case "$choice" in
      1) printf 'tcp'; return 0 ;;
      2) printf 'udp'; return 0 ;;
      3) printf 'both'; return 0 ;;
      *) printf 'Please enter 1, 2, or 3.\n' > /dev/tty ;;
    esac
  done
}

prompt_uninstall_confirmation() {
  local answer=""
  [[ "$ASSUME_YES" == "1" ]] && return 0
  tty_available || die "Uninstall confirmation requires --yes in non-interactive mode"
  printf 'Remove Paqet X, its configuration, services, and firewall rules? [y/N]: ' > /dev/tty
  IFS= read -r answer < /dev/tty
  [[ "$answer" =~ ^[Yy]$ ]]
}

remove_iptables_rule() {
  local table="$1"
  shift
  while iptables -w 5 -t "$table" -C "$@" >/dev/null 2>&1; do
    iptables -w 5 -t "$table" -D "$@" >/dev/null 2>&1 || break
  done
}

cleanup_recorded_firewall_rules() {
  local role="" transport="" mode="" forwards="" interface="" service_uid="" item port protocol
  local -a firewall_items=()
  [[ -r "$FIREWALL_ENV" ]] || return 0
  if ! command -v iptables >/dev/null 2>&1; then
    log_warn "iptables is unavailable; recorded Paqet X firewall rules could not be verified or removed"
    return 0
  fi
  role="$(awk -F= '$1=="ROLE"{print $2;exit}' "$FIREWALL_ENV")"
  transport="$(awk -F= '$1=="TRANSPORT_PORT"{print $2;exit}' "$FIREWALL_ENV")"
  mode="$(awk -F= '$1=="FORWARD_MODE"{print $2;exit}' "$FIREWALL_ENV")"
  forwards="$(awk -F= '$1=="FORWARD_PORTS"{sub(/^[^=]*=/,"");print;exit}' "$FIREWALL_ENV")"
  interface="$(awk -F= '$1=="INTERFACE"{print $2;exit}' "$FIREWALL_ENV")"
  service_uid="$(awk -F= '$1=="SERVICE_UID"{print $2;exit}' "$FIREWALL_ENV")"

  if [[ "$role" == "abroad" ]] && validate_port "$transport"; then
    remove_iptables_rule raw PREROUTING -p tcp --dport "$transport" -j NOTRACK
    remove_iptables_rule raw OUTPUT -p tcp --sport "$transport" -j NOTRACK
    remove_iptables_rule mangle OUTPUT -p tcp --sport "$transport" --tcp-flags RST RST -j DROP
    remove_iptables_rule filter INPUT -p tcp --dport "$transport" -j ACCEPT
    if [[ "$service_uid" =~ ^[0-9]+$ ]]; then
      # Remove all previous destination-rewrite variants, including the v4.1
      # rule that matched dport and could recapture Paqet tunnel replies.
      remove_iptables_rule nat OUTPUT -m owner --uid-owner "$service_uid" -p tcp ! --sport "$transport" -j DNAT --to-destination 127.0.0.1
      remove_iptables_rule nat OUTPUT -m owner --uid-owner "$service_uid" -p udp -j DNAT --to-destination 127.0.0.1
      remove_iptables_rule nat OUTPUT -m owner --uid-owner "$service_uid" -p tcp ! --dport "$transport" ! -d 127.0.0.0/8 -j REDIRECT
      remove_iptables_rule nat OUTPUT -m owner --uid-owner "$service_uid" -p tcp ! --sport "$transport" ! -d 127.0.0.0/8 -j REDIRECT
      remove_iptables_rule nat OUTPUT -m owner --uid-owner "$service_uid" -p udp ! -d 127.0.0.0/8 -j REDIRECT
    fi
  elif [[ "$role" == "iran" && "$mode" == "selected" && -n "$forwards" ]]; then
    IFS=',' read -r -a firewall_items <<<"$forwards"
    for item in "${firewall_items[@]}"; do
      port="${item%/*}"
      protocol="${item##*/}"
      if ! validate_port "$port" || [[ "$protocol" != "tcp" && "$protocol" != "udp" ]]; then continue; fi
      remove_iptables_rule filter INPUT -p "$protocol" --dport "$port" -j ACCEPT
    done
  elif [[ "$role" == "iran" && "$mode" == "all" ]]; then
    if validate_interface "$interface"; then
      remove_iptables_rule mangle PREROUTING -i "$interface" -m addrtype --dst-type LOCAL -j PAQETX_ALLPORT
    fi
    remove_iptables_rule mangle PREROUTING -m addrtype --dst-type LOCAL -j PAQETX_ALLPORT
    remove_iptables_rule filter INPUT -m mark --mark 1088/0x7ff -j ACCEPT
    iptables -w 5 -t mangle -F PAQETX_ALLPORT >/dev/null 2>&1 || true
    iptables -w 5 -t mangle -X PAQETX_ALLPORT >/dev/null 2>&1 || true
    if command -v ip >/dev/null 2>&1; then
      while ip rule del fwmark 1088/0x7ff table 100 >/dev/null 2>&1; do :; done
      ip route flush table 100 >/dev/null 2>&1 || true
    fi
  fi
}

restore_recorded_kernel_values() {
  local role="" mode="" interface="" all_old="" interface_old=""
  [[ -r "$FIREWALL_RUNTIME_STATE" ]] || return 0
  role="$(awk -F= '$1=="ROLE"{print $2;exit}' "$FIREWALL_RUNTIME_STATE")"
  mode="$(awk -F= '$1=="FORWARD_MODE"{print $2;exit}' "$FIREWALL_RUNTIME_STATE")"
  [[ "$role" == "iran" && "$mode" == "all" ]] || return 0
  interface="$(awk -F= '$1=="INTERFACE"{print $2;exit}' "$FIREWALL_RUNTIME_STATE")"
  all_old="$(awk -F= '$1=="RP_FILTER_ALL_OLD"{print $2;exit}' "$FIREWALL_RUNTIME_STATE")"
  interface_old="$(awk -F= '$1=="RP_FILTER_INTERFACE_OLD"{print $2;exit}' "$FIREWALL_RUNTIME_STATE")"
  if [[ -n "$all_old" && -w /proc/sys/net/ipv4/conf/all/rp_filter ]]; then
    printf '%s\n' "$all_old" > /proc/sys/net/ipv4/conf/all/rp_filter || true
  fi
  if validate_interface "$interface" && [[ -n "$interface_old" && -w "/proc/sys/net/ipv4/conf/${interface}/rp_filter" ]]; then
    printf '%s\n' "$interface_old" > "/proc/sys/net/ipv4/conf/${interface}/rp_filter" || true
  fi
}

remove_installer_service_user() {
  local created="$1"
  [[ "$created" == "1" ]] || return 0
  [[ -z "$ROOT_PREFIX" ]] || return 0
  id -u "$SERVICE_USER" >/dev/null 2>&1 || return 0
  if command -v userdel >/dev/null 2>&1; then
    userdel "$SERVICE_USER" >/dev/null 2>&1 || log_warn "Could not remove service user ${SERVICE_USER}"
  elif command -v deluser >/dev/null 2>&1; then
    deluser --system "$SERVICE_USER" >/dev/null 2>&1 || log_warn "Could not remove service user ${SERVICE_USER}"
  else
    log_warn "No user removal command is available; service user ${SERVICE_USER} remains"
  fi
}

uninstall_existing() {
  local service_user_created="0"
  prompt_uninstall_confirmation || { log_info "Uninstall cancelled"; return 0; }
  [[ ! -r "$STATE_PATH" ]] || service_user_created="$(awk -F= '$1=="SERVICE_USER_CREATED"{print $2;exit}' "$STATE_PATH")"
  [[ "$service_user_created" == "1" ]] || service_user_created="0"

  log_info "Stopping Paqet X services"
  if command -v systemctl >/dev/null 2>&1; then
    systemctl disable --now "$TPROXY_SERVICE_NAME" "$SERVICE_NAME" "$FIREWALL_SERVICE_NAME" >/dev/null 2>&1 || true
  fi
  if [[ -z "$ROOT_PREFIX" && -x "$FIREWALL_SCRIPT" ]]; then
    "$FIREWALL_SCRIPT" stop >/dev/null 2>&1 || true
  fi
  cleanup_recorded_firewall_rules
  restore_recorded_kernel_values
  rm -f -- "$SERVICE_PATH" "$FIREWALL_SERVICE_PATH" "$TPROXY_SERVICE_PATH" "$FIREWALL_RUNTIME_STATE"
  rm -rf -- "$CONFIG_DIR" "$LIB_DIR" "$STATE_DIR"
  rm -f -- "$BIN_PATH" "$TPROXY_BIN_PATH" "$MANAGER_PATH"
  if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl reset-failed "$TPROXY_SERVICE_NAME" "$SERVICE_NAME" "$FIREWALL_SERVICE_NAME" >/dev/null 2>&1 || true
  fi
  remove_installer_service_user "$service_user_created"
  log_success "Paqet X was completely removed"
}

normalize_protocol_mode() {
  case "${1,,}" in
    1|tcp) printf 'tcp' ;;
    2|udp) printf 'udp' ;;
    3|both|all|tcp+udp|udp+tcp) printf 'both' ;;
    *) return 1 ;;
  esac
}

append_ports_with_protocol() {
  local value="$1" mode="$2" item port
  local -a parts
  mode="$(normalize_protocol_mode "$mode")" || die "Invalid protocol mode: ${mode}. Use tcp, udp, or both"
  IFS=',' read -r -a parts <<<"$value"
  for item in "${parts[@]}"; do
    item="$(trim "$item")"
    [[ -n "$item" ]] || continue
    validate_port "$item" || die "Invalid forwarding port: ${item}"
    port="$((10#$item))"
    case "$mode" in
      tcp) append_forward_values "${port}:${port}/tcp" ;;
      udp) append_forward_values "${port}:${port}/udp" ;;
      both)
        append_forward_values "${port}:${port}/tcp"
        append_forward_values "${port}:${port}/udp"
        ;;
    esac
  done
}

self_test() {
  local result
  FORWARD_SPECS=()
  result="$(canonical_forward '443')"; [[ "$result" == '443:443/tcp' ]]
  result="$(canonical_forward '8443:443/udp')"; [[ "$result" == '8443:443/udp' ]]
  ! canonical_forward 'x:443/tcp' >/dev/null 2>&1
  append_ports_with_protocol '443,8443' both
  [[ ${#FORWARD_SPECS[@]} -eq 4 ]]
  [[ "${FORWARD_SPECS[0]}" == '443:443/tcp' ]]
  [[ "${FORWARD_SPECS[1]}" == '443:443/udp' ]]
  [[ "${FORWARD_SPECS[2]}" == '8443:8443/tcp' ]]
  [[ "${FORWARD_SPECS[3]}" == '8443:8443/udp' ]]
  printf 'Paqet X self-test passed.\n'
}

ACTION="${PAQET_ACTION:-}"
ROLE="${PAQET_ROLE:-}"
TRANSPORT_PORT="${PAQET_PORT:-9999}"
FOREIGN_HOST="${PAQET_FOREIGN_HOST:-}"
LISTEN_IP="${PAQET_LISTEN_IP:-0.0.0.0}"
TARGET_HOST="127.0.0.1"
PAQET_KEY="${PAQET_KEY:-}"
VERSION_REQUEST=""
PAQET_INTERFACE="${PAQET_INTERFACE:-}"
PAQET_LOCAL_IP="${PAQET_LOCAL_IP:-}"
PAQET_ROUTER_MAC="${PAQET_ROUTER_MAC:-}"
KCP_MODE="fast"
KCP_BLOCK="aes-128-gcm"
TRANSPORT_CONN="1"
KCP_MTU="1350"
readonly STABLE_SMUX_BUFFER="4194304"
readonly STABLE_STREAM_BUFFER="2097152"
readonly STABLE_SMUX_KEEPALIVE="5"
readonly STABLE_SMUX_TIMEOUT="30"
FORWARD_MODE="${PAQET_FORWARD_MODE:-}"
FORWARD_PROTOCOL="${PAQET_PROTOCOL:-tcp}"
OPEN_FORWARD_PORTS="${OPEN_FORWARD_PORTS:-1}"
TPROXY_VERSION="${PAQET_TPROXY_VERSION:-$DEFAULT_TPROXY_VERSION}"
TPROXY_PORT=""
SERVICE_UID=""
SERVICE_USER_CREATED=0
RECONFIGURE="${RECONFIGURE:-0}"
SKIP_START="${SKIP_START:-0}"
ASSUME_YES="${ASSUME_YES:-0}"
SELF_TEST=0
CONFIG_INPUT_GIVEN=0
PROTOCOL_INPUT_GIVEN=0
SSH_PORTS_INPUT_GIVEN=0
FORWARD_SPECS=()
PORT_LIST_INPUTS=()
EXCLUDE_PORT_INPUTS=()
SSH_PORT_INPUTS=()
EXCLUDED_PORTS=()
SSH_PORTS=()

while (($# > 0)); do
  case "$1" in
    --role) (($# >= 2)) || die "--role requires a value"; ACTION="install"; ROLE="$2"; CONFIG_INPUT_GIVEN=1; shift 2 ;;
    --port) (($# >= 2)) || die "--port requires a value"; TRANSPORT_PORT="$2"; CONFIG_INPUT_GIVEN=1; shift 2 ;;
    --foreign-host) (($# >= 2)) || die "--foreign-host requires a value"; FOREIGN_HOST="$2"; CONFIG_INPUT_GIVEN=1; shift 2 ;;
    --forward-mode) (($# >= 2)) || die "--forward-mode requires a value"; FORWARD_MODE="$2"; CONFIG_INPUT_GIVEN=1; shift 2 ;;
    --all-ports) FORWARD_MODE="all"; CONFIG_INPUT_GIVEN=1; shift ;;
    --ports) (($# >= 2)) || die "--ports requires a value"; PORT_LIST_INPUTS+=("$2"); CONFIG_INPUT_GIVEN=1; shift 2 ;;
    --protocol) (($# >= 2)) || die "--protocol requires a value"; FORWARD_PROTOCOL="$2"; PROTOCOL_INPUT_GIVEN=1; CONFIG_INPUT_GIVEN=1; shift 2 ;;
    --exclude-ports) (($# >= 2)) || die "--exclude-ports requires a value"; EXCLUDE_PORT_INPUTS+=("$2"); CONFIG_INPUT_GIVEN=1; shift 2 ;;
    --ssh-ports) (($# >= 2)) || die "--ssh-ports requires a value"; SSH_PORT_INPUTS+=("$2"); SSH_PORTS_INPUT_GIVEN=1; CONFIG_INPUT_GIVEN=1; shift 2 ;;
    --forward) (($# >= 2)) || die "--forward requires a value"; append_forward_values "$2"; CONFIG_INPUT_GIVEN=1; shift 2 ;;
    --listen-ip) (($# >= 2)) || die "--listen-ip requires a value"; LISTEN_IP="$2"; CONFIG_INPUT_GIVEN=1; shift 2 ;;
    --target-host) (($# >= 2)) || die "--target-host requires a value"; [[ "$2" == "127.0.0.1" ]] || die "Invalid --target-host: Paqet X forwards only to 127.0.0.1 on the Abroad server"; shift 2 ;;
    --key) (($# >= 2)) || die "--key requires a value"; PAQET_KEY="$2"; CONFIG_INPUT_GIVEN=1; shift 2 ;;
    --interface) (($# >= 2)) || die "--interface requires a value"; PAQET_INTERFACE="$2"; CONFIG_INPUT_GIVEN=1; shift 2 ;;
    --local-ip) (($# >= 2)) || die "--local-ip requires a value"; PAQET_LOCAL_IP="$2"; CONFIG_INPUT_GIVEN=1; shift 2 ;;
    --router-mac) (($# >= 2)) || die "--router-mac requires a value"; PAQET_ROUTER_MAC="$2"; CONFIG_INPUT_GIVEN=1; shift 2 ;;
    --no-open-forward-ports) OPEN_FORWARD_PORTS=0; CONFIG_INPUT_GIVEN=1; shift ;;
    --reconfigure|--force-config) RECONFIGURE=1; shift ;;
    --uninstall) ACTION="uninstall"; shift ;;
    --no-start) SKIP_START=1; shift ;;
    --yes) ASSUME_YES=1; shift ;;
    --self-test) SELF_TEST=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $1 (use --help)" ;;
  esac
done

if [[ "$SELF_TEST" == "1" ]]; then
  self_test
  exit 0
fi

validate_boolean "OPEN_FORWARD_PORTS" "$OPEN_FORWARD_PORTS"
validate_boolean "RECONFIGURE" "$RECONFIGURE"
validate_boolean "SKIP_START" "$SKIP_START"
validate_boolean "ASSUME_YES" "$ASSUME_YES"
FORWARD_PROTOCOL="$(normalize_protocol_mode "$FORWARD_PROTOCOL")" || die "Invalid protocol mode: ${FORWARD_PROTOCOL}. Use tcp, udp, or both"
if [[ -n "$FORWARD_MODE" ]]; then
  FORWARD_MODE="$(normalize_forward_mode "$FORWARD_MODE")" || die "Invalid forward mode: ${FORWARD_MODE}. Use selected or all"
fi
for port_list in "${PORT_LIST_INPUTS[@]}"; do
  append_ports_with_protocol "$port_list" "$FORWARD_PROTOCOL"
done
for excluded_input in "${EXCLUDE_PORT_INPUTS[@]}"; do
  append_port_list EXCLUDED_PORTS "$excluded_input"
done
for ssh_input in "${SSH_PORT_INPUTS[@]}"; do
  append_port_list SSH_PORTS "$ssh_input"
done
validate_release_tag "$TPROXY_VERSION" || die "Invalid transparent-proxy release: ${TPROXY_VERSION}"

if [[ -z "$ACTION" ]]; then
  selection="$(prompt_action)"
  ACTION="${selection%%:*}"
  ROLE="${selection#*:}"
fi
case "$ACTION" in
  exit) log_info "No changes made"; exit 0 ;;
  uninstall)
    printf '%sPaqet X Uninstaller v%s%s
' "$BOLD" "$INSTALLER_VERSION" "$RESET"
    ((EUID == 0)) || die "Root privileges are required. Use sudo"
    uninstall_existing
    exit 0
    ;;
  install) ;;
  *) die "Invalid action: ${ACTION}" ;;
esac

ROLE="$(normalize_role "$ROLE")" || die "Invalid role. Use abroad or iran"
validate_transport_port "$TRANSPORT_PORT"
if [[ "$ROLE" == "abroad" ]]; then
  [[ -z "$FORWARD_MODE" && ${#FORWARD_SPECS[@]} -eq 0 && ${#EXCLUDED_PORTS[@]} -eq 0 ]] || die "Forwarding options are valid only on the Iran role"
else
  if [[ "$FORWARD_MODE" == "all" && ${#FORWARD_SPECS[@]} -gt 0 ]]; then
    die "Do not combine --all-ports with --ports or --forward"
  fi
  if [[ "$FORWARD_MODE" == "selected" && ${#EXCLUDED_PORTS[@]} -gt 0 ]]; then
    die "--exclude-ports is valid only with --all-ports"
  fi
fi
[[ -z "$FOREIGN_HOST" ]] || validate_host "$FOREIGN_HOST" || die "Invalid --foreign-host: ${FOREIGN_HOST}"
validate_ipv4 "$LISTEN_IP" || die "Invalid --listen-ip IPv4 address: ${LISTEN_IP}"
validate_host "$TARGET_HOST" || die "Invalid --target-host: ${TARGET_HOST}"
[[ -z "$PAQET_INTERFACE" ]] || validate_interface "$PAQET_INTERFACE" || die "Invalid interface name: ${PAQET_INTERFACE}"
[[ -z "$PAQET_LOCAL_IP" ]] || validate_ipv4 "$PAQET_LOCAL_IP" || die "Invalid local IPv4: ${PAQET_LOCAL_IP}"
[[ -z "$PAQET_ROUTER_MAC" ]] || validate_mac "$PAQET_ROUTER_MAC" || die "Invalid router MAC: ${PAQET_ROUTER_MAC}"
[[ -z "$PAQET_KEY" ]] || validate_key "$PAQET_KEY" || die "Key must be 16-128 safe characters"
validate_kcp_mode "$KCP_MODE" || die "Invalid KCP mode: ${KCP_MODE}"
validate_block "$KCP_BLOCK" || die "Unsupported KCP cipher: ${KCP_BLOCK}"
if [[ ! "$TRANSPORT_CONN" =~ ^[0-9]+$ ]] || ((TRANSPORT_CONN < 1 || TRANSPORT_CONN > 256)); then die "--conn must be 1-256"; fi
if [[ ! "$KCP_MTU" =~ ^[0-9]+$ ]] || ((KCP_MTU < 50 || KCP_MTU > 1500)); then die "--mtu must be 50-1500"; fi

printf '%sPaqet X Installer v%s%s\n' "$BOLD" "$INSTALLER_VERSION" "$RESET"
printf 'Project:  https://github.com/%s\n' "$INSTALLER_REPOSITORY"
printf 'Upstream: https://github.com/%s\n' "$UPSTREAM_REPOSITORY"

step "Checking privileges and Linux platform"
((EUID == 0)) || die "Root privileges are required. Use sudo"
[[ "$(uname -s)" == "Linux" ]] || die "Linux is required"
if [[ "${PAQETX_TEST_MODE:-0}" != "1" ]]; then
  [[ -d /run/systemd/system ]] || die "systemd must be the active init system"
fi

case "$(uname -m)" in
  x86_64|amd64) PAQET_ARCH="amd64"; ARCH_BINARY_NAME="paqet_linux_amd64" ;;
  aarch64|arm64) PAQET_ARCH="arm64"; ARCH_BINARY_NAME="paqet_linux_arm64" ;;
  armv7l|armv7) PAQET_ARCH="arm32"; ARCH_BINARY_NAME="paqet_linux_arm32" ;;
  *) die "Unsupported architecture: $(uname -m). Supported: amd64, arm64, armv7" ;;
esac
log_success "Linux $(uname -m), systemd, and root access detected"

step "Installing required packages"
install_dependencies() {
  local -a required=(curl jq tar ip ss iptables systemctl sha256sum install awk sed grep find od id)
  local -a missing=()
  local cmd
  for cmd in "${required[@]}"; do command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd"); done
  if ((${#missing[@]} == 0)); then log_success "Required commands are already installed"; return; fi
  log_info "Missing commands: ${missing[*]}"
  if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y --no-install-recommends ca-certificates curl jq tar iproute2 iptables iputils-ping coreutils passwd
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y ca-certificates curl jq tar iproute iputils coreutils iptables shadow-utils || dnf install -y iptables-nft shadow-utils
  elif command -v yum >/dev/null 2>&1; then
    yum install -y ca-certificates curl jq tar iproute iputils coreutils iptables shadow-utils || yum install -y iptables-nft shadow-utils
  elif command -v pacman >/dev/null 2>&1; then
    pacman -Sy --noconfirm --needed ca-certificates curl jq tar iproute2 iptables iputils coreutils shadow
  elif command -v zypper >/dev/null 2>&1; then
    zypper --non-interactive install ca-certificates curl jq tar iproute2 iptables iputils coreutils shadow
  else
    die "Unsupported package manager. Install curl jq tar iproute2 iptables coreutils, then rerun"
  fi
  for cmd in "${required[@]}"; do command -v "$cmd" >/dev/null 2>&1 || die "Still missing required command: $cmd"; done
  log_success "Dependencies installed"
}
install_dependencies

ensure_service_user() {
  local saved_created="0"
  if [[ -r "$STATE_PATH" ]]; then
    saved_created="$(awk -F= '$1=="SERVICE_USER_CREATED" {print $2; exit}' "$STATE_PATH")"
    [[ "$saved_created" == "1" ]] || saved_created="0"
  fi
  if [[ "${PAQETX_TEST_MODE:-0}" == "1" ]]; then
    SERVICE_UID="65534"
    SERVICE_GROUP="root"
    SERVICE_USER_CREATED="$saved_created"
    return 0
  fi
  if id -u "$SERVICE_USER" >/dev/null 2>&1; then
    SERVICE_UID="$(id -u "$SERVICE_USER")"
    SERVICE_GROUP="$SERVICE_USER"
    SERVICE_USER_CREATED="$saved_created"
    return 0
  fi
  if command -v useradd >/dev/null 2>&1; then
    useradd --system --home-dir /nonexistent --shell /usr/sbin/nologin --user-group "$SERVICE_USER"
  elif command -v adduser >/dev/null 2>&1; then
    adduser --system --no-create-home --home /nonexistent --shell /usr/sbin/nologin --group "$SERVICE_USER"
  else
    die "Could not create the dedicated ${SERVICE_USER} service user"
  fi
  SERVICE_UID="$(id -u "$SERVICE_USER")"
  SERVICE_GROUP="$SERVICE_USER"
  SERVICE_USER_CREATED=1
}
ensure_service_user

step "Loading or preparing the selected role configuration"
install -d -m 0750 -o root -g "$SERVICE_GROUP" "$CONFIG_DIR"
install -d -m 0755 -o root -g root "$LIB_DIR" "$STATE_DIR" "$(dirname "$BIN_PATH")" "$(dirname "$MANAGER_PATH")" "$(dirname "$SERVICE_PATH")"

if [[ -f "$LEGACY_CONFIG_PATH" && ! -f "$CONFIG_PATH" ]]; then
  cp -a "$LEGACY_CONFIG_PATH" "$CONFIG_PATH"
  chmod 0640 "$CONFIG_PATH"
  chown root:"$SERVICE_GROUP" "$CONFIG_PATH"
  log_warn "Migrated legacy server configuration to ${CONFIG_PATH}"
fi

read_state_value() {
  local key="$1"
  [[ -r "$STATE_PATH" ]] || return 0
  awk -F= -v key="$key" '$1==key {sub(/^[^=]*=/,""); print; exit}' "$STATE_PATH"
}

detect_ssh_ports() {
  local port config_file
  if [[ "$SSH_PORTS_INPUT_GIVEN" == "1" && ${#SSH_PORTS[@]} -gt 0 ]]; then
    return 0
  fi
  SSH_PORTS=()

  if [[ -n "${SSH_CONNECTION:-}" ]]; then
    port="$(awk '{print $4}' <<<"$SSH_CONNECTION")"
    [[ -z "$port" ]] || append_unique_port SSH_PORTS "$port"
  fi

  if command -v sshd >/dev/null 2>&1; then
    while IFS= read -r port; do
      [[ -z "$port" ]] || append_unique_port SSH_PORTS "$port"
    done < <(sshd -T 2>/dev/null | awk '$1=="port" && $2 ~ /^[0-9]+$/ {print $2}' || true)
  fi

  while IFS= read -r port; do
    [[ -z "$port" ]] || append_unique_port SSH_PORTS "$port"
  done < <(ss -H -lntp 2>/dev/null | awk '
    /users:\(\("sshd"/ {
      value=$4
      sub(/^.*:/,"",value)
      gsub(/[^0-9]/,"",value)
      if(value!="") print value
    }
  ' || true)

  for config_file in "${ROOT_PREFIX}/etc/ssh/sshd_config" "${ROOT_PREFIX}/etc/ssh/sshd_config.d/"*.conf; do
    [[ -r "$config_file" ]] || continue
    while IFS= read -r port; do
      [[ -z "$port" ]] || append_unique_port SSH_PORTS "$port"
    done < <(awk 'tolower($1)=="port" && $2 ~ /^[0-9]+$/ {print $2}' "$config_file")
  done

  if ((${#SSH_PORTS[@]} == 0)); then
    append_unique_port SSH_PORTS 22
    log_warn "Could not prove the active SSH port; protecting default port 22"
  fi
}

validate_selected_forward_safety() {
  local spec base listen_port
  for spec in "${FORWARD_SPECS[@]}"; do
    base="${spec%/*}"
    listen_port="${base%%:*}"
    [[ "$listen_port" != "$TRANSPORT_PORT" ]] || die "Selected forwarding port ${listen_port} is the Paqet tunnel port"
    if port_is_listed "$listen_port" SSH_PORTS; then
      die "Selected forwarding port ${listen_port} is an active SSH port; refusing to risk SSH access"
    fi
  done
}

PRESERVE_CONFIG=0
if [[ -f "$CONFIG_PATH" && "$RECONFIGURE" != "1" ]]; then
  ROLE_FROM_CONFIG="$(awk -F'"' '/^[[:space:]]*role:[[:space:]]*"(server|client)"/ {print $2; exit}' "$CONFIG_PATH")"
  case "$ROLE_FROM_CONFIG" in
    server) EXISTING_ROLE="abroad" ;;
    client) EXISTING_ROLE="iran" ;;
    *) die "Existing configuration has no valid role: ${CONFIG_PATH}" ;;
  esac
  if [[ "$ROLE" != "$EXISTING_ROLE" ]]; then
    die "Paqet X is already installed as ${EXISTING_ROLE}. Select Uninstall first, or rerun with --reconfigure"
  fi
  PRESERVE_CONFIG=1
  ROLE="$EXISTING_ROLE"

  FORWARD_SPECS=()
  EXCLUDED_PORTS=()
  SSH_PORTS=()
  SAVED_FOREIGN_HOST="$(read_state_value FOREIGN_HOST)"
  SAVED_LISTEN_IP="$(read_state_value LISTEN_IP)"
  SAVED_FORWARD_MODE="$(read_state_value FORWARD_MODE)"
  SAVED_FORWARD_PROTOCOL="$(read_state_value FORWARD_PROTOCOL)"
  SAVED_FORWARD_SPECS="$(read_state_value FORWARD_SPECS)"
  SAVED_EXCLUDED_PORTS="$(read_state_value EXCLUDED_PORTS)"
  SAVED_SSH_PORTS="$(read_state_value SSH_PORTS)"
  SAVED_TPROXY_PORT="$(read_state_value TPROXY_PORT)"
  SAVED_TPROXY_VERSION="$(read_state_value TPROXY_VERSION)"
  SAVED_OPEN_FORWARD_PORTS="$(read_state_value OPEN_FORWARD_PORTS)"
  SAVED_SERVICE_USER_CREATED="$(read_state_value SERVICE_USER_CREATED)"

  [[ -z "$SAVED_FOREIGN_HOST" ]] || FOREIGN_HOST="$SAVED_FOREIGN_HOST"
  [[ -z "$SAVED_LISTEN_IP" ]] || LISTEN_IP="$SAVED_LISTEN_IP"
  if [[ -n "$SAVED_FORWARD_MODE" ]]; then
    FORWARD_MODE="$(normalize_forward_mode "$SAVED_FORWARD_MODE")" || die "Invalid FORWARD_MODE in ${STATE_PATH}"
  elif [[ "$ROLE" == "iran" ]] && grep -q '^[[:space:]]*socks5:' "$CONFIG_PATH"; then
    FORWARD_MODE="all"
  else
    FORWARD_MODE="selected"
  fi
  [[ -z "$SAVED_FORWARD_PROTOCOL" ]] || FORWARD_PROTOCOL="$(normalize_protocol_mode "$SAVED_FORWARD_PROTOCOL")"
  [[ -z "$SAVED_FORWARD_SPECS" ]] || append_forward_values "$SAVED_FORWARD_SPECS"
  [[ -z "$SAVED_EXCLUDED_PORTS" ]] || append_port_list EXCLUDED_PORTS "$SAVED_EXCLUDED_PORTS"
  [[ -z "$SAVED_SSH_PORTS" ]] || append_port_list SSH_PORTS "$SAVED_SSH_PORTS"
  [[ -z "$SAVED_TPROXY_PORT" ]] || TPROXY_PORT="$SAVED_TPROXY_PORT"
  [[ -z "$SAVED_TPROXY_VERSION" ]] || TPROXY_VERSION="$SAVED_TPROXY_VERSION"
  if [[ -n "$SAVED_OPEN_FORWARD_PORTS" ]]; then
    [[ "$SAVED_OPEN_FORWARD_PORTS" == "0" || "$SAVED_OPEN_FORWARD_PORTS" == "1" ]] || die "Invalid OPEN_FORWARD_PORTS in ${STATE_PATH}"
    OPEN_FORWARD_PORTS="$SAVED_OPEN_FORWARD_PORTS"
  fi
  [[ "$SAVED_SERVICE_USER_CREATED" == "1" ]] && SERVICE_USER_CREATED=1
  if [[ "$CONFIG_INPUT_GIVEN" == "1" ]]; then
    log_warn "Existing configuration is being preserved; configuration options were ignored. Use --reconfigure to replace it"
  fi
  log_success "Preserving existing ${ROLE} configuration"
else
  if [[ "$ROLE" == "abroad" ]]; then
    if [[ "$ASSUME_YES" != "1" ]]; then
      prompt_value TRANSPORT_PORT "Paqet tunnel port / پورت تونل" "$TRANSPORT_PORT"
      validate_transport_port "$TRANSPORT_PORT"
    fi
    if [[ -z "$PAQET_KEY" ]]; then
      PAQET_KEY="$(od -An -N32 -tx1 /dev/urandom | tr -d ' \n')"
    fi
    validate_key "$PAQET_KEY" || die "Generated key failed validation"
    FORWARD_MODE="selected"
    FORWARD_SPECS=()
  else
    if [[ -z "$FOREIGN_HOST" ]]; then
      prompt_value FOREIGN_HOST "Abroad server public IP or DNS / آدرس سرور خارج" ""
    fi
    validate_host "$FOREIGN_HOST" || die "Invalid abroad host: ${FOREIGN_HOST}"
    if [[ "$ASSUME_YES" != "1" ]]; then
      prompt_value TRANSPORT_PORT "Abroad Paqet tunnel port / پورت تونل خارج" "$TRANSPORT_PORT"
      validate_transport_port "$TRANSPORT_PORT"
    fi
    if [[ -z "$PAQET_KEY" ]]; then
      prompt_value PAQET_KEY "Shared key from Abroad / کلید دریافتی از خارج" "" 1
    fi
    validate_key "$PAQET_KEY" || die "Invalid shared key"

    if [[ -z "$FORWARD_MODE" ]]; then
      if ((${#FORWARD_SPECS[@]} > 0)); then
        FORWARD_MODE="selected"
      elif tty_available && [[ "$ASSUME_YES" != "1" ]]; then
        FORWARD_MODE="$(prompt_forward_mode)"
      else
        die "Iran forwarding mode is required: use --forward-mode selected with --ports, or --all-ports"
      fi
    fi
    FORWARD_MODE="$(normalize_forward_mode "$FORWARD_MODE")" || die "Invalid forward mode"

    detect_ssh_ports
    log_info "Protected SSH port(s): $(ports_csv SSH_PORTS)"

    if [[ "$FORWARD_MODE" == "selected" ]]; then
      ((${#EXCLUDED_PORTS[@]} == 0)) || die "--exclude-ports is valid only with --all-ports"
      if ((${#FORWARD_SPECS[@]} == 0)); then
        FORWARD_INPUT=""
        prompt_value FORWARD_INPUT "Forward ports, comma-separated / پورت‌ها، با کاما جدا کنید (e.g. 443,8443)" ""
        [[ -n "$FORWARD_INPUT" ]] || die "At least one forwarding port is required in selected mode"
        if [[ "$PROTOCOL_INPUT_GIVEN" != "1" && "$ASSUME_YES" != "1" ]]; then
          FORWARD_PROTOCOL="$(prompt_protocol)"
        fi
        append_ports_with_protocol "$FORWARD_INPUT" "$FORWARD_PROTOCOL"
      fi
      validate_selected_forward_safety
    else
      ((${#FORWARD_SPECS[@]} == 0)) || die "Do not combine --all-ports with --ports or --forward"
      if [[ "$PROTOCOL_INPUT_GIVEN" != "1" && "$ASSUME_YES" != "1" ]]; then
        FORWARD_PROTOCOL="$(prompt_protocol)"
      fi
      if tty_available && [[ "$ASSUME_YES" != "1" ]]; then
        EXCLUDE_INPUT=""
        prompt_value EXCLUDE_INPUT "Extra excluded ports, comma-separated / پورت‌های مستثنا (اختیاری)" ""
        [[ -z "$EXCLUDE_INPUT" ]] || append_port_list EXCLUDED_PORTS "$EXCLUDE_INPUT"
      fi
      log_info "All-port mode excludes tunnel ${TRANSPORT_PORT}, SSH $(ports_csv SSH_PORTS), and user exclusions: $(ports_csv EXCLUDED_PORTS)"
    fi
  fi
fi

validate_ipv4 "$LISTEN_IP" || die "Invalid preserved listen IPv4: ${LISTEN_IP}"
validate_host "$TARGET_HOST" || die "Invalid preserved target host: ${TARGET_HOST}"

step "Detecting network interface, local IP, and gateway MAC"
get_default_interface() {
  ip -4 route show default 2>/dev/null | awk 'NR==1 {for(i=1;i<=NF;i++) if($i=="dev") {print $(i+1); exit}}'
}
get_local_ip() {
  local interface="$1" result
  result="$(ip -4 route get 1.1.1.1 2>/dev/null | awk 'NR==1 {for(i=1;i<=NF;i++) if($i=="src") {print $(i+1); exit}}' || true)"
  [[ -n "$result" ]] || result="$(ip -4 -o addr show dev "$interface" scope global 2>/dev/null | awk 'NR==1 {split($4,a,"/");print a[1]}' || true)"
  printf '%s' "$result"
}
get_gateway_ip() {
  ip -4 route show default dev "$1" 2>/dev/null | awk 'NR==1 {for(i=1;i<=NF;i++) if($i=="via") {print $(i+1); exit}}'
}
get_neighbor_mac() {
  ip neigh show to "$2" dev "$1" 2>/dev/null | awk 'NR==1 {for(i=1;i<=NF;i++) if($i=="lladdr") {print $(i+1); exit}}'
}

if [[ "$PRESERVE_CONFIG" == "1" ]]; then
  PAQET_INTERFACE="$(awk -F'"' '/^[[:space:]]*interface:[[:space:]]*"/ {print $2; exit}' "$CONFIG_PATH")"
  PAQET_LOCAL_IP="$(awk -F'"' '/^[[:space:]]*addr:[[:space:]]*"[0-9]+\./ {split($2,a,":"); print a[1]; exit}' "$CONFIG_PATH")"
  PAQET_ROUTER_MAC="$(awk -F'"' '/^[[:space:]]*router_mac:[[:space:]]*"/ {print $2; exit}' "$CONFIG_PATH")"
  validate_interface "$PAQET_INTERFACE" || die "Invalid interface in preserved config"
  validate_ipv4 "$PAQET_LOCAL_IP" || die "Invalid local IPv4 in preserved config"
  validate_mac "$PAQET_ROUTER_MAC" || die "Invalid router MAC in preserved config"
else
  [[ -n "$PAQET_INTERFACE" ]] || PAQET_INTERFACE="$(get_default_interface || true)"
  [[ -n "$PAQET_INTERFACE" ]] || die "Could not detect interface; use --interface"
  validate_interface "$PAQET_INTERFACE" || die "Invalid detected interface: ${PAQET_INTERFACE}"
  ip link show dev "$PAQET_INTERFACE" >/dev/null 2>&1 || die "Interface does not exist: ${PAQET_INTERFACE}"

  [[ -n "$PAQET_LOCAL_IP" ]] || PAQET_LOCAL_IP="$(get_local_ip "$PAQET_INTERFACE")"
  validate_ipv4 "$PAQET_LOCAL_IP" || die "Could not detect local IPv4; use --local-ip"

  if [[ -z "$PAQET_ROUTER_MAC" ]]; then
    GATEWAY_IP="$(get_gateway_ip "$PAQET_INTERFACE" || true)"
    [[ -n "$GATEWAY_IP" ]] || die "Could not detect gateway; use --router-mac"
    if command -v ping >/dev/null 2>&1; then
      ping -c 1 -W 1 "$GATEWAY_IP" >/dev/null 2>&1 || true
    fi
    PAQET_ROUTER_MAC="$(get_neighbor_mac "$PAQET_INTERFACE" "$GATEWAY_IP" || true)"
  fi
  validate_mac "$PAQET_ROUTER_MAC" || die "Could not detect gateway MAC; use --router-mac aa:bb:cc:dd:ee:ff"
  PAQET_ROUTER_MAC="${PAQET_ROUTER_MAC,,}"
fi
log_success "Interface ${PAQET_INTERFACE}, local IPv4 ${PAQET_LOCAL_IP}, gateway MAC ${PAQET_ROUTER_MAC}"

choose_tproxy_port() {
  local candidate used
  if [[ -n "$TPROXY_PORT" ]]; then
    validate_port "$TPROXY_PORT" || die "Invalid preserved TPROXY port: ${TPROXY_PORT}"
    return 0
  fi
  used="$(ss -H -lntu 2>/dev/null | awk '{value=$5; sub(/^.*:/,"",value); gsub(/[^0-9]/,"",value); if(value!="") print value}' | sort -u || true)"
  for ((candidate=61080; candidate<=61180; candidate++)); do
    [[ "$candidate" == "$TRANSPORT_PORT" ]] && continue
    grep -qx "$candidate" <<<"$used" && continue
    TPROXY_PORT="$candidate"
    return 0
  done
  die "Could not find a free internal transparent-proxy port between 61080 and 61180"
}

if [[ "$ROLE" == "iran" && "$FORWARD_MODE" == "all" ]]; then
  choose_tproxy_port
  log_success "Reserved internal TPROXY listener port ${TPROXY_PORT}"
fi

step "Resolving the matching upstream Paqet release"
if [[ -z "$VERSION_REQUEST" ]]; then
  if [[ -s "$VERSION_FILE" && -x "$BIN_PATH" ]]; then
    VERSION_REQUEST="$(tr -d '[:space:]' < "$VERSION_FILE")"
  else
    VERSION_REQUEST="$DEFAULT_PAQET_VERSION"
  fi
fi
validate_release_tag "$VERSION_REQUEST" || die "Invalid requested release: ${VERSION_REQUEST}"

RELEASE_API_URL="${API_BASE}/releases/latest"
[[ "$VERSION_REQUEST" == "latest" ]] || RELEASE_API_URL="${API_BASE}/releases/tags/${VERSION_REQUEST}"
TMP_DIR="$(mktemp -d -t paqet-x-install.XXXXXXXX)"
RELEASE_JSON="${TMP_DIR}/release.json"
CURL_HEADERS=(-H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: ${GITHUB_API_VERSION}" -H "User-Agent: paqet-x-installer/${INSTALLER_VERSION}")
[[ -z "${GITHUB_TOKEN:-}" ]] || CURL_HEADERS+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")

curl --proto '=https' --tlsv1.2 -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 --max-time 60 \
  "${CURL_HEADERS[@]}" "$RELEASE_API_URL" -o "$RELEASE_JSON"
RELEASE_TAG="$(jq -er '.tag_name' "$RELEASE_JSON")"
validate_release_tag "$RELEASE_TAG" || die "GitHub returned an invalid release tag"
ASSET_NAME="paqet-linux-${PAQET_ARCH}-${RELEASE_TAG}.tar.gz"
ASSET_URL="$(jq -er --arg name "$ASSET_NAME" '.assets[] | select(.name==$name) | .browser_download_url' "$RELEASE_JSON")"
ASSET_DIGEST="$(jq -er --arg name "$ASSET_NAME" '.assets[] | select(.name==$name) | .digest // empty' "$RELEASE_JSON")"
[[ "$ASSET_URL" == "https://github.com/${UPSTREAM_REPOSITORY}/releases/download/"* ]] || die "Unexpected release asset URL"
[[ "$ASSET_DIGEST" =~ ^sha256:[[:xdigit:]]{64}$ ]] || die "Release asset has no valid SHA-256 digest"
EXPECTED_SHA256="${ASSET_DIGEST#sha256:}"; EXPECTED_SHA256="${EXPECTED_SHA256,,}"
log_success "Resolved ${RELEASE_TAG} for linux/${PAQET_ARCH}"

step "Downloading, verifying, and installing the Paqet binary"
ARCHIVE_PATH="${TMP_DIR}/${ASSET_NAME}"
EXTRACT_DIR="${TMP_DIR}/extract"; mkdir -p "$EXTRACT_DIR"
curl --proto '=https' --tlsv1.2 -fL --retry 3 --retry-delay 2 --connect-timeout 10 --max-time 300 "$ASSET_URL" -o "$ARCHIVE_PATH"
[[ -s "$ARCHIVE_PATH" ]] || die "Downloaded archive is empty"
ACTUAL_SHA256="$(sha256sum "$ARCHIVE_PATH" | awk '{print $1}')"
[[ "$ACTUAL_SHA256" == "$EXPECTED_SHA256" ]] || die "SHA-256 verification failed"

tar -tzf "$ARCHIVE_PATH" | while IFS= read -r entry; do
  [[ "$entry" != /* && "/${entry}/" != *"/../"* ]] || die "Unsafe path in release archive: ${entry}"
done
while IFS= read -r listing; do
  type="${listing:0:1}"
  [[ "$type" == "-" || "$type" == "d" ]] || die "Unsafe non-regular entry in release archive"
done < <(tar -tvzf "$ARCHIVE_PATH")
tar -xzf "$ARCHIVE_PATH" -C "$EXTRACT_DIR" --no-same-owner --no-same-permissions
mapfile -t MATCHES < <(find "$EXTRACT_DIR" -type f -name "$ARCH_BINARY_NAME" -print)
((${#MATCHES[@]} == 1)) || die "Expected one ${ARCH_BINARY_NAME} binary, found ${#MATCHES[@]}"
chmod 0755 "${MATCHES[0]}"
"${MATCHES[0]}" version >/dev/null 2>&1 || die "Downloaded binary failed its version check"
NEW_BIN="${BIN_PATH}.new.$$"
install -m 0755 -o root -g root "${MATCHES[0]}" "$NEW_BIN"
mv -f "$NEW_BIN" "$BIN_PATH"
printf '%s\n' "$RELEASE_TAG" > "$VERSION_FILE"; chmod 0644 "$VERSION_FILE"
log_success "Verified and installed ${BIN_PATH}"

if [[ "$ROLE" == "iran" && "$FORWARD_MODE" == "all" ]]; then
  log_info "Resolving HevSocks5TProxy ${TPROXY_VERSION} for all-port mode"
  TPROXY_RELEASE_JSON="${TMP_DIR}/tproxy-release.json"
  TPROXY_RELEASE_API="${TPROXY_API_BASE}/releases/tags/${TPROXY_VERSION}"
  curl --proto '=https' --tlsv1.2 -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 --max-time 60 \
    "${CURL_HEADERS[@]}" "$TPROXY_RELEASE_API" -o "$TPROXY_RELEASE_JSON"

  case "$PAQET_ARCH" in
    amd64) TPROXY_CANDIDATES=(hev-socks5-tproxy-linux-x86_64 hev-socks5-tproxy-linux-amd64) ;;
    arm64) TPROXY_CANDIDATES=(hev-socks5-tproxy-linux-arm64) ;;
    arm32) TPROXY_CANDIDATES=(hev-socks5-tproxy-linux-arm32v7hf hev-socks5-tproxy-linux-arm32v7 hev-socks5-tproxy-linux-arm32hf hev-socks5-tproxy-linux-arm32) ;;
    *) die "No transparent-proxy build mapping for ${PAQET_ARCH}" ;;
  esac
  TPROXY_ASSET_NAME=""
  for candidate in "${TPROXY_CANDIDATES[@]}"; do
    if jq -e --arg name "$candidate" '.assets[] | select(.name==$name)' "$TPROXY_RELEASE_JSON" >/dev/null; then
      TPROXY_ASSET_NAME="$candidate"
      break
    fi
  done
  [[ -n "$TPROXY_ASSET_NAME" ]] || die "No compatible HevSocks5TProxy asset was found for ${PAQET_ARCH}"
  TPROXY_ASSET_URL="$(jq -er --arg name "$TPROXY_ASSET_NAME" '.assets[] | select(.name==$name) | .browser_download_url' "$TPROXY_RELEASE_JSON")"
  TPROXY_ASSET_DIGEST="$(jq -er --arg name "$TPROXY_ASSET_NAME" '.assets[] | select(.name==$name) | .digest // empty' "$TPROXY_RELEASE_JSON")"
  [[ "$TPROXY_ASSET_URL" == "https://github.com/${TPROXY_REPOSITORY}/releases/download/"* ]] || die "Unexpected transparent-proxy asset URL"
  [[ "$TPROXY_ASSET_DIGEST" =~ ^sha256:[[:xdigit:]]{64}$ ]] || die "Transparent-proxy asset has no valid SHA-256 digest"
  TPROXY_EXPECTED_SHA="${TPROXY_ASSET_DIGEST#sha256:}"; TPROXY_EXPECTED_SHA="${TPROXY_EXPECTED_SHA,,}"
  TPROXY_DOWNLOAD="${TMP_DIR}/${TPROXY_ASSET_NAME}"
  curl --proto '=https' --tlsv1.2 -fL --retry 3 --retry-delay 2 --connect-timeout 10 --max-time 300 \
    "$TPROXY_ASSET_URL" -o "$TPROXY_DOWNLOAD"
  [[ -s "$TPROXY_DOWNLOAD" ]] || die "Downloaded transparent-proxy binary is empty"
  TPROXY_ACTUAL_SHA="$(sha256sum "$TPROXY_DOWNLOAD" | awk '{print $1}')"
  [[ "$TPROXY_ACTUAL_SHA" == "$TPROXY_EXPECTED_SHA" ]] || die "Transparent-proxy SHA-256 verification failed"
  install -m 0755 -o root -g root "$TPROXY_DOWNLOAD" "$TPROXY_BIN_PATH"
  log_success "Verified and installed ${TPROXY_BIN_PATH}"
else
  rm -f -- "$TPROXY_BIN_PATH" "$TPROXY_CONFIG_PATH" "$TPROXY_SERVICE_PATH"
fi

apply_paqet_stability_profile() {
  local source="$1" tmp
  grep -q '^[[:space:]]*kcp:[[:space:]]*$' "$source" || die "Paqet config has no transport.kcp section"
  tmp="${TMP_DIR}/stable-config.yaml"
  # Older installer versions inherited Paqet's very short SMUX timeout. On
  # filtered or lossy routes that can tear down a healthy tunnel after a brief
  # burst of loss. Replace only installer-managed stability fields and leave all
  # user connection details untouched. The generated kcp section is the final
  # YAML section, so these indented keys remain inside transport.kcp.
  grep -Ev '^    (smuxbuf|streambuf|smuxkalive|smuxktimeout):[[:space:]]*' "$source" > "$tmp"
  cat >> "$tmp" <<STABILITY
    smuxbuf: ${STABLE_SMUX_BUFFER}
    streambuf: ${STABLE_STREAM_BUFFER}
    smuxkalive: ${STABLE_SMUX_KEEPALIVE}
    smuxktimeout: ${STABLE_SMUX_TIMEOUT}
STABILITY
  install -m 0640 -o root -g "$SERVICE_GROUP" "$tmp" "$source"
}

step "Creating role-specific configuration"
if [[ "$PRESERVE_CONFIG" != "1" ]]; then
  if [[ -f "$CONFIG_PATH" ]]; then
    BACKUP_SUFFIX="$(date -u +%Y%m%dT%H%M%SZ)"
    cp -a "$CONFIG_PATH" "${CONFIG_PATH}.bak.${BACKUP_SUFFIX}"
    [[ ! -f "$STATE_PATH" ]] || cp -a "$STATE_PATH" "${STATE_PATH}.bak.${BACKUP_SUFFIX}"
    log_warn "Previous configuration backed up with suffix ${BACKUP_SUFFIX}"
  fi

  if [[ "$ROLE" == "abroad" ]]; then
    CONFIG_TMP="${TMP_DIR}/config.yaml"
    cat > "$CONFIG_TMP" <<CONFIG
role: "server"

log:
  level: "info"

listen:
  addr: ":${TRANSPORT_PORT}"

network:
  interface: "${PAQET_INTERFACE}"
  ipv4:
    addr: "${PAQET_LOCAL_IP}:${TRANSPORT_PORT}"
    router_mac: "${PAQET_ROUTER_MAC}"
  tcp:
    local_flag: ["PA"]
    remote_flag: ["PA"]

transport:
  protocol: "kcp"
  conn: ${TRANSPORT_CONN}
  kcp:
    mode: "${KCP_MODE}"
    mtu: ${KCP_MTU}
    block: "${KCP_BLOCK}"
    key: "${PAQET_KEY}"
CONFIG
  else
    CONFIG_TMP="${TMP_DIR}/config.yaml"
    {
      cat <<CONFIG
role: "client"

log:
  level: "info"
CONFIG
      if [[ "$FORWARD_MODE" == "selected" ]]; then
        printf '\nforward:\n'
        for spec in "${FORWARD_SPECS[@]}"; do
          base="${spec%/*}"; protocol="${spec##*/}"; listen_port="${base%%:*}"; target_port="${base##*:}"
          cat <<CONFIG
  - listen: "${LISTEN_IP}:${listen_port}"
    target: "127.0.0.1:${target_port}"
    protocol: "${protocol}"
CONFIG
        done
      else
        cat <<CONFIG

# Used by the transparent all-port helper on the Iran server.
socks5:
  - listen: "127.0.0.1:1080"
CONFIG
      fi
      cat <<CONFIG

network:
  interface: "${PAQET_INTERFACE}"
  ipv4:
    addr: "${PAQET_LOCAL_IP}:0"
    router_mac: "${PAQET_ROUTER_MAC}"
  tcp:
    local_flag: ["PA"]
    remote_flag: ["PA"]

server:
  addr: "${FOREIGN_HOST}:${TRANSPORT_PORT}"

transport:
  protocol: "kcp"
  conn: ${TRANSPORT_CONN}
  kcp:
    mode: "${KCP_MODE}"
    mtu: ${KCP_MTU}
    block: "${KCP_BLOCK}"
    key: "${PAQET_KEY}"
CONFIG
    } > "$CONFIG_TMP"
  fi
  install -m 0640 -o root -g "$SERVICE_GROUP" "$CONFIG_TMP" "$CONFIG_PATH"
else
  # Recover values needed by services and firewall state.
  PAQET_KEY="$(awk -F'"' '/^[[:space:]]*key:[[:space:]]*"/ {print $2; exit}' "$CONFIG_PATH")"
  KCP_MODE="$(awk -F'"' '/^[[:space:]]*mode:[[:space:]]*"/ {print $2; exit}' "$CONFIG_PATH")"
  KCP_BLOCK="$(awk -F'"' '/^[[:space:]]*block:[[:space:]]*"/ {print $2; exit}' "$CONFIG_PATH")"
  TRANSPORT_CONN="$(awk '/^[[:space:]]*conn:[[:space:]]*[0-9]+/ {print $2; exit}' "$CONFIG_PATH")"
  KCP_MTU="$(awk '/^[[:space:]]*mtu:[[:space:]]*[0-9]+/ {print $2; exit}' "$CONFIG_PATH")"
  [[ -n "$KCP_MODE" ]] || KCP_MODE="fast"
  [[ -n "$KCP_BLOCK" ]] || KCP_BLOCK="aes"
  [[ -n "$TRANSPORT_CONN" ]] || TRANSPORT_CONN="1"
  [[ -n "$KCP_MTU" ]] || KCP_MTU="1350"
  validate_key "$PAQET_KEY" || die "Could not recover a valid key from ${CONFIG_PATH}"
  validate_kcp_mode "$KCP_MODE" || die "Could not recover a valid KCP mode from ${CONFIG_PATH}"
  validate_block "$KCP_BLOCK" || die "Could not recover a valid cipher from ${CONFIG_PATH}"

  if [[ "$ROLE" == "abroad" ]]; then
    TRANSPORT_PORT="$(awk -F'"' '/^[[:space:]]*addr:[[:space:]]*"\:[0-9]+"/ {value=$2; sub(/^:/,"",value); print value; exit}' "$CONFIG_PATH")"
    validate_transport_port "$TRANSPORT_PORT"
  else
    SERVER_ADDRESS="$(awk -F'"' '
      /^server:[[:space:]]*$/ {inside=1; next}
      inside && /^[^[:space:]]/ {inside=0}
      inside && /^[[:space:]]+addr:[[:space:]]*"/ {print $2; exit}
    ' "$CONFIG_PATH")"
    [[ "$SERVER_ADDRESS" == *:* ]] || die "Could not recover abroad server address from ${CONFIG_PATH}"
    FOREIGN_HOST="${SERVER_ADDRESS%:*}"
    TRANSPORT_PORT="${SERVER_ADDRESS##*:}"
    validate_host "$FOREIGN_HOST" || die "Invalid preserved abroad host"
    validate_transport_port "$TRANSPORT_PORT"

    # Older installs may not have install.env; recover generated forward entries.
    if ((${#FORWARD_SPECS[@]} == 0)); then
      while IFS= read -r recovered; do
        [[ -n "$recovered" ]] && append_forward_values "$recovered"
      done < <(awk -F'"' '
        /^forward:[[:space:]]*$/ {inside=1; next}
        inside && /^[^[:space:]]/ {inside=0}
        inside && /listen:[[:space:]]*"/ {listen=$2; sub(/^.*:/,"",listen)}
        inside && /target:[[:space:]]*"/ {target=$2; sub(/^.*:/,"",target)}
        inside && /protocol:[[:space:]]*"/ {protocol=$2; if(listen!="" && target!="") {print listen ":" target "/" protocol; listen=""; target=""}}
      ' "$CONFIG_PATH")
    fi
    if [[ "$FORWARD_MODE" == "selected" ]]; then
      ((${#FORWARD_SPECS[@]} > 0)) || die "Preserved selected-mode Iran config contains no port forwards"
      detect_ssh_ports
      validate_selected_forward_safety
    else
      grep -q '^[[:space:]]*socks5:' "$CONFIG_PATH" || die "Preserved all-port config has no SOCKS5 listener"
      detect_ssh_ports
      choose_tproxy_port
    fi
  fi
fi

apply_paqet_stability_profile "$CONFIG_PATH"
log_success "Applied stable SMUX keepalive and buffer profile"

if [[ "$ROLE" == "iran" && "$FORWARD_MODE" == "all" ]]; then
  TPROXY_WORKERS=1
  if command -v nproc >/dev/null 2>&1; then
    TPROXY_WORKERS="$(nproc 2>/dev/null || printf '1')"
  elif command -v getconf >/dev/null 2>&1; then
    TPROXY_WORKERS="$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf '1')"
  fi
  [[ "$TPROXY_WORKERS" =~ ^[0-9]+$ ]] || TPROXY_WORKERS=1
  ((TPROXY_WORKERS < 1)) && TPROXY_WORKERS=1
  ((TPROXY_WORKERS > 4)) && TPROXY_WORKERS=4
  cat > "$TPROXY_CONFIG_PATH" <<TPROXY_CONFIG
main:
  workers: ${TPROXY_WORKERS}

socks5:
  port: 1080
  address: 127.0.0.1
  udp: 'udp'
  # Mark helper-created SOCKS sockets so future firewall changes cannot loop
  # them back into the transparent chain.
  mark: 1080

# Transparent sockets receive the original Iran destination address and port.
tcp:
  port: ${TPROXY_PORT}
  address: '0.0.0.0'

udp:
  port: ${TPROXY_PORT}
  address: '0.0.0.0'

misc:
  connect-timeout: 15000
  tcp-read-write-timeout: 900000
  udp-read-write-timeout: 120000
  log-file: stderr
  log-level: warn
  limit-nofile: 1048576
TPROXY_CONFIG
  chmod 0640 "$TPROXY_CONFIG_PATH"
  chown root:"$SERVICE_GROUP" "$TPROXY_CONFIG_PATH"
else
  rm -f -- "$TPROXY_CONFIG_PATH"
fi

FORWARD_CSV="$(forward_specs_csv)"
EXCLUDED_CSV="$(ports_csv EXCLUDED_PORTS)"
SSH_CSV="$(ports_csv SSH_PORTS)"
cat > "$STATE_PATH" <<STATE
ROLE=${ROLE}
VERSION=${RELEASE_TAG}
TRANSPORT_PORT=${TRANSPORT_PORT}
FOREIGN_HOST=${FOREIGN_HOST}
LISTEN_IP=${LISTEN_IP}
TARGET_HOST=127.0.0.1
FORWARD_MODE=${FORWARD_MODE}
FORWARD_PROTOCOL=${FORWARD_PROTOCOL}
FORWARD_SPECS=${FORWARD_CSV}
EXCLUDED_PORTS=${EXCLUDED_CSV}
SSH_PORTS=${SSH_CSV}
TPROXY_PORT=${TPROXY_PORT}
TPROXY_VERSION=${TPROXY_VERSION}
OPEN_FORWARD_PORTS=${OPEN_FORWARD_PORTS}
SERVICE_UID=${SERVICE_UID}
SERVICE_USER_CREATED=${SERVICE_USER_CREATED}
STATE
chmod 0600 "$STATE_PATH"

rm -f "$LEGACY_TOKEN_PATH"
log_success "Created ${ROLE} configuration at ${CONFIG_PATH}"

step "Installing persistent firewall and systemd services"
FORWARD_FIREWALL=""
if [[ "$ROLE" == "iran" && "$FORWARD_MODE" == "selected" && "$OPEN_FORWARD_PORTS" == "1" ]]; then
  for spec in "${FORWARD_SPECS[@]}"; do
    base="${spec%/*}"; protocol="${spec##*/}"; listen_port="${base%%:*}"
    [[ -n "$FORWARD_FIREWALL" ]] && FORWARD_FIREWALL+=","
    FORWARD_FIREWALL+="${listen_port}/${protocol}"
  done
fi
cat > "$FIREWALL_ENV" <<ENV
ROLE=${ROLE}
TRANSPORT_PORT=${TRANSPORT_PORT}
FORWARD_MODE=${FORWARD_MODE}
FORWARD_PROTOCOL=${FORWARD_PROTOCOL}
FORWARD_PORTS=${FORWARD_FIREWALL}
EXCLUDED_PORTS=${EXCLUDED_CSV}
SSH_PORTS=${SSH_CSV}
TPROXY_PORT=${TPROXY_PORT}
INTERFACE=${PAQET_INTERFACE}
SERVICE_UID=${SERVICE_UID}
ENV
chmod 0600 "$FIREWALL_ENV"

cat > "$FIREWALL_SCRIPT" <<'FIREWALL'
#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
readonly ENV_FILE="/etc/paqet-x/firewall.env"
readonly STATE_FILE="/run/paqet-x-firewall.state"
readonly ALLPORT_CHAIN="PAQETX_ALLPORT"
readonly TPROXY_MARK="1088/0x7ff"
readonly TPROXY_BYPASS_MARK="1080/0x7ff"
readonly ROUTE_TABLE="100"
readonly SOCKS_PORT="1080"

read_value() {
  local key="$1"
  awk -F= -v key="$key" '$1==key {sub(/^[^=]*=/,""); print; exit}' "$ENV_FILE"
}
valid_port() { [[ "$1" =~ ^[0-9]+$ ]] && ((10#$1 >= 1 && 10#$1 <= 65535)); }
add_rule() { local table="$1"; shift; iptables -w 5 -t "$table" -C "$@" >/dev/null 2>&1 || iptables -w 5 -t "$table" -I "$@"; }
remove_rule() { local table="$1"; shift; while iptables -w 5 -t "$table" -C "$@" >/dev/null 2>&1; do iptables -w 5 -t "$table" -D "$@"; done; }
read_kernel_value() {
  local path="$1"
  [[ -r "$path" ]] || return 0
  tr -d '[:space:]' < "$path"
}
write_kernel_value() {
  local path="$1" value="$2"
  [[ -w "$path" ]] || return 0
  printf '%s\n' "$value" > "$path"
}
set_tproxy_kernel_values() {
  local interface="$1"
  # Strict reverse-path filtering can silently discard fwmark-routed TPROXY
  # packets. Loose mode retains source validation while permitting this path.
  write_kernel_value /proc/sys/net/ipv4/conf/all/rp_filter 2
  write_kernel_value "/proc/sys/net/ipv4/conf/${interface}/rp_filter" 2
}
restore_tproxy_kernel_values() {
  local interface="$1" all_old="${2:-}" interface_old="${3:-}"
  [[ -z "$all_old" ]] || write_kernel_value /proc/sys/net/ipv4/conf/all/rp_filter "$all_old"
  [[ -z "$interface_old" ]] || write_kernel_value "/proc/sys/net/ipv4/conf/${interface}/rp_filter" "$interface_old"
}

remove_allport() {
  local interface="$1"
  # Remove the old v4.0 interface-scoped hook as well as the corrected global hook.
  if [[ -n "$interface" ]]; then
    remove_rule mangle PREROUTING -i "$interface" -m addrtype --dst-type LOCAL -j "$ALLPORT_CHAIN"
  fi
  remove_rule mangle PREROUTING -m addrtype --dst-type LOCAL -j "$ALLPORT_CHAIN"
  remove_rule filter INPUT -m mark --mark "$TPROXY_MARK" -j ACCEPT
  iptables -w 5 -t mangle -F "$ALLPORT_CHAIN" >/dev/null 2>&1 || true
  iptables -w 5 -t mangle -X "$ALLPORT_CHAIN" >/dev/null 2>&1 || true
  while ip rule del fwmark "$TPROXY_MARK" table "$ROUTE_TABLE" >/dev/null 2>&1; do :; done
  ip route flush table "$ROUTE_TABLE" >/dev/null 2>&1 || true
}

add_exclusion_rules() {
  local protocol="$1" transport="$2" ssh_ports="$3" excluded_ports="$4" item
  local -a values=() ssh_items=() excluded_items=()
  values+=("$transport")
  IFS=',' read -r -a ssh_items <<<"$ssh_ports"
  values+=("${ssh_items[@]:-}")
  IFS=',' read -r -a excluded_items <<<"$excluded_ports"
  values+=("${excluded_items[@]:-}")
  for item in "${values[@]}"; do
    [[ -n "$item" ]] || continue
    valid_port "$item" || return 1
    iptables -w 5 -t mangle -A "$ALLPORT_CHAIN" -p "$protocol" --dport "$item" -j RETURN
  done
}

apply_allport() {
  local transport="$1" protocol_mode="$2" excluded_ports="$3" ssh_ports="$4" tproxy_port="$5" interface="$6"
  if ! valid_port "$transport" || ! valid_port "$tproxy_port"; then return 1; fi
  [[ "$protocol_mode" == tcp || "$protocol_mode" == udp || "$protocol_mode" == both ]] || return 1
  [[ "$interface" =~ ^[A-Za-z0-9_.:@-]+$ ]] || return 1

  if command -v modprobe >/dev/null 2>&1; then
    modprobe xt_TPROXY nf_tproxy_ipv4 >/dev/null 2>&1 || true
  fi

  set_tproxy_kernel_values "$interface"
  remove_allport "$interface"
  iptables -w 5 -t mangle -N "$ALLPORT_CHAIN"

  # Do not re-capture loopback traffic, sockets created by Hev itself, or
  # Paqet tunnel replies. Client tunnel replies arrive from the Abroad
  # transport source port and must bypass TPROXY or the tunnel feeds itself.
  iptables -w 5 -t mangle -A "$ALLPORT_CHAIN" -i lo -j RETURN
  iptables -w 5 -t mangle -A "$ALLPORT_CHAIN" -m mark --mark "$TPROXY_BYPASS_MARK" -j RETURN
  iptables -w 5 -t mangle -A "$ALLPORT_CHAIN" -p tcp --sport "$transport" -j RETURN

  if [[ "$protocol_mode" == tcp || "$protocol_mode" == both ]]; then
    add_exclusion_rules tcp "$transport" "$ssh_ports" "$excluded_ports"
    iptables -w 5 -t mangle -A "$ALLPORT_CHAIN" -p tcp --dport "$SOCKS_PORT" -j RETURN
    iptables -w 5 -t mangle -A "$ALLPORT_CHAIN" -p tcp --dport "$tproxy_port" -j RETURN
    iptables -w 5 -t mangle -A "$ALLPORT_CHAIN" -p tcp -j TPROXY --on-ip 127.0.0.1 --on-port "$tproxy_port" --tproxy-mark "$TPROXY_MARK"
  fi
  if [[ "$protocol_mode" == udp || "$protocol_mode" == both ]]; then
    add_exclusion_rules udp "$transport" "$ssh_ports" "$excluded_ports"
    iptables -w 5 -t mangle -A "$ALLPORT_CHAIN" -p udp --dport "$SOCKS_PORT" -j RETURN
    iptables -w 5 -t mangle -A "$ALLPORT_CHAIN" -p udp --dport "$tproxy_port" -j RETURN
    iptables -w 5 -t mangle -A "$ALLPORT_CHAIN" -p udp -j TPROXY --on-ip 127.0.0.1 --on-port "$tproxy_port" --tproxy-mark "$TPROXY_MARK"
  fi

  # Do not bind the hook to one interface: VPS public traffic can arrive on a
  # provider/NAT-facing interface different from the default-route interface.
  add_rule mangle PREROUTING -m addrtype --dst-type LOCAL -j "$ALLPORT_CHAIN"
  add_rule filter INPUT -m mark --mark "$TPROXY_MARK" -j ACCEPT
  ip rule add fwmark "$TPROXY_MARK" table "$ROUTE_TABLE"
  ip route replace local default dev lo table "$ROUTE_TABLE"
}

apply_set() {
  local role="$1" transport="$2" mode="$3" protocol_mode="$4" forwards="$5" excluded="$6" ssh_ports="$7" tproxy_port="$8" interface="$9" service_uid="${10}"
  local item port proto
  if [[ "$role" == "abroad" ]]; then
    if ! valid_port "$transport" || [[ ! "$service_uid" =~ ^[0-9]+$ ]]; then return 1; fi
    add_rule raw PREROUTING -p tcp --dport "$transport" -j NOTRACK
    add_rule raw OUTPUT -p tcp --sport "$transport" -j NOTRACK
    add_rule mangle OUTPUT -p tcp --sport "$transport" --tcp-flags RST RST -j DROP
    add_rule filter INPUT -p tcp --dport "$transport" -j ACCEPT
    # In all-port mode, Hev preserves the Iran server's original destination
    # address. Redirect only Paqet-created target sockets back to this Abroad
    # host while preserving the destination port. Tunnel packets are identified
    # by their SOURCE port; excluding dport here recaptures raw tunnel replies
    # and causes a rapid disconnect/reconnect loop.
    add_rule nat OUTPUT -m owner --uid-owner "$service_uid" -p tcp ! --sport "$transport" ! -d 127.0.0.0/8 -j REDIRECT
    add_rule nat OUTPUT -m owner --uid-owner "$service_uid" -p udp ! -d 127.0.0.0/8 -j REDIRECT
  elif [[ "$role" == "iran" && "$mode" == "selected" && -n "$forwards" ]]; then
    IFS=',' read -r -a items <<<"$forwards"
    for item in "${items[@]}"; do
      port="${item%/*}"; proto="${item##*/}"
      if ! valid_port "$port" || [[ "$proto" != tcp && "$proto" != udp ]]; then return 1; fi
      add_rule filter INPUT -p "$proto" --dport "$port" -j ACCEPT
    done
  elif [[ "$role" == "iran" && "$mode" == "all" ]]; then
    apply_allport "$transport" "$protocol_mode" "$excluded" "$ssh_ports" "$tproxy_port" "$interface"
  fi
}

remove_set() {
  local role="$1" transport="$2" mode="$3" protocol_mode="$4" forwards="$5" excluded="$6" ssh_ports="$7" tproxy_port="$8" interface="$9" service_uid="${10}"
  local item port proto
  if [[ "$role" == "abroad" ]] && valid_port "$transport"; then
    remove_rule raw PREROUTING -p tcp --dport "$transport" -j NOTRACK
    remove_rule raw OUTPUT -p tcp --sport "$transport" -j NOTRACK
    remove_rule mangle OUTPUT -p tcp --sport "$transport" --tcp-flags RST RST -j DROP
    remove_rule filter INPUT -p tcp --dport "$transport" -j ACCEPT
    if [[ "$service_uid" =~ ^[0-9]+$ ]]; then
      # Remove v4.0, broken v4.1, and current destination-rewrite variants.
      remove_rule nat OUTPUT -m owner --uid-owner "$service_uid" -p tcp ! --sport "$transport" -j DNAT --to-destination 127.0.0.1
      remove_rule nat OUTPUT -m owner --uid-owner "$service_uid" -p udp -j DNAT --to-destination 127.0.0.1
      remove_rule nat OUTPUT -m owner --uid-owner "$service_uid" -p tcp ! --dport "$transport" ! -d 127.0.0.0/8 -j REDIRECT
      remove_rule nat OUTPUT -m owner --uid-owner "$service_uid" -p tcp ! --sport "$transport" ! -d 127.0.0.0/8 -j REDIRECT
      remove_rule nat OUTPUT -m owner --uid-owner "$service_uid" -p udp ! -d 127.0.0.0/8 -j REDIRECT
    fi
  elif [[ "$role" == "iran" && "$mode" == "selected" && -n "$forwards" ]]; then
    IFS=',' read -r -a items <<<"$forwards"
    for item in "${items[@]}"; do
      port="${item%/*}"; proto="${item##*/}"
      if ! valid_port "$port" || [[ "$proto" != tcp && "$proto" != udp ]]; then continue; fi
      remove_rule filter INPUT -p "$proto" --dport "$port" -j ACCEPT
    done
  elif [[ "$role" == "iran" && "$mode" == "all" ]]; then
    remove_allport "$interface"
  fi
}

verify_set() {
  local role="$1" transport="$2" mode="$3" protocol_mode="$4" forwards="$5" excluded="$6" ssh_ports="$7" tproxy_port="$8" interface="$9" service_uid="${10}"
  if [[ "$role" == "abroad" ]]; then
    [[ "$service_uid" =~ ^[0-9]+$ ]] || return 1
    iptables -w 5 -t raw -C PREROUTING -p tcp --dport "$transport" -j NOTRACK >/dev/null 2>&1 || return 1
    iptables -w 5 -t nat -C OUTPUT -m owner --uid-owner "$service_uid" -p tcp ! --sport "$transport" ! -d 127.0.0.0/8 -j REDIRECT >/dev/null 2>&1 || return 1
  elif [[ "$role" == "iran" && "$mode" == "all" ]]; then
    iptables -w 5 -t mangle -C PREROUTING -m addrtype --dst-type LOCAL -j "$ALLPORT_CHAIN" >/dev/null 2>&1 || return 1
    # This bypass is the critical anti-loop rule: tunnel replies use the Abroad
    # transport port as their source port and must never enter TPROXY.
    iptables -w 5 -t mangle -C "$ALLPORT_CHAIN" -p tcp --sport "$transport" -j RETURN >/dev/null 2>&1 || return 1
    if [[ "$protocol_mode" == tcp || "$protocol_mode" == both ]]; then
      iptables -w 5 -t mangle -C "$ALLPORT_CHAIN" -p tcp -j TPROXY --on-ip 127.0.0.1 --on-port "$tproxy_port" --tproxy-mark "$TPROXY_MARK" >/dev/null 2>&1 || return 1
    fi
    if [[ "$protocol_mode" == udp || "$protocol_mode" == both ]]; then
      iptables -w 5 -t mangle -C "$ALLPORT_CHAIN" -p udp -j TPROXY --on-ip 127.0.0.1 --on-port "$tproxy_port" --tproxy-mark "$TPROXY_MARK" >/dev/null 2>&1 || return 1
    fi
    ip rule show | grep -Eq 'fwmark (0x)?440(/0x7ff)?.*(lookup|table) 100|fwmark 0x440/0x7ff.*lookup 100' || return 1
    ip route show table "$ROUTE_TABLE" | grep -Eq '^local (default|0\.0\.0\.0/0) dev lo' || return 1
  fi
}

read_env_set() {
  role="$(read_value ROLE)"
  transport="$(read_value TRANSPORT_PORT)"
  mode="$(read_value FORWARD_MODE)"
  protocol_mode="$(read_value FORWARD_PROTOCOL)"
  forwards="$(read_value FORWARD_PORTS)"
  excluded="$(read_value EXCLUDED_PORTS)"
  ssh_ports="$(read_value SSH_PORTS)"
  tproxy_port="$(read_value TPROXY_PORT)"
  interface="$(read_value INTERFACE)"
  service_uid="$(read_value SERVICE_UID)"
}

read_state_set() {
  role="$(awk -F= '$1=="ROLE"{print $2}' "$STATE_FILE")"
  transport="$(awk -F= '$1=="TRANSPORT_PORT"{print $2}' "$STATE_FILE")"
  mode="$(awk -F= '$1=="FORWARD_MODE"{print $2}' "$STATE_FILE")"
  protocol_mode="$(awk -F= '$1=="FORWARD_PROTOCOL"{print $2}' "$STATE_FILE")"
  forwards="$(awk -F= '$1=="FORWARD_PORTS"{sub(/^[^=]*=/,"");print}' "$STATE_FILE")"
  excluded="$(awk -F= '$1=="EXCLUDED_PORTS"{sub(/^[^=]*=/,"");print}' "$STATE_FILE")"
  ssh_ports="$(awk -F= '$1=="SSH_PORTS"{sub(/^[^=]*=/,"");print}' "$STATE_FILE")"
  tproxy_port="$(awk -F= '$1=="TPROXY_PORT"{print $2}' "$STATE_FILE")"
  interface="$(awk -F= '$1=="INTERFACE"{print $2}' "$STATE_FILE")"
  service_uid="$(awk -F= '$1=="SERVICE_UID"{print $2}' "$STATE_FILE")"
  rp_filter_all_old="$(awk -F= '$1=="RP_FILTER_ALL_OLD"{print $2}' "$STATE_FILE")"
  rp_filter_interface_old="$(awk -F= '$1=="RP_FILTER_INTERFACE_OLD"{print $2}' "$STATE_FILE")"
}

[[ -r "$ENV_FILE" ]] || { echo "Missing $ENV_FILE" >&2; exit 1; }
read_env_set
[[ "$role" == abroad || "$role" == iran ]] || { echo "Invalid ROLE" >&2; exit 1; }

case "${1:-}" in
  start)
    rp_filter_all_old=""
    rp_filter_interface_old=""
    if [[ -r "$STATE_FILE" ]]; then
      read_state_set
      remove_set "$role" "$transport" "$mode" "$protocol_mode" "$forwards" "$excluded" "$ssh_ports" "$tproxy_port" "$interface" "$service_uid"
      if [[ "$role" == "iran" && "$mode" == "all" ]]; then
        restore_tproxy_kernel_values "$interface" "$rp_filter_all_old" "$rp_filter_interface_old"
      fi
      read_env_set
    fi
    if [[ "$role" == "iran" && "$mode" == "all" ]]; then
      rp_filter_all_old="$(read_kernel_value /proc/sys/net/ipv4/conf/all/rp_filter)"
      rp_filter_interface_old="$(read_kernel_value "/proc/sys/net/ipv4/conf/${interface}/rp_filter")"
    fi
    apply_set "$role" "$transport" "$mode" "$protocol_mode" "$forwards" "$excluded" "$ssh_ports" "$tproxy_port" "$interface" "$service_uid"
    install -d -m 0755 "$(dirname "$STATE_FILE")"
    cp "$ENV_FILE" "$STATE_FILE"
    printf 'RP_FILTER_ALL_OLD=%s\nRP_FILTER_INTERFACE_OLD=%s\n' "$rp_filter_all_old" "$rp_filter_interface_old" >> "$STATE_FILE"
    ;;
  stop)
    rp_filter_all_old=""
    rp_filter_interface_old=""
    [[ -r "$STATE_FILE" ]] && read_state_set
    remove_set "$role" "$transport" "$mode" "$protocol_mode" "$forwards" "$excluded" "$ssh_ports" "$tproxy_port" "$interface" "$service_uid"
    if [[ "$role" == "iran" && "$mode" == "all" ]]; then
      restore_tproxy_kernel_values "$interface" "$rp_filter_all_old" "$rp_filter_interface_old"
    fi
    rm -f "$STATE_FILE"
    ;;
  verify)
    verify_set "$role" "$transport" "$mode" "$protocol_mode" "$forwards" "$excluded" "$ssh_ports" "$tproxy_port" "$interface" "$service_uid"
    ;;
  *) echo "Usage: $0 {start|stop|verify}" >&2; exit 2 ;;
esac
FIREWALL
chmod 0750 "$FIREWALL_SCRIPT"; chown root:root "$FIREWALL_SCRIPT"

cat > "$FIREWALL_SERVICE_PATH" <<UNIT
[Unit]
Description=Paqet X firewall and policy-routing rules
After=local-fs.target
Before=${SERVICE_NAME} ${TPROXY_SERVICE_NAME}

[Service]
Type=oneshot
ExecStart=${FIREWALL_SCRIPT} start
ExecStop=${FIREWALL_SCRIPT} stop
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
UNIT

cat > "$SERVICE_PATH" <<UNIT
[Unit]
Description=Paqet X ${ROLE} tunnel
StartLimitIntervalSec=120
StartLimitBurst=8
Documentation=https://github.com/${INSTALLER_REPOSITORY}
After=network-online.target ${FIREWALL_SERVICE_NAME}
Wants=network-online.target
Requires=${FIREWALL_SERVICE_NAME}

[Service]
Type=simple
User=${SERVICE_USER}
Group=${SERVICE_GROUP}
ExecStart=${BIN_PATH} run -c ${CONFIG_PATH}
Restart=on-failure
RestartSec=5s
TimeoutStopSec=15s
LimitNOFILE=1048576
UMask=0077
NoNewPrivileges=yes
PrivateTmp=yes
ProtectHome=yes
ProtectSystem=full
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
RestrictSUIDSGID=yes
LockPersonality=yes
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_RAW CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_RAW CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
UNIT

if [[ "$ROLE" == "iran" && "$FORWARD_MODE" == "all" ]]; then
  cat > "$TPROXY_SERVICE_PATH" <<UNIT
[Unit]
Description=Paqet X transparent all-port forwarding helper
StartLimitIntervalSec=120
StartLimitBurst=8
Documentation=https://github.com/${TPROXY_REPOSITORY}
After=${SERVICE_NAME} ${FIREWALL_SERVICE_NAME}
Requires=${SERVICE_NAME} ${FIREWALL_SERVICE_NAME}

[Service]
Type=simple
User=${SERVICE_USER}
Group=${SERVICE_GROUP}
ExecStart=${TPROXY_BIN_PATH} ${TPROXY_CONFIG_PATH}
Restart=on-failure
RestartSec=5s
LimitNOFILE=1048576
UMask=0077
NoNewPrivileges=yes
PrivateTmp=yes
ProtectHome=yes
ProtectSystem=full
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
RestrictSUIDSGID=yes
LockPersonality=yes
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
UNIT
else
  rm -f -- "$TPROXY_SERVICE_PATH"
fi
chmod 0644 "$SERVICE_PATH" "$FIREWALL_SERVICE_PATH"
[[ ! -f "$TPROXY_SERVICE_PATH" ]] || chmod 0644 "$TPROXY_SERVICE_PATH"

cat > "$MANAGER_PATH" <<'MANAGER'
#!/usr/bin/env bash
set -Eeuo pipefail
readonly SERVICE="paqet-x.service"
readonly FIREWALL="paqet-x-firewall.service"
readonly TPROXY="paqet-x-tproxy.service"
readonly CONFIG="/etc/paqet-x/config.yaml"
readonly STATE="/etc/paqet-x/install.env"
readonly FW_SCRIPT="/usr/local/lib/paqet-x/firewall.sh"
readonly TPROXY_UNIT="/etc/systemd/system/paqet-x-tproxy.service"
need_root() { ((EUID==0)) || { echo "Run with sudo." >&2; exit 1; }; }
state_value() { awk -F= -v key="$1" '$1==key{sub(/^[^=]*=/,"");print;exit}' "$STATE" 2>/dev/null || true; }
role() { state_value ROLE; }
mode() { state_value FORWARD_MODE; }
has_tproxy() { [[ "$(role)" == "iran" && "$(mode)" == "all" && -f "$TPROXY_UNIT" ]]; }
service_units() {
  SERVICE_UNITS=("$FIREWALL" "$SERVICE")
  if has_tproxy; then SERVICE_UNITS+=("$TPROXY"); fi
}
usage() { cat <<'EOF'
Usage: sudo paqetx COMMAND
  status     Show installed role and service status
  logs       Follow Paqet and all-port helper logs
  restart    Restart firewall, Paqet, and all-port helper when installed
  start      Start services
  stop       Stop services
  test       Run Paqet ping plus forwarding-path checks
  diagnose   Show service, restart, listener, routing, firewall, and packet counters
  key        Show shared key and tunnel port on the Abroad server
  config     Print active YAML configuration (contains the secret key)
  version    Show installer state and Paqet version
  uninstall  Remove Paqet X completely
EOF
}
cmd="${1:-status}"
case "$cmd" in
  status)
    echo "Role: $(role)"
    echo "Forward mode: $(mode)"
    service_units
    systemctl status "${SERVICE_UNITS[@]}" --no-pager
    ;;
  logs)
    if has_tproxy; then journalctl -u "$SERVICE" -u "$TPROXY" -f; else journalctl -u "$SERVICE" -f; fi
    ;;
  restart)
    need_root
    systemctl restart "$FIREWALL"
    systemctl restart "$SERVICE"
    if has_tproxy; then systemctl restart "$TPROXY"; fi
    service_units
    systemctl status "${SERVICE_UNITS[@]}" --no-pager
    ;;
  start)
    need_root
    systemctl start "$FIREWALL"
    systemctl start "$SERVICE"
    if has_tproxy; then systemctl start "$TPROXY"; fi
    ;;
  stop)
    need_root
    if has_tproxy; then systemctl stop "$TPROXY" || true; fi
    systemctl stop "$SERVICE" "$FIREWALL"
    ;;
  test)
    need_root
    if [[ "$(role)" == "iran" ]]; then
      /usr/local/bin/paqet ping -c "$CONFIG"
      if has_tproxy; then
        systemctl is-active --quiet "$TPROXY"
        "$FW_SCRIPT" verify
        echo "Tunnel, transparent helper, and policy-routing checks passed."
      fi
    else
      systemctl is-active --quiet "$SERVICE"
      "$FW_SCRIPT" verify
      echo "Abroad service and local destination redirect checks passed."
    fi
    ;;
  diagnose)
    need_root
    echo "=== State ==="
    cat "$STATE" 2>/dev/null || true
    echo "=== Services ==="
    service_units
    systemctl --no-pager --full status "${SERVICE_UNITS[@]}" || true
    echo "=== Restart counters ==="
    systemctl show "$SERVICE" "$TPROXY" -p Id -p ActiveState -p SubState -p NRestarts -p ExecMainStatus --no-pager 2>/dev/null || true
    echo "=== Recent tunnel lifecycle messages ==="
    journalctl -u "$SERVICE" --since "10 minutes ago" --no-pager 2>/dev/null | grep -Ei "established|closed pipe|EOF|reconnect|restart|failed" | tail -n 80 || true
    echo "=== Listeners ==="
    ss -lntup || true
    echo "=== Policy routing ==="
    ip rule show || true
    ip route show table 100 || true
    echo "=== Reverse-path filtering ==="
    cat /proc/sys/net/ipv4/conf/all/rp_filter 2>/dev/null || true
    interface="$(state_value INTERFACE)"
    [[ -z "$interface" ]] || cat "/proc/sys/net/ipv4/conf/${interface}/rp_filter" 2>/dev/null || true
    echo "=== Paqet X mangle counters ==="
    iptables -w 5 -t mangle -nvL PAQETX_ALLPORT --line-numbers 2>/dev/null || true
    echo "=== Paqet-owned destination redirect ==="
    iptables -w 5 -t nat -nvL OUTPUT --line-numbers 2>/dev/null || true
    echo "=== Verification ==="
    if "$FW_SCRIPT" verify; then echo "Firewall verification: OK"; else echo "Firewall verification: FAILED"; fi
    ;;
  key)
    need_root
    [[ "$(role)" == "abroad" ]] || { echo "The key command is available only on the Abroad role." >&2; exit 1; }
    key="$(awk -F'"' '/^[[:space:]]*key:[[:space:]]*"/ {print $2; exit}' "$CONFIG")"
    port="$(awk -F'"' '/^[[:space:]]*addr:[[:space:]]*":[0-9]+"/ {value=$2; sub(/^:/,"",value); print value; exit}' "$CONFIG")"
    version="$(state_value VERSION)"
    printf 'Paqet version: %s\nTunnel port: %s\nShared key: %s\n' "$version" "$port" "$key"
    ;;
  config) need_root; cat "$CONFIG" ;;
  version) cat "$STATE" 2>/dev/null || true; /usr/local/bin/paqet version ;;
  uninstall)
    need_root
    [[ "${2:-}" == "--yes" ]] || { printf 'Remove Paqet X and its configuration? [y/N] ' > /dev/tty; read -r answer < /dev/tty; [[ "$answer" =~ ^[Yy]$ ]] || exit 0; }
    user_created="$(state_value SERVICE_USER_CREATED)"
    systemctl disable --now "$TPROXY" "$SERVICE" "$FIREWALL" >/dev/null 2>&1 || true
    "$FW_SCRIPT" stop >/dev/null 2>&1 || true
    rm -f /etc/systemd/system/paqet-x.service /etc/systemd/system/paqet-x-firewall.service /etc/systemd/system/paqet-x-tproxy.service
    systemctl daemon-reload
    systemctl reset-failed "$TPROXY" "$SERVICE" "$FIREWALL" >/dev/null 2>&1 || true
    rm -rf /etc/paqet-x /usr/local/lib/paqet-x /var/lib/paqet-x
    rm -f /usr/local/bin/paqet /usr/local/bin/hev-socks5-tproxy /usr/local/sbin/paqetx
    if [[ "$user_created" == "1" ]] && id -u paqetx >/dev/null 2>&1; then
      if command -v userdel >/dev/null 2>&1; then userdel paqetx >/dev/null 2>&1 || true; elif command -v deluser >/dev/null 2>&1; then deluser --system paqetx >/dev/null 2>&1 || true; fi
    fi
    echo "Paqet X removed."
    ;;
  -h|--help|help) usage ;;
  *) usage >&2; exit 2 ;;
esac
MANAGER
chmod 0755 "$MANAGER_PATH"

systemctl daemon-reload
VERIFY_UNITS=("$SERVICE_PATH" "$FIREWALL_SERVICE_PATH")
[[ ! -f "$TPROXY_SERVICE_PATH" ]] || VERIFY_UNITS+=("$TPROXY_SERVICE_PATH")
if command -v systemd-analyze >/dev/null 2>&1; then
  systemd-analyze verify "${VERIFY_UNITS[@]}" >/dev/null 2>&1 || log_warn "systemd-analyze reported a warning; startup validation will still run"
fi
log_success "Installed systemd services, firewall helper, and paqetx manager"

step "Starting services and performing health checks"
if [[ "$SKIP_START" == "1" ]]; then
  log_warn "Services installed but not started (--no-start)"
else
  ENABLE_UNITS=("$FIREWALL_SERVICE_NAME" "$SERVICE_NAME")
  [[ "$ROLE" != "iran" || "$FORWARD_MODE" != "all" ]] || ENABLE_UNITS+=("$TPROXY_SERVICE_NAME")
  systemctl enable "${ENABLE_UNITS[@]}" >/dev/null
  systemctl restart "$FIREWALL_SERVICE_NAME"
  systemctl restart "$SERVICE_NAME"
  if [[ "$ROLE" == "iran" && "$FORWARD_MODE" == "all" ]]; then
    systemctl restart "$TPROXY_SERVICE_NAME"
  fi
  sleep 2
  systemctl is-active --quiet "$FIREWALL_SERVICE_NAME" || { journalctl -u "$FIREWALL_SERVICE_NAME" -n 80 --no-pager >&2 || true; die "Firewall or policy-routing service failed"; }
  systemctl is-active --quiet "$SERVICE_NAME" || { journalctl -u "$SERVICE_NAME" -n 100 --no-pager >&2 || true; die "Paqet service failed"; }
  if [[ "$ROLE" == "iran" && "$FORWARD_MODE" == "all" ]]; then
    systemctl is-active --quiet "$TPROXY_SERVICE_NAME" || { journalctl -u "$TPROXY_SERVICE_NAME" -n 100 --no-pager >&2 || true; die "All-port transparent-proxy service failed"; }
  fi
  if [[ "${PAQETX_TEST_MODE:-0}" != "1" ]]; then
    "$FIREWALL_SCRIPT" verify || die "Installed firewall/routing rules did not pass verification; run sudo paqetx diagnose"
    if [[ "$ROLE" == "iran" && "$FORWARD_MODE" == "all" ]]; then
      ss -H -lnt 2>/dev/null | awk '{print $4}' | grep -Eq '(^|:)1080$' || die "Paqet SOCKS5 listener is not active on 127.0.0.1:1080"
      if [[ "$FORWARD_PROTOCOL" == "tcp" || "$FORWARD_PROTOCOL" == "both" ]]; then
        ss -H -lnt 2>/dev/null | awk -v p=":${TPROXY_PORT}" '$4 ~ p"$" {found=1} END{exit !found}' || die "Transparent TCP listener is not active on port ${TPROXY_PORT}"
      fi
      if [[ "$FORWARD_PROTOCOL" == "udp" || "$FORWARD_PROTOCOL" == "both" ]]; then
        ss -H -lnu 2>/dev/null | awk -v p=":${TPROXY_PORT}" '$4 ~ p"$" {found=1} END{exit !found}' || die "Transparent UDP listener is not active on port ${TPROXY_PORT}"
      fi
    fi
  fi
  log_success "Paqet X services and forwarding prerequisites are active"
  if [[ "$ROLE" == "iran" ]]; then
    CONNECTION_OK=0
    for attempt in 1 2 3 4 5; do
      if "$BIN_PATH" ping -c "$CONFIG_PATH" >/dev/null 2>&1; then
        CONNECTION_OK=1
        break
      fi
      if (( attempt < 5 )) && [[ "${PAQETX_TEST_MODE:-0}" != "1" ]]; then sleep 2; fi
    done
    if [[ "$CONNECTION_OK" == "1" ]]; then
      log_success "Iran-to-abroad Paqet tunnel check succeeded"
    else
      journalctl -u "$SERVICE_NAME" -n 100 --no-pager >&2 || true
      die "Iran service started, but the tunnel check failed. Verify the Abroad host, tunnel port, shared key, matching Paqet version, and provider firewall"
    fi
  fi
fi

printf '\n%sInstallation complete%s\n' "$GREEN$BOLD" "$RESET"
printf '  Role:          %s\n' "$ROLE"
printf '  Paqet version: %s\n' "$RELEASE_TAG"
printf '  Config:        %s\n' "$CONFIG_PATH"
printf '  Manager:       sudo paqetx status\n'
if [[ "$ROLE" == "abroad" ]]; then
  printf '  Tunnel port:   %s\n' "$TRANSPORT_PORT"
  printf '\n%sSave these values for the Iran server:%s\n' "$BOLD" "$RESET"
  printf '  Paqet version: %s\n' "$RELEASE_TAG"
  printf '  Tunnel port:  %s\n' "$TRANSPORT_PORT"
  printf '  Shared key:   %s\n' "$PAQET_KEY"
  printf '\nAllow inbound TCP %s in the Abroad provider/cloud firewall.\n' "$TRANSPORT_PORT"
  printf 'Show them again later with: sudo paqetx key\n'
else
  printf '  Abroad server: %s:%s\n' "$FOREIGN_HOST" "$TRANSPORT_PORT"
  printf '  Forward mode:  %s\n' "$FORWARD_MODE"
  if [[ "$FORWARD_MODE" == "selected" ]]; then
    printf '  Forwards:      %s\n' "$(forward_specs_csv)"
    printf '\nThe Iran service is listening on the selected forwarding ports.\n'
  else
    printf '  Protocols:       %s\n' "$FORWARD_PROTOCOL"
    printf '  Tunnel excluded: %s\n' "$TRANSPORT_PORT"
    printf '  SSH excluded:    %s\n' "$(ports_csv SSH_PORTS)"
    printf '  Extra excluded:  %s\n' "${EXCLUDED_CSV:-none}"
    printf '\nAll selected-protocol ports are transparently forwarded except the listed exclusions.\n'
  fi
fi
printf '\nUseful commands:\n'
printf '  sudo paqetx status\n  sudo paqetx logs\n  sudo paqetx test\n  sudo paqetx diagnose\n'
