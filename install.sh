#!/bin/bash
#=================================================
# Paqet-X Client Manager v1.0
#=================================================

export LC_ALL=C
umask 027

# Colors
readonly RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m' BLUE='\033[0;34m' MAGENTA='\033[0;35m'
readonly WHITE='\033[1;37m' NC='\033[0m'

# Config
readonly SCRIPT_VERSION="5.1.0"
readonly BIN_DIR="/usr/local/bin"
readonly BIN_NAME="Paqet-X"
readonly INSTALL_DIR="/opt/paqet-x"
readonly CONFIG_DIR="/etc/paqet-x"
readonly SERVICE_DIR="/etc/systemd/system"
readonly PROJECT_REPOSITORY="Unknown-sir/paqetX"
readonly CORE_BINARY_URL="https://raw.githubusercontent.com/${PROJECT_REPOSITORY}/main/Paqet-Xv2"
readonly CORE_BINARY_SHA256="4ece7681bdc6f339307c269bec0ca1a2abd2edc4db1d3b8c644b687d91e061d2"
readonly HEV_REPOSITORY="heiher/hev-socks5-tproxy"
readonly HEV_VERSION="2.12.0"
readonly HEV_BIN="$BIN_DIR/hev-socks5-tproxy"
readonly LIBEXEC_DIR="/usr/local/libexec/paqet-x"
readonly STATE_DIR="$CONFIG_DIR/state"
readonly DEFAULT_TPROXY_PORT="1088"
readonly DEFAULT_INTERNAL_SOCKS_PORT="1080"
readonly ALLPORT_MARK="1088/0x7ff"
readonly ALLPORT_BYPASS_MARK="1080/0x7ff"
readonly ALLPORT_TABLE="10088"
readonly DEFAULT_LISTEN_PORT="8888"
readonly DEFAULT_KCP_MODE="fast"
readonly DEFAULT_ENCRYPTION="aes-128-gcm"
readonly DEFAULT_CONNECTIONS="6"
readonly DEFAULT_MTU="1150"
readonly DEFAULT_SOCKS5_PORT="1080"
readonly DEFAULT_V2RAY_PORTS="443,8443"

# KCP modes
declare -A KCP_MODES=(
    ["0"]="normal:Conservative / Reliable / Higher latency"
    ["1"]="fast:Balanced speed / Recommended"
    ["2"]="fast2:Aggressive / Lower latency"
    ["3"]="fast3:Most aggressive / Lowest latency"
)

# Encryption options
declare -A ENCRYPTION_OPTIONS=(
    ["1"]="aes-128-gcm:Best balance of speed and security"
    ["2"]="aes-128:Good security / Moderate speed"
    ["3"]="aes:Standard AES / Good security"
    ["4"]="salsa20:Fast stream cipher"
    ["5"]="aes-256:Maximum security / Slower"
    ["6"]="none:No encryption / Max speed"
    ["7"]="null:No encryption / Max speed"
)

# ═══════════════════════════════════════
#  Utility Functions
# ═══════════════════════════════════════
print_step()    { echo -e "${BLUE}[*]${NC} $1"; }
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error()   { echo -e "${RED}[✗]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_info()    { echo -e "${CYAN}[i]${NC} $1"; }

pause() { echo ""; read -p "${1:-Press Enter to continue...}" </dev/tty; }

check_root() { [[ $EUID -ne 0 ]] && { print_error "Run as root"; exit 1; }; }

show_banner() {
    clear
    echo -e "${MAGENTA}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                         PAQET-X                              ║"
    printf "║                 Enhanced Manager v%-8s                 ║\n" "$SCRIPT_VERSION"
    echo "║                                                              ║"
    echo "║  Based on MrAminiDev/Paqet-X-Nulled management workflow     ║"
    echo "║  Repository: https://github.com/Unknown-sir/paqetX          ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}
detect_os() {
    if [ -f /etc/os-release ]; then . /etc/os-release; echo "$ID"
    else echo "$(uname -s | tr '[:upper:]' '[:lower:]')"; fi
}

detect_arch() {
    local arch=$(uname -m)
    case $arch in
        x86_64|x86-64|amd64) echo "amd64" ;;
        aarch64|arm64) echo "arm64" ;;
        armv7l|armhf) echo "armv7" ;;
        *) print_error "Unsupported: $arch"; return 1 ;;
    esac
}

get_public_ip() {
    for svc in https://ifconfig.me/ip https://icanhazip.com https://api.ipify.org; do
        local ip=$(curl -4 -fsS --max-time 3 "$svc" 2>/dev/null)
        [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && { echo "$ip"; return; }
    done
    echo "N/A"
}

get_network_info() {
    NETWORK_INTERFACE=""
    LOCAL_IP=""
    GATEWAY_IP=""
    GATEWAY_MAC=""

    if command -v ip &>/dev/null; then
        NETWORK_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
        LOCAL_IP=$(ip -4 addr show "$NETWORK_INTERFACE" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
        GATEWAY_IP=$(ip route | grep default | awk '{print $3}' | head -1)

        if [ -n "$GATEWAY_IP" ]; then
            ping -c 1 -W 1 "$GATEWAY_IP" >/dev/null 2>&1 || true
            GATEWAY_MAC=$(ip neigh show "$GATEWAY_IP" 2>/dev/null | grep -oE '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}' | head -1)

            if [ -z "$GATEWAY_MAC" ] && command -v arp &>/dev/null; then
                GATEWAY_MAC=$(arp -n "$GATEWAY_IP" 2>/dev/null | awk "/^$GATEWAY_IP/ {print \$3}" | head -1)
            fi
        fi
    fi

    NETWORK_INTERFACE="${NETWORK_INTERFACE:-eth0}"
}

validate_ip() {
    local ip="$1" a b c d
    [[ "$ip" =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$ ]] || return 1
    a=${BASH_REMATCH[1]}; b=${BASH_REMATCH[2]}; c=${BASH_REMATCH[3]}; d=${BASH_REMATCH[4]}
    ((10#$a<=255 && 10#$b<=255 && 10#$c<=255 && 10#$d<=255))
}
validate_port() { [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -ge 1 ] && [ "$1" -le 65535 ]; }

validate_secret_key() {
    local key="$1"
    [[ ${#key} -ge 8 && ${#key} -le 128 && "$key" =~ ^[A-Za-z0-9._:@+=/-]+$ ]]
}

clean_config_name() {
    echo "$1" | tr -cd '[:alnum:]-_' | tr '[:upper:]' '[:lower:]'
}

clean_port_list() {
    echo "$1" | tr ',' '\n' | while read -r p; do
        p=$(echo "$p" | tr -d '[:space:]')
        validate_port "$p" && echo "$p"
    done | paste -sd ',' -
}

generate_secret_key() {
    if command -v openssl >/dev/null 2>&1; then openssl rand -hex 24; else head -c 48 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 32; echo; fi
}


normalize_csv() {
    local input="$1" item out=""
    IFS=',' read -ra items <<< "$input"
    for item in "${items[@]}"; do
        item=$(echo "$item" | tr -d '[:space:]')
        [ -n "$item" ] || continue
        if [[ "$item" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            local a="${BASH_REMATCH[1]}" b="${BASH_REMATCH[2]}"
            validate_port "$a" && validate_port "$b" && [ "$a" -le "$b" ] || continue
        else
            validate_port "$item" || continue
        fi
        case ",$out," in *",$item,"*) ;; *) out="${out:+$out,}$item" ;; esac
    done
    echo "$out"
}

csv_contains_port() {
    local csv="$1" port="$2" item
    IFS=',' read -ra items <<< "$csv"
    for item in "${items[@]}"; do
        if [[ "$item" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            (( port >= BASH_REMATCH[1] && port <= BASH_REMATCH[2] )) && return 0
        elif [ "$item" = "$port" ]; then
            return 0
        fi
    done
    return 1
}

append_csv_unique() {
    local current="$1" value="$2"
    [ -n "$value" ] || { echo "$current"; return; }
    csv_contains_port "$current" "$value" && { echo "$current"; return; }
    echo "${current:+$current,}$value"
}

detect_ssh_ports() {
    local ports="" p file
    if [[ -n "${SSH_CONNECTION:-}" ]]; then
        p=$(awk '{print $4}' <<< "$SSH_CONNECTION")
        validate_port "$p" && ports=$(append_csv_unique "$ports" "$p")
    fi
    if command -v sshd >/dev/null 2>&1; then
        while read -r p; do
            validate_port "$p" && ports=$(append_csv_unique "$ports" "$p")
        done < <(sshd -T 2>/dev/null | awk '$1=="port" {print $2}')
    fi
    if command -v ss >/dev/null 2>&1; then
        while read -r p; do
            validate_port "$p" && ports=$(append_csv_unique "$ports" "$p")
        done < <(ss -H -lntp 2>/dev/null | awk '/sshd/ {n=$4; sub(/^.*:/,"",n); print n}')
    fi
    for file in /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf; do
        [ -r "$file" ] || continue
        while read -r p; do
            validate_port "$p" && ports=$(append_csv_unique "$ports" "$p")
        done < <(awk 'tolower($1)=="port" && $2 ~ /^[0-9]+$/ {print $2}' "$file")
    done
    [ -n "$ports" ] || ports="22"
    echo "$ports"
}

service_slug() {
    printf '%s' "$1" | sha256sum | cut -c1-12
}

service_user_for() {
    echo "pqx-$(service_slug "$1")"
}

ensure_service_user() {
    local name="$1" user
    user=$(service_user_for "$name")
    if ! id "$user" >/dev/null 2>&1; then
        useradd --system --user-group --no-create-home --home-dir /nonexistent --shell "$(command -v nologin || echo /usr/sbin/nologin)" "$user"
    fi
    echo "$user"
}

remove_service_user() {
    local name="$1" user
    user=$(service_user_for "$name")
    id "$user" >/dev/null 2>&1 && userdel "$user" >/dev/null 2>&1 || true
}

port_is_listening() {
    local p="$1"
    ss -H -lntup 2>/dev/null | awk -v p=":$p" '$5 ~ p"$" {found=1} END{exit !found}'
}

find_free_port() {
    local p="$1"
    while ((p <= 65000)); do
        if ! port_is_listening "$p"; then echo "$p"; return 0; fi
        ((p++))
    done
    return 1
}

existing_allport_service() {
    local except="${1:-}" f n mode
    for f in "$STATE_DIR"/*.env; do
        [ -r "$f" ] || continue
        n=$(basename "$f" .env)
        [ "$n" = "$except" ] && continue
        mode=$(awk -F= '$1=="MODE" {print $2; exit}' "$f")
        [ "$mode" = all ] && { echo "$n"; return 0; }
    done
    return 1
}

metadata_file() { echo "$STATE_DIR/$1.env"; }
firewall_script_file() { echo "$LIBEXEC_DIR/firewall-$1.sh"; }
firewall_service_name() { echo "paqet-x-$1-firewall.service"; }
tproxy_service_name() { echo "paqet-x-$1-tproxy.service"; }
tproxy_config_file() { echo "$CONFIG_DIR/$1-tproxy.yaml"; }

read_meta() {
    local name="$1" key="$2" file
    file=$(metadata_file "$name")
    [ -r "$file" ] || return 1
    awk -F= -v k="$key" '$1==k {sub(/^[^=]*=/,""); print; exit}' "$file"
}

write_meta() {
    local name="$1"; shift
    mkdir -p "$STATE_DIR"
    local file; file=$(metadata_file "$name")
    : > "$file"
    while [ "$#" -gt 0 ]; do printf '%s\n' "$1" >> "$file"; shift; done
    chmod 600 "$file"
}

# ═══════════════════════════════════════
#  Firewall and all-port helpers
# ═══════════════════════════════════════
install_iptables_persistent() {
    # Rules are owned by per-tunnel systemd units. This package is optional and
    # retained only for compatibility with the original project.
    return 0
}

install_hev() {
    [ -x "$HEV_BIN" ] && return 0
    local arch api tmp json asset url digest actual
    arch=$(detect_arch) || return 1
    case "$arch" in
        amd64) asset="hev-socks5-tproxy-linux-x86_64" ;;
        arm64) asset="hev-socks5-tproxy-linux-arm64" ;;
        armv7) asset="hev-socks5-tproxy-linux-arm32v7hf" ;;
        *) print_error "Unsupported Hev architecture: $arch"; return 1 ;;
    esac
    command -v jq >/dev/null 2>&1 || { print_error "jq is required"; return 1; }
    api="https://api.github.com/repos/$HEV_REPOSITORY/releases/tags/$HEV_VERSION"
    tmp=$(mktemp -d)
    json="$tmp/release.json"
    print_step "Downloading HevSocks5TProxy $HEV_VERSION metadata..."
    curl -fsSL --retry 3 --connect-timeout 10 "$api" -o "$json" || { rm -rf "$tmp"; print_error "Hev release lookup failed"; return 1; }
    url=$(jq -er --arg n "$asset" '.assets[] | select(.name==$n) | .browser_download_url' "$json" 2>/dev/null) || true
    digest=$(jq -er --arg n "$asset" '.assets[] | select(.name==$n) | .digest // empty' "$json" 2>/dev/null) || true
    [ -n "$url" ] || { rm -rf "$tmp"; print_error "Hev asset $asset was not found"; return 1; }
    curl -fsSL --retry 3 --connect-timeout 10 "$url" -o "$tmp/hev" || { rm -rf "$tmp"; print_error "Hev download failed"; return 1; }
    if [[ "$digest" =~ ^sha256:([0-9a-fA-F]{64})$ ]]; then
        actual=$(sha256sum "$tmp/hev" | awk '{print $1}')
        [ "${actual,,}" = "${BASH_REMATCH[1],,}" ] || { rm -rf "$tmp"; print_error "Hev checksum verification failed"; return 1; }
    else
        print_warning "GitHub did not publish an asset digest; refusing unverified Hev binary"
        rm -rf "$tmp"
        return 1
    fi
    install -m 0755 "$tmp/hev" "$HEV_BIN"
    rm -rf "$tmp"
    print_success "HevSocks5TProxy installed and verified"
}

create_firewall_assets() {
    local name="$1" role="$2" tunnel_port="$3" mode="$4" protocol="$5" exclusions="$6" ssh_ports="$7" tproxy_port="$8" socks_port="$9" user="${10}" forwards="${11:-}"
    local script unit svc_uid
    script=$(firewall_script_file "$name")
    unit=$(firewall_service_name "$name")
    svc_uid=$(id -u "$user")
    mkdir -p "$LIBEXEC_DIR"
    cat > "$script" <<EOF
#!/bin/bash
set -Eeuo pipefail
ROLE='$role'
TUNNEL_PORT='$tunnel_port'
MODE='$mode'
PROTOCOL='$protocol'
EXCLUSIONS='$exclusions'
SSH_PORTS='$ssh_ports'
TPROXY_PORT='$tproxy_port'
SOCKS_PORT='$socks_port'
SERVICE_UID='$svc_uid'
FORWARDS='$forwards'
CHAIN='PQX_$(service_slug "$name")'
MARK='$ALLPORT_MARK'
BYPASS='$ALLPORT_BYPASS_MARK'
TABLE='$ALLPORT_TABLE'
STATE='/run/paqet-x-$name-firewall.state'

valid_port(){ [[ "\$1" =~ ^[0-9]+$ ]] && ((10#\$1>=1 && 10#\$1<=65535)); }
add(){ local t="\$1"; shift; iptables -w 5 -t "\$t" -C "\$@" >/dev/null 2>&1 || iptables -w 5 -t "\$t" -I "\$@"; }
del(){ local t="\$1"; shift; while iptables -w 5 -t "\$t" -C "\$@" >/dev/null 2>&1; do iptables -w 5 -t "\$t" -D "\$@"; done; }
add_exclusions(){
  local proto="\$1" csv item
  csv="\$TUNNEL_PORT,\$SSH_PORTS,\$EXCLUSIONS,\$SOCKS_PORT,\$TPROXY_PORT"
  IFS=',' read -ra xs <<< "\$csv"
  for item in "\${xs[@]}"; do
    [ -n "\$item" ] || continue
    if [[ "\$item" =~ ^([0-9]+)-([0-9]+)\$ ]]; then
      iptables -w 5 -t mangle -A "\$CHAIN" -p "\$proto" --dport "\${BASH_REMATCH[1]}:\${BASH_REMATCH[2]}" -j RETURN
    elif valid_port "\$item"; then
      iptables -w 5 -t mangle -A "\$CHAIN" -p "\$proto" --dport "\$item" -j RETURN
    fi
  done
}
remove_all(){
  del mangle PREROUTING -m addrtype --dst-type LOCAL -j "\$CHAIN"
  del filter INPUT -m mark --mark "\$MARK" -j ACCEPT
  iptables -w 5 -t mangle -F "\$CHAIN" >/dev/null 2>&1 || true
  iptables -w 5 -t mangle -X "\$CHAIN" >/dev/null 2>&1 || true
  while ip rule del fwmark "\$MARK" table "\$TABLE" >/dev/null 2>&1; do :; done
  ip route flush table "\$TABLE" >/dev/null 2>&1 || true
}
start_rules(){
  if [ "\$ROLE" = server ]; then
    add raw PREROUTING -p tcp --dport "\$TUNNEL_PORT" -j NOTRACK
    add raw OUTPUT -p tcp --sport "\$TUNNEL_PORT" -j NOTRACK
    add mangle OUTPUT -p tcp --sport "\$TUNNEL_PORT" --tcp-flags RST RST -j DROP
    add filter INPUT -p tcp --dport "\$TUNNEL_PORT" -j ACCEPT
  fi
  if [ "\$ROLE" = server ] && [ "\$MODE" = forward ]; then
    # Forward-profile server: dynamic all-port SOCKS requests are mapped to
    # localhost with the same destination port. Raw tunnel packets are excluded.
    add nat OUTPUT -m owner --uid-owner "\$SERVICE_UID" -p tcp ! --sport "\$TUNNEL_PORT" ! -d 127.0.0.0/8 -j REDIRECT
    add nat OUTPUT -m owner --uid-owner "\$SERVICE_UID" -p udp ! -d 127.0.0.0/8 -j REDIRECT
  elif [ "\$ROLE" = client ] && [ "\$MODE" = selected ]; then
    IFS=',' read -ra fs <<< "\$FORWARDS"
    for f in "\${fs[@]}"; do
      port="\${f%/*}"; proto="\${f##*/}"
      valid_port "\$port" || continue
      [ "\$proto" = tcp ] || [ "\$proto" = udp ] || continue
      add filter INPUT -p "\$proto" --dport "\$port" -j ACCEPT
    done
  elif [ "\$MODE" = all ]; then
    command -v modprobe >/dev/null 2>&1 && modprobe xt_TPROXY nf_tproxy_ipv4 >/dev/null 2>&1 || true
    remove_all
    printf 'ALL_RPF=%s\n' "\$(cat /proc/sys/net/ipv4/conf/all/rp_filter 2>/dev/null || true)" > "\$STATE"
    printf 'DEFAULT_RPF=%s\n' "\$(cat /proc/sys/net/ipv4/conf/default/rp_filter 2>/dev/null || true)" >> "\$STATE"
    sysctl -qw net.ipv4.conf.all.rp_filter=2 || true
    sysctl -qw net.ipv4.conf.default.rp_filter=2 || true
    iptables -w 5 -t mangle -N "\$CHAIN"
    iptables -w 5 -t mangle -A "\$CHAIN" -i lo -j RETURN
    iptables -w 5 -t mangle -A "\$CHAIN" -m mark --mark "\$BYPASS" -j RETURN
    # Tunnel replies arrive from the foreign transport source port.
    iptables -w 5 -t mangle -A "\$CHAIN" -p tcp --sport "\$TUNNEL_PORT" -j RETURN
    if [ "\$PROTOCOL" = tcp ] || [ "\$PROTOCOL" = both ]; then
      add_exclusions tcp
      iptables -w 5 -t mangle -A "\$CHAIN" -p tcp -j TPROXY --on-ip 127.0.0.1 --on-port "\$TPROXY_PORT" --tproxy-mark "\$MARK"
    fi
    if [ "\$PROTOCOL" = udp ] || [ "\$PROTOCOL" = both ]; then
      add_exclusions udp
      iptables -w 5 -t mangle -A "\$CHAIN" -p udp -j TPROXY --on-ip 127.0.0.1 --on-port "\$TPROXY_PORT" --tproxy-mark "\$MARK"
    fi
    add mangle PREROUTING -m addrtype --dst-type LOCAL -j "\$CHAIN"
    add filter INPUT -m mark --mark "\$MARK" -j ACCEPT
    ip rule add fwmark "\$MARK" table "\$TABLE"
    ip route replace local default dev lo table "\$TABLE"
  fi
}
stop_rules(){
  del raw PREROUTING -p tcp --dport "\$TUNNEL_PORT" -j NOTRACK
  del raw OUTPUT -p tcp --sport "\$TUNNEL_PORT" -j NOTRACK
  del mangle OUTPUT -p tcp --sport "\$TUNNEL_PORT" --tcp-flags RST RST -j DROP
  del filter INPUT -p tcp --dport "\$TUNNEL_PORT" -j ACCEPT
  del nat OUTPUT -m owner --uid-owner "\$SERVICE_UID" -p tcp ! --sport "\$TUNNEL_PORT" ! -d 127.0.0.0/8 -j REDIRECT
  del nat OUTPUT -m owner --uid-owner "\$SERVICE_UID" -p udp ! -d 127.0.0.0/8 -j REDIRECT
  if [ "\$ROLE" = client ] && [ "\$MODE" = selected ]; then
    IFS=',' read -ra fs <<< "\$FORWARDS"
    for f in "\${fs[@]}"; do
      port="\${f%/*}"; proto="\${f##*/}"
      valid_port "\$port" || continue
      del filter INPUT -p "\$proto" --dport "\$port" -j ACCEPT
    done
  fi
  remove_all
  if [ -r "\$STATE" ]; then
    . "\$STATE"
    [ -z "\${ALL_RPF:-}" ] || sysctl -qw net.ipv4.conf.all.rp_filter="\$ALL_RPF" || true
    [ -z "\${DEFAULT_RPF:-}" ] || sysctl -qw net.ipv4.conf.default.rp_filter="\$DEFAULT_RPF" || true
    rm -f "\$STATE"
  fi
}
verify_rules(){
  if [ "\$ROLE" = server ]; then
    iptables -w 5 -t raw -C PREROUTING -p tcp --dport "\$TUNNEL_PORT" -j NOTRACK >/dev/null
  fi
  if [ "\$ROLE" = server ] && [ "\$MODE" = forward ]; then
    iptables -w 5 -t nat -C OUTPUT -m owner --uid-owner "\$SERVICE_UID" -p tcp ! --sport "\$TUNNEL_PORT" ! -d 127.0.0.0/8 -j REDIRECT >/dev/null
  elif [ "\$MODE" = all ]; then
    iptables -w 5 -t mangle -C PREROUTING -m addrtype --dst-type LOCAL -j "\$CHAIN" >/dev/null
    iptables -w 5 -t mangle -C "\$CHAIN" -p tcp --sport "\$TUNNEL_PORT" -j RETURN >/dev/null
    ip rule show | grep -Eq "(lookup|table) \$TABLE( |\$)"
    ip route show table "\$TABLE" | grep -q '^local '
  fi
}
case "\${1:-}" in start) stop_rules; start_rules ;; stop) stop_rules ;; verify) verify_rules ;; *) exit 2 ;; esac
EOF
    chmod 0750 "$script"
    cat > "$SERVICE_DIR/$unit" <<EOF
[Unit]
Description=Paqet-X firewall rules ($name)
After=local-fs.target
Before=paqet-x-$name.service

[Service]
Type=oneshot
ExecStart=$script start
ExecStop=$script stop
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
}

create_tproxy_assets() {
    local name="$1" user="$2" socks_port="$3" tproxy_port="$4"
    local cfg svc workers
    cfg=$(tproxy_config_file "$name")
    svc=$(tproxy_service_name "$name")
    workers=$(nproc 2>/dev/null || echo 1)
    [[ "$workers" =~ ^[0-9]+$ ]] || workers=1
    ((workers > 4)) && workers=4
    ((workers < 1)) && workers=1
    cat > "$cfg" <<EOF
main:
  workers: $workers
socks5:
  port: $socks_port
  address: 127.0.0.1
  udp: 'udp'
  mark: 1080
tcp:
  port: $tproxy_port
  address: 127.0.0.1
udp:
  port: $tproxy_port
  address: 127.0.0.1
misc:
  connect-timeout: 15000
  tcp-read-write-timeout: 900000
  udp-read-write-timeout: 120000
  log-file: stderr
  log-level: warn
  limit-nofile: 1048576
EOF
    chmod 0640 "$cfg"; chown root:"$user" "$cfg"
    cat > "$SERVICE_DIR/$svc" <<EOF
[Unit]
Description=Paqet-X all-port transparent helper ($name)
After=paqet-x-$name.service $(firewall_service_name "$name")
Requires=paqet-x-$name.service $(firewall_service_name "$name")
StartLimitIntervalSec=120
StartLimitBurst=8

[Service]
Type=simple
User=$user
Group=$user
ExecStart=$HEV_BIN $cfg
Restart=on-failure
RestartSec=5
LimitNOFILE=1048576
NoNewPrivileges=yes
PrivateTmp=yes
ProtectHome=yes
ProtectSystem=full
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF
}

remove_tunnel_assets() {
    local name="$1" fw tps main
    fw=$(firewall_service_name "$name"); tps=$(tproxy_service_name "$name"); main="paqet-x-$name.service"
    systemctl stop "$tps" "$main" "$fw" >/dev/null 2>&1 || true
    systemctl disable "$tps" "$main" "$fw" >/dev/null 2>&1 || true
    [ -x "$(firewall_script_file "$name")" ] && "$(firewall_script_file "$name")" stop >/dev/null 2>&1 || true
    remove_auto_restart "${main%.service}" 2>/dev/null || true
    rm -f "$SERVICE_DIR/$main" "$SERVICE_DIR/$fw" "$SERVICE_DIR/$tps"           "$(firewall_script_file "$name")" "$(tproxy_config_file "$name")" "$(metadata_file "$name")"
    remove_service_user "$name"
    systemctl daemon-reload >/dev/null 2>&1 || true
}

# ═══════════════════════════════════════
#  Systemd Service
# ═══════════════════════════════════════
create_systemd_service() {
    local name="$1" user="$2"
    local fw; fw=$(firewall_service_name "$name")
    cat > "$SERVICE_DIR/paqet-x-${name}.service" <<EOF
[Unit]
Description=Paqet-X Tunnel (${name})
After=network-online.target $fw
Wants=network-online.target
Requires=$fw
StartLimitIntervalSec=120
StartLimitBurst=8

[Service]
Type=simple
User=$user
Group=$user
ExecStart=$BIN_DIR/$BIN_NAME run -c $CONFIG_DIR/${name}.yaml
Restart=on-failure
RestartSec=5
LimitNOFILE=1048576
NoNewPrivileges=yes
PrivateTmp=yes
ProtectHome=yes
ProtectSystem=full
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_RAW CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_RAW CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
}

# ═══════════════════════════════════════
#  Install Dependencies
# ═══════════════════════════════════════
install_dependencies() {
    show_banner
    print_step "Installing dependencies...\n"
    local os=$(detect_os)
    case $os in
        ubuntu|debian)
            export DEBIAN_FRONTEND=noninteractive
            apt-get update -qq
            apt-get install -y curl wget ca-certificates jq libpcap-dev iptables lsof iproute2 cron dnsutils kmod openssl >/dev/null ;;
        centos|rhel|fedora|rocky|almalinux)
            local pm=yum; command -v dnf >/dev/null 2>&1 && pm=dnf
            "$pm" install -y curl wget ca-certificates jq libpcap-devel iptables lsof iproute cronie bind-utils kmod openssl >/dev/null ;;
        *) print_warning "Unknown OS. Required: curl jq libpcap iptables iproute2 kmod openssl" ;;
    esac
    mkdir -p "$CONFIG_DIR" "$STATE_DIR" "$LIBEXEC_DIR"
    print_success "Dependencies installed"
    pause
}

# ═══════════════════════════════════════
#  Install Paqet-X Core
# ═══════════════════════════════════════
install_paqet() {
    show_banner
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  Install / Update Paqet-X Core                                ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
    local arch current tmp actual
    arch=$(detect_arch) || return 1
    [ "$arch" = amd64 ] || { print_error "The supplied Paqet-Xv2 binary supports amd64 only"; pause; return 1; }
    current="Not installed"
    [ -f "$BIN_DIR/$BIN_NAME" ] && current="Installed"
    echo -e " Arch:      ${CYAN}$arch${NC}"
    echo -e " Installed: ${CYAN}$current${NC}\n"
    tmp=$(mktemp)
    local script_dir local_binary
    script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)
    local_binary="$script_dir/Paqet-Xv2"
    if [ -f "$local_binary" ]; then
        print_info "Using the bundled Paqet-Xv2 binary..."
        cp "$local_binary" "$tmp"
    else
        print_info "Downloading the pinned Paqet-Xv2 binary from $PROJECT_REPOSITORY ..."
        curl -fsSL --retry 3 --connect-timeout 10 "$CORE_BINARY_URL" -o "$tmp" || { rm -f "$tmp"; print_error "Download failed"; pause; return 1; }
    fi
    actual=$(sha256sum "$tmp" | awk '{print $1}')
    if [ "$actual" != "$CORE_BINARY_SHA256" ]; then
        rm -f "$tmp"
        print_error "Core SHA-256 mismatch; installation stopped"
        pause
        return 1
    fi
    install -m 0755 "$tmp" "$BIN_DIR/$BIN_NAME"
    rm -f "$tmp"
    print_success "Verified and installed to $BIN_DIR/$BIN_NAME"
    pause
}

# ═══════════════════════════════════════
#  Configure Server (Kharej)
# ═══════════════════════════════════════
configure_server() {
    while true; do
        show_banner
        echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║ Configure as Server (Kharej)                                 ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
        get_network_info
        [ -n "$NETWORK_INTERFACE" ] && [ -n "$LOCAL_IP" ] && [ -n "$GATEWAY_MAC" ] || { print_error "Could not detect interface, local IPv4, or gateway MAC"; pause; return 1; }
        local public_ip=$(get_public_ip)
        echo -e "${YELLOW}Detected Network Information${NC}"
        printf " Interface: %s\n Local IP: %s\n Public IP: %s\n Gateway MAC: %s\n\n" "${NETWORK_INTERFACE:-N/A}" "${LOCAL_IP:-N/A}" "$public_ip" "${GATEWAY_MAC:-N/A}"

        read -p "[1/7] Service Name [server]: " config_name
        config_name=$(clean_config_name "${config_name:-server}")
        [ -n "$config_name" ] || { print_error "Invalid service name"; continue; }
        if [ -f "$CONFIG_DIR/${config_name}.yaml" ]; then
            read -p "Config exists. Stop and replace it? (y/N): " ow
            [[ "$ow" =~ ^[Yy]$ ]] || continue
            remove_tunnel_assets "$config_name"
        fi
        read -p "[2/7] Listen Port [$DEFAULT_LISTEN_PORT]: " port; port="${port:-$DEFAULT_LISTEN_PORT}"
        validate_port "$port" || { print_error "Invalid port"; continue; }
        [ "$port" != 80 ] && [ "$port" != 443 ] || { print_error "Do not use 80 or 443 as the tunnel port"; continue; }
        local secret_key=$(generate_secret_key)
        read -p "[3/7] Secret Key [auto: $secret_key]: " custom_key
        [ -z "$custom_key" ] || secret_key="$custom_key"
        validate_secret_key "$secret_key" || { print_error "Key must be 8-128 characters using letters, numbers, and ._:@+=/- only"; continue; }
        echo "KCP modes: [0] normal [1] fast [2] fast2 [3] fast3"
        read -p "[4/7] Mode [1]: " mode_choice; mode_choice="${mode_choice:-1}"
        case $mode_choice in 0) mode_name=normal;; 2) mode_name=fast2;; 3) mode_name=fast3;; *) mode_name=fast;; esac
        read -p "[5/7] Connections [${DEFAULT_CONNECTIONS}]: " conn; conn="${conn:-$DEFAULT_CONNECTIONS}"
        [[ "$conn" =~ ^[0-9]+$ ]] && ((conn>=1 && conn<=32)) || { print_error "Connections must be 1-32"; continue; }
        read -p "[6/7] MTU [$DEFAULT_MTU]: " mtu; mtu="${mtu:-$DEFAULT_MTU}"
        [[ "$mtu" =~ ^[0-9]+$ ]] && ((mtu>=576 && mtu<=1500)) || { print_error "MTU must be 576-1500"; continue; }
        echo "Encryption: [1] aes-128-gcm [2] aes-128 [3] aes [4] salsa20 [5] aes-256 [6] none [7] null"
        read -p "[7/7] Encryption [1]: " enc_choice; enc_choice="${enc_choice:-1}"
        IFS=':' read -r block _ <<< "${ENCRYPTION_OPTIONS[$enc_choice]}"; block="${block:-aes-128-gcm}"
        echo "Server profile: [1] Port forwarding (selected/all ports) [2] Normal SOCKS5 internet proxy"
        read -p "Choose [1-2] [1]: " profile_choice; profile_choice="${profile_choice:-1}"
        case "$profile_choice" in 2) server_profile=socks5;; *) server_profile=forward;; esac

        [ -x "$BIN_DIR/$BIN_NAME" ] || { install_paqet || continue; }
        mkdir -p "$CONFIG_DIR" "$STATE_DIR" "$LIBEXEC_DIR"
        local user; user=$(ensure_service_user "$config_name") || { print_error "Could not create service user"; continue; }
        cat > "$CONFIG_DIR/${config_name}.yaml" <<EOF
role: "server"
log:
  level: "info"
listen:
  addr: ":$port"
network:
  interface: "$NETWORK_INTERFACE"
  ipv4:
    addr: "$LOCAL_IP:$port"
    router_mac: "$GATEWAY_MAC"
  tcp:
    local_flag: ["PA"]
transport:
  protocol: "kcp"
  conn: $conn
  kcp:
    key: "$secret_key"
    mode: "$mode_name"
    block: "$block"
    mtu: $mtu
    smuxkalive: 5
    smuxktimeout: 30
    smuxbuf: 4194304
    streambuf: 2097152
EOF
        chmod 0640 "$CONFIG_DIR/${config_name}.yaml"; chown root:"$user" "$CONFIG_DIR/${config_name}.yaml"
        create_firewall_assets "$config_name" server "$port" "$server_profile" tcp "" "" "" "" "$user" ""
        create_systemd_service "$config_name" "$user"
        write_meta "$config_name" "ROLE=server" "TUNNEL_PORT=$port" "USER=$user" "MODE=$server_profile"
        local svc="paqet-x-${config_name}.service" fw; fw=$(firewall_service_name "$config_name")
        systemctl daemon-reload
        systemctl enable --now "$fw" "$svc" >/dev/null 2>&1
        if systemctl is-active --quiet "$svc" && "$(firewall_script_file "$config_name")" verify; then
            print_success "Server started successfully"
            echo -e "\n${YELLOW}Give these values to the Iran installer:${NC}"
            echo "Server IP: $public_ip"
            echo "Tunnel Port: $port"
            echo "Secret Key: $secret_key"
            echo "KCP: $mode_name | Encryption: $block | Connections: $conn | MTU: $mtu"
            echo "Server profile: $server_profile"
            setup_auto_restart "${svc%.service}" "$DEFAULT_RESTART_INTERVAL"
        else
            print_error "Service failed to start"
            systemctl status "$svc" --no-pager -l
        fi
        pause
        return 0
    done
}

# ═══════════════════════════════════════
#  Configure Client (Iran)
# ═══════════════════════════════════════
configure_client() {
    while true; do
        show_banner
        echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║ Configure as Client (Iran)                                   ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
        get_network_info
        [ -n "$NETWORK_INTERFACE" ] && [ -n "$LOCAL_IP" ] && [ -n "$GATEWAY_MAC" ] || { print_error "Could not detect interface, local IPv4, or gateway MAC"; pause; return 1; }
        local public_ip=$(get_public_ip)
        read -p "[1/8] Service Name [client]: " config_name
        config_name=$(clean_config_name "${config_name:-client}")
        [ -n "$config_name" ] || { print_error "Invalid service name"; continue; }
        if [ -f "$CONFIG_DIR/${config_name}.yaml" ]; then
            read -p "Config exists. Overwrite? (y/N): " ow
            [[ "$ow" =~ ^[Yy]$ ]] || continue
            remove_tunnel_assets "$config_name"
        fi
        read -p "[2/8] Kharej Server IPv4: " server_ip
        validate_ip "$server_ip" || { print_error "Invalid IPv4 address"; continue; }
        read -p "[3/8] Tunnel Port [$DEFAULT_LISTEN_PORT]: " server_port; server_port="${server_port:-$DEFAULT_LISTEN_PORT}"
        validate_port "$server_port" || { print_error "Invalid port"; continue; }
        read -p "[4/8] Secret Key: " secret_key
        validate_secret_key "$secret_key" || { print_error "Key must be 8-128 characters using letters, numbers, and ._:@+=/- only"; continue; }
        echo "KCP modes: [0] normal [1] fast [2] fast2 [3] fast3"
        read -p "[5/8] Mode [1]: " mode_choice; mode_choice="${mode_choice:-1}"
        case $mode_choice in 0) mode_name=normal;; 2) mode_name=fast2;; 3) mode_name=fast3;; *) mode_name=fast;; esac
        read -p "[6/8] Connections [$DEFAULT_CONNECTIONS]: " conn; conn="${conn:-$DEFAULT_CONNECTIONS}"
        [[ "$conn" =~ ^[0-9]+$ ]] && ((conn>=1 && conn<=32)) || { print_error "Connections must be 1-32"; continue; }
        read -p "[7/8] MTU [$DEFAULT_MTU]: " mtu; mtu="${mtu:-$DEFAULT_MTU}"
        [[ "$mtu" =~ ^[0-9]+$ ]] && ((mtu>=576 && mtu<=1500)) || { print_error "MTU must be 576-1500"; continue; }
        echo "Encryption: [1] aes-128-gcm [2] aes-128 [3] aes [4] salsa20 [5] aes-256 [6] none [7] null"
        read -p "[8/8] Encryption [1]: " enc_choice; enc_choice="${enc_choice:-1}"
        IFS=':' read -r block _ <<< "${ENCRYPTION_OPTIONS[$enc_choice]}"; block="${block:-aes-128-gcm}"

        echo -e "\n${CYAN}Traffic Type${NC}"
        echo " [1] Port Forwarding (requires a server installed with forwarding profile)"
        echo " [2] SOCKS5 Proxy (requires a server installed with SOCKS5 profile)"
        read -p "Choose [1-2] [1]: " traffic_type; traffic_type="${traffic_type:-1}"
        local forward_entries=() socks5_entries=() display_ports="" forward_mode="selected" firewall_forwards=""
        local protocol_mode="" exclusions="" ssh_ports="" tproxy_port="" socks_port=""

        if [ "$traffic_type" = 1 ]; then
            echo -e "\n${CYAN}Forward Mode${NC}"
            echo " [1] Selected ports (native Paqet forward, same as source project)"
            echo " [2] All ports except tunnel, SSH, and user exclusions"
            read -p "Choose [1-2] [1]: " fm; fm="${fm:-1}"
            if [ "$fm" = 2 ]; then
                forward_mode="all"
                echo "Protocol: [1] TCP [2] UDP [3] TCP+UDP"
                read -p "Choose [1-3] [3]: " pc; pc="${pc:-3}"
                case "$pc" in 1) protocol_mode=tcp;; 2) protocol_mode=udp;; *) protocol_mode=both;; esac
                ssh_ports=$(detect_ssh_ports)
                read -p "Additional excluded ports/ranges (e.g. 25,3306,5000-5010; Enter=none): " exclusions
                exclusions=$(normalize_csv "$exclusions")
                exclusions=$(append_csv_unique "$exclusions" "$server_port")
                IFS=',' read -ra ssh_items <<< "$ssh_ports"
                for p in "${ssh_items[@]}"; do exclusions=$(append_csv_unique "$exclusions" "$p"); done
                print_info "Automatic exclusions: tunnel $server_port; SSH $ssh_ports"
                print_info "Final exclusions: $exclusions"
                read -p "Continue with all-port mode? (y/N): " ok
                [[ "$ok" =~ ^[Yy]$ ]] || continue
                iptables -j TPROXY -h >/dev/null 2>&1 || { print_error "This kernel/iptables build does not support TPROXY"; pause; continue; }
                command -v ip >/dev/null 2>&1 || { print_error "iproute2 is required for policy routing"; pause; continue; }
                local existing_all
                existing_all=$(existing_allport_service "$config_name" || true)
                [ -z "$existing_all" ] || { print_error "All-port mode is already owned by service: $existing_all"; pause; continue; }
                install_hev || { pause; continue; }
                socks_port=$(find_free_port "$DEFAULT_INTERNAL_SOCKS_PORT") || { print_error "No free internal SOCKS port"; continue; }
                tproxy_port=$(find_free_port "$DEFAULT_TPROXY_PORT") || { print_error "No free TPROXY port"; continue; }
                [ "$tproxy_port" != "$socks_port" ] || tproxy_port=$(find_free_port "$((tproxy_port+1))")
                socks5_entries+=("  - listen: \"127.0.0.1:$socks_port\"")
                display_ports="ALL $protocol_mode except $exclusions"
            else
                read -p "Forward Ports (comma separated) [$DEFAULT_V2RAY_PORTS]: " forward_ports
                forward_ports=$(clean_port_list "${forward_ports:-$DEFAULT_V2RAY_PORTS}")
                [ -n "$forward_ports" ] || { print_error "No valid ports"; continue; }
                IFS=',' read -ra PORTS <<< "$forward_ports"
                for p in "${PORTS[@]}"; do
                    [ "$p" != "$server_port" ] || { print_error "Port $p is the tunnel port"; forward_entries=(); break; }
                    echo -n "Port $p protocol [1=tcp,2=udp,3=both] [1]: "
                    read -r proto_choice; proto_choice="${proto_choice:-1}"
                    case $proto_choice in
                        2) forward_entries+=("  - listen: \"0.0.0.0:$p\"\n    target: \"127.0.0.1:$p\"\n    protocol: \"udp\""); display_ports+=" $p(UDP)"; firewall_forwards="${firewall_forwards:+$firewall_forwards,}$p/udp" ;;
                        3) forward_entries+=("  - listen: \"0.0.0.0:$p\"\n    target: \"127.0.0.1:$p\"\n    protocol: \"tcp\""); forward_entries+=("  - listen: \"0.0.0.0:$p\"\n    target: \"127.0.0.1:$p\"\n    protocol: \"udp\""); display_ports+=" $p(TCP+UDP)"; firewall_forwards="${firewall_forwards:+$firewall_forwards,}$p/tcp,$p/udp" ;;
                        *) forward_entries+=("  - listen: \"0.0.0.0:$p\"\n    target: \"127.0.0.1:$p\"\n    protocol: \"tcp\""); display_ports+=" $p(TCP)"; firewall_forwards="${firewall_forwards:+$firewall_forwards,}$p/tcp" ;;
                    esac
                done
                [ ${#forward_entries[@]} -gt 0 ] || continue
            fi
        else
            forward_mode="socks5"
            read -p "SOCKS5 Port [$DEFAULT_SOCKS5_PORT]: " socks_port; socks_port="${socks_port:-$DEFAULT_SOCKS5_PORT}"
            validate_port "$socks_port" || { print_error "Invalid SOCKS5 port"; continue; }
            read -p "SOCKS5 Username (Enter=none): " socks_user
            if [ -n "$socks_user" ]; then
                read -s -p "SOCKS5 Password: " socks_pass; echo
                socks5_entries+=("  - listen: \"127.0.0.1:$socks_port\"\n    username: \"$socks_user\"\n    password: \"$socks_pass\"")
            else
                socks5_entries+=("  - listen: \"127.0.0.1:$socks_port\"")
            fi
            display_ports="SOCKS5:$socks_port"
        fi

        [ -x "$BIN_DIR/$BIN_NAME" ] || { install_paqet || continue; }
        mkdir -p "$CONFIG_DIR" "$STATE_DIR" "$LIBEXEC_DIR"
        local user; user=$(ensure_service_user "$config_name") || continue
        {
            echo 'role: "client"'
            echo 'log:'; echo '  level: "info"'
            if [ ${#forward_entries[@]} -gt 0 ]; then echo 'forward:'; for e in "${forward_entries[@]}"; do echo -e "$e"; done; fi
            if [ ${#socks5_entries[@]} -gt 0 ]; then echo 'socks5:'; for e in "${socks5_entries[@]}"; do echo -e "$e"; done; fi
            cat <<EOF
network:
  interface: "$NETWORK_INTERFACE"
  ipv4:
    addr: "$LOCAL_IP:0"
    router_mac: "$GATEWAY_MAC"
  tcp:
    local_flag: ["PA"]
    remote_flag: ["PA"]
server:
  addr: "$server_ip:$server_port"
transport:
  protocol: "kcp"
  conn: $conn
  kcp:
    key: "$secret_key"
    mode: "$mode_name"
    block: "$block"
    mtu: $mtu
    smuxkalive: 5
    smuxktimeout: 30
    smuxbuf: 4194304
    streambuf: 2097152
EOF
        } > "$CONFIG_DIR/${config_name}.yaml"
        chmod 0640 "$CONFIG_DIR/${config_name}.yaml"; chown root:"$user" "$CONFIG_DIR/${config_name}.yaml"
        create_firewall_assets "$config_name" client "$server_port" "$forward_mode" "${protocol_mode:-tcp}" "$exclusions" "$ssh_ports" "$tproxy_port" "$socks_port" "$user" "$firewall_forwards"
        create_systemd_service "$config_name" "$user"
        if [ "$forward_mode" = all ]; then create_tproxy_assets "$config_name" "$user" "$socks_port" "$tproxy_port"; fi
        write_meta "$config_name" "ROLE=client" "TUNNEL_PORT=$server_port" "USER=$user" "MODE=$forward_mode" "PROTOCOL=$protocol_mode" "EXCLUSIONS=$exclusions" "SSH_PORTS=$ssh_ports"
        local svc="paqet-x-${config_name}.service" fw tp
        fw=$(firewall_service_name "$config_name"); tp=$(tproxy_service_name "$config_name")
        systemctl daemon-reload
        systemctl enable --now "$fw" "$svc" >/dev/null 2>&1
        [ "$forward_mode" != all ] || systemctl enable --now "$tp" >/dev/null 2>&1
        if systemctl is-active --quiet "$svc" && { [ "$forward_mode" != all ] || systemctl is-active --quiet "$tp"; } && "$(firewall_script_file "$config_name")" verify; then
            print_success "Client started successfully"
            echo "This server: $public_ip"
            echo "Remote server: $server_ip:$server_port"
            echo "Traffic: ${display_ports# }"
            setup_auto_restart "${svc%.service}" "$DEFAULT_RESTART_INTERVAL"
        else
            print_error "Client or helper failed to start"
            systemctl status "$svc" "$tp" --no-pager -l 2>/dev/null || true
        fi
        pause
        return 0
    done
}

# ═══════════════════════════════════════
#  Auto-Restart (Cronjob)
# ═══════════════════════════════════════
readonly DEFAULT_RESTART_INTERVAL=60

setup_auto_restart() {
    local service_name="$1"
    local interval="${2:-$DEFAULT_RESTART_INTERVAL}"
    [[ "$interval" =~ ^[0-9]+$ ]] && ((interval >= 1 && interval <= 1440)) || {
        print_error "Auto-restart interval must be 1-1440 minutes"
        return 1
    }
    remove_auto_restart "$service_name" 2>/dev/null
    local schedule
    if ((interval < 60)); then
        schedule="*/$interval * * * *"
    elif ((interval % 60 == 0)); then
        local hours=$((interval / 60))
        if ((hours < 24)); then schedule="0 */$hours * * *"; else schedule="0 0 * * *"; fi
    else
        print_error "Intervals above 59 minutes must be a whole number of hours"
        return 1
    fi
    (crontab -l 2>/dev/null; echo "# PAQETX_AUTORESTART $service_name interval=$interval"; echo "$schedule systemctl restart $service_name") | crontab - 2>/dev/null
    print_success "Auto-restart enabled: every $interval minutes"
}

remove_auto_restart() {
    local service_name="$1"
    local tmp
    tmp=$(mktemp)
    crontab -l 2>/dev/null | grep -v "systemctl restart $service_name" | grep -v "PAQETX_AUTORESTART $service_name " > "$tmp" || true
    crontab "$tmp" 2>/dev/null || true
    rm -f "$tmp"
}

manage_auto_restart() {
    local service_name="$1"
    local display_name="$2"

    show_banner
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ⏰ Auto-Restart Management                                       ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}\n"

    local svc_name="${service_name%.service}"
    local has_cron="No"
    local current_interval="-"
    local cron_line
    cron_line=$(crontab -l 2>/dev/null | grep "PAQETX_AUTORESTART $svc_name " | tail -1)
    if [ -n "$cron_line" ]; then
        has_cron="Yes"
        current_interval=$(sed -n 's/.*interval=\([0-9][0-9]*\).*/\1/p' <<< "$cron_line")
    fi

    echo -e "${CYAN}Service:${NC} $display_name"
    echo -e "${CYAN}Auto-Restart:${NC} $has_cron"
    [ "$has_cron" = "Yes" ] && echo -e "${CYAN}Interval:${NC} Every ${current_interval} minutes"

    echo -e "\n${CYAN}Options${NC}"
    echo " 1. ✅ Enable Auto-Restart"
    echo " 2. ❌ Disable Auto-Restart"
    echo " 0. ↩️  Back"
    echo ""
    read -p "Choose [0-2]: " choice

    case $choice in
        0) return ;;
        1)
            echo -e "\n${CYAN}Restart Intervals${NC}"
            echo -e "────────────────────────────────────────────────────────────────"
            echo " [1] 30 minutes"
            echo " [2] 1 hour (default)"
            echo " [3] 2 hours"
            echo " [4] 4 hours"
            echo " [5] 6 hours"
            echo " [6] 12 hours"
            echo " [7] Custom interval"
            echo ""
            read -p "Choose [1-7] (default 2): " int_choice
            int_choice="${int_choice:-2}"

            local mins=60
            case $int_choice in
                1) mins=30 ;;
                2) mins=60 ;;
                3) mins=120 ;;
                4) mins=240 ;;
                5) mins=360 ;;
                6) mins=720 ;;
                7) echo -en "${YELLOW}Enter interval in minutes: ${NC}"
                   read -r mins
                   [[ ! "$mins" =~ ^[0-9]+$ ]] || [ "$mins" -lt 1 ] && { print_error "Invalid"; pause; return; }
                   ;;
                *) mins=60 ;;
            esac
            setup_auto_restart "$svc_name" "$mins"
            ;;
        2)
            remove_auto_restart "$svc_name"
            print_success "Auto-restart disabled"
            ;;
    esac
    pause
}

# ═══════════════════════════════════════
#  Service Management
# ═══════════════════════════════════════
get_service_details() {
    local service_name="$1"
    local config_name="${service_name#paqet-x-}"
    local config_file="$CONFIG_DIR/$config_name.yaml"

    local type="unknown" mode="fast" mtu="-" conn="-" cron="No"

    if [ -f "$config_file" ]; then
        local role_line=$(grep "^role:" "$config_file" 2>/dev/null | head -1)
        [ -n "$role_line" ] && type=$(echo "$role_line" | awk '{print $2}' | tr -d '"')
        local mode_line=$(grep "mode:" "$config_file" 2>/dev/null | head -1)
        [ -n "$mode_line" ] && mode=$(echo "$mode_line" | awk '{print $2}' | tr -d '"')
        grep -q "mtu:" "$config_file" 2>/dev/null && mtu=$(grep "mtu:" "$config_file" | head -1 | awk '{print $2}' | tr -d '"')
        grep -q "conn:" "$config_file" 2>/dev/null && conn=$(grep "conn:" "$config_file" | head -1 | awk '{print $2}' | tr -d '"')
    fi

    crontab -l 2>/dev/null | grep -q "systemctl restart $service_name" && cron="Yes"
    echo "$type $mode $mtu $conn $cron"
}

manage_services() {
    while true; do
        show_banner
        echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║  Paqet-X Service Management                                                                       ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════════════════════════╝${NC}\n"

        local services=()
        mapfile -t services < <(systemctl list-unit-files --type=service --no-legend --no-pager 2>/dev/null |
                              grep -E '^paqet-x-.*\.service' | grep -Ev -- '-(firewall|tproxy)\.service$' | awk '{print $1}' || true)

        if [ ${#services[@]} -eq 0 ]; then
            echo -e "${YELLOW}No Paqet-X services found.${NC}\n"
            pause
            return
        fi

        echo -e "${CYAN}┌─────┬──────────────────────────┬─────────────┬───────────┬────────────┬──────────┬────────┬────────────────┐${NC}"
        echo -e "${CYAN}│  #  │ Service Name             │ Status      │ Type      │ Mode       │ MTU      │ Conn   │ Auto-Restart   │${NC}"
        echo -e "${CYAN}├─────┼──────────────────────────┼─────────────┼───────────┼────────────┼──────────┼────────┼────────────────┤${NC}"

        local i=1
        for svc in "${services[@]}"; do
            local service_name="${svc%.service}"
            local display_name="${service_name#paqet-x-}"
            local status
            status=$(systemctl is-active "$svc" 2>/dev/null) || true
            status="${status:-unknown}"
            status=$(echo "$status" | head -1 | awk '{print $1}')
            local details=$(get_service_details "$service_name")
            local type=$(echo "$details" | awk '{print $1}')
            local mode=$(echo "$details" | awk '{print $2}')
            local mtu=$(echo "$details" | awk '{print $3}')
            local conn=$(echo "$details" | awk '{print $4}')
            local cron=$(echo "$details" | awk '{print $5}')

            local status_color=""
            case "$status" in
                active) status_color="${GREEN}" ;;
                failed) status_color="${RED}" ;;
                inactive) status_color="${YELLOW}" ;;
                activating) status_color="${YELLOW}"; status="restarting" ;;
                deactivating) status_color="${YELLOW}"; status="stopping" ;;
                *) status_color="${WHITE}" ;;
            esac

            local mode_color=""
            case "$mode" in
                normal) mode_color="${CYAN}" ;;
                fast) mode_color="${GREEN}" ;;
                fast2) mode_color="${YELLOW}" ;;
                fast3) mode_color="${RED}" ;;
                *) mode_color="${WHITE}" ;;
            esac

            printf "${CYAN}│${NC} %3d ${CYAN}│${NC} %-24s ${CYAN}│${NC} ${status_color}%-11s${NC} ${CYAN}│${NC} %-9s ${CYAN}│${NC} ${mode_color}%-10s${NC} ${CYAN}│${NC} %-8s ${CYAN}│${NC} %-6s ${CYAN}│${NC} %-14s ${CYAN}│${NC}\n" \
                "$i" "${display_name:0:24}" "$status" "${type:-unknown}" "${mode:-fast}" "${mtu:--}" "${conn:--}" "${cron:-No}"
            ((i++))
        done

        echo -e "${CYAN}└─────┴──────────────────────────┴─────────────┴───────────┴────────────┴──────────┴────────┴────────────────┘${NC}\n"

        echo -e "${YELLOW}Options:${NC}"
        echo -e " 1-${#services[@]}. Select a service to manage"
        echo -e " 0. ↩️  Back to Main Menu"
        echo ""

        read -p "Enter choice: " choice

        [ "$choice" = "0" ] && return

        if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#services[@]} )); then
            print_error "Invalid selection"
            sleep 1.5
            continue
        fi

        local selected_service="${services[$((choice-1))]}"
        local sel_name="${selected_service%.service}"
        local sel_display="${sel_name#paqet-x-}"
        manage_single_service "$selected_service" "$sel_display"
    done
}

tunnel_mode() { read_meta "$1" MODE 2>/dev/null || echo selected; }
start_tunnel() {
    local name="$1" fw tp mode
    fw=$(firewall_service_name "$name"); tp=$(tproxy_service_name "$name"); mode=$(tunnel_mode "$name")
    systemctl start "$fw" "paqet-x-$name.service"
    [ "$mode" != all ] || systemctl start "$tp"
}
stop_tunnel() {
    local name="$1" fw tp mode
    fw=$(firewall_service_name "$name"); tp=$(tproxy_service_name "$name"); mode=$(tunnel_mode "$name")
    [ "$mode" != all ] || systemctl stop "$tp" >/dev/null 2>&1 || true
    systemctl stop "paqet-x-$name.service" "$fw" >/dev/null 2>&1 || true
}
restart_tunnel() { local name="$1"; stop_tunnel "$name"; start_tunnel "$name"; }

manage_single_service() {
    local selected_service="$1"
    local display_name="$2"

    while true; do
        show_banner

        local short_name="${display_name:0:32}"
        [ ${#display_name} -gt 32 ] && short_name="${short_name}..."

        echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
        printf "${GREEN}║ Managing: %-50s ║${NC}\n" "$short_name"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}\n"

        local status
        status=$(systemctl is-active "$selected_service" 2>/dev/null) || true
        status="${status:-unknown}"
        status=$(echo "$status" | head -1 | awk '{print $1}')

        echo -en "${CYAN}Status:${NC} "
        case "$status" in
            active)       echo -e "${GREEN}🟢 Active${NC}" ;;
            failed)       echo -e "${RED}🔴 Failed${NC}" ;;
            inactive)     echo -e "${YELLOW}🟡 Inactive${NC}" ;;
            activating)   echo -e "${YELLOW}🟡 Restarting${NC}" ;;
            deactivating) echo -e "${YELLOW}🟡 Stopping${NC}" ;;
            *)            echo -e "${WHITE}⚪ $status${NC}" ;;
        esac

        local details=$(get_service_details "${selected_service%.service}")
        local type=$(echo "$details" | awk '{print $1}')
        local mode=$(echo "$details" | awk '{print $2}')
        local mtu=$(echo "$details" | awk '{print $3}')
        local conn=$(echo "$details" | awk '{print $4}')
        local cron=$(echo "$details" | awk '{print $5}')

        echo -e "\n${CYAN}Details:${NC}"
        echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
        printf "${CYAN}│${NC} %-16s ${CYAN}:${NC} %-25s ${CYAN}│${NC}\n" "Type" "${type:-unknown}"
        printf "${CYAN}│${NC} %-16s ${CYAN}:${NC} %-25s ${CYAN}│${NC}\n" "KCP Mode" "${mode:-fast}"
        printf "${CYAN}│${NC} %-16s ${CYAN}:${NC} %-25s ${CYAN}│${NC}\n" "MTU" "${mtu:--}"
        printf "${CYAN}│${NC} %-16s ${CYAN}:${NC} %-25s ${CYAN}│${NC}\n" "Connections" "${conn:--}"
        printf "${CYAN}│${NC} %-16s ${CYAN}:${NC} %-25s ${CYAN}│${NC}\n" "Auto-Restart" "${cron:-No}"
        echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"

        echo -e "\n${CYAN}Actions${NC}"
        echo " 1. 🟢 Start"
        echo " 2. 🔴 Stop"
        echo " 3. 🔄 Restart"
        echo " 4. 📊 Show Status"
        echo " 5. 📝 View Recent Logs"
        echo " 6. 📺 Live Logs"
        echo " 7. 📄 View Configuration"
        echo " 8. ✏️  Edit Configuration"
        echo " 9. ⏰ Auto-Restart"
        echo " 10. 🗑️  Delete Service"
        echo " 0. ↩️  Back"
        echo ""

        read -p "Choose action [0-10]: " action

        case "$action" in
            0) return ;;
            1) start_tunnel "$display_name" >/dev/null 2>&1
               print_success "Service started"
               sleep 1.5 ;;
            2) stop_tunnel "$display_name" >/dev/null 2>&1
               print_success "Service stopped"
               sleep 1.5 ;;
            3) restart_tunnel "$display_name" >/dev/null 2>&1
               print_success "Service restarted"
               sleep 1.5 ;;
            4) echo ""
               systemctl status "$selected_service" --no-pager -l
               pause ;;
            5) echo ""
               journalctl -u "$selected_service" -n 30 --no-pager
               pause ;;
            6) echo -e "\n${CYAN}Ctrl+C to return to menu...${NC}\n"
               journalctl -u "$selected_service" -f --no-pager &
               local log_pid=$!
               trap "kill $log_pid 2>/dev/null; wait $log_pid 2>/dev/null" INT
               wait $log_pid 2>/dev/null
               trap - INT
               echo ""
               ;;
            7) local cfg="$CONFIG_DIR/$display_name.yaml"
               if [ -f "$cfg" ]; then
                   echo -e "\n${CYAN}$cfg${NC}\n"
                   cat "$cfg"
               else
                   print_error "Config file not found"
               fi
               pause ;;
            8) local cfg="$CONFIG_DIR/$display_name.yaml"
               if [ -f "$cfg" ]; then
                   echo -e "\n${YELLOW}Editing: $cfg${NC}"
                   local editor="nano"
                   command -v nano &>/dev/null || editor="vi"
                   $editor "$cfg"
                   read -p "Restart service to apply changes? (y/N): " restart_choice
                   if [[ "$restart_choice" =~ ^[Yy]$ ]]; then
                       restart_tunnel "$display_name" >/dev/null 2>&1
                       if systemctl is-active --quiet "$selected_service"; then
                           print_success "Service restarted successfully"
                       else
                           print_error "Service failed to start"
                           systemctl status "$selected_service" --no-pager -l
                       fi
                   fi
               else
                   print_error "Config file not found"
               fi
               pause ;;
            9) manage_auto_restart "$selected_service" "$display_name" ;;
            10) read -p "Delete this service? (y/N): " confirm
               if [[ "$confirm" =~ ^[Yy]$ ]]; then
                   # Safety check: only delete services with paqet- prefix
                   local svc_file="$SERVICE_DIR/$selected_service"
                   if [[ "$selected_service" != paqet-x-* ]]; then
                       print_error "Safety check failed: '$selected_service' is not a paqet-x- service"
                       pause; continue
                   fi
                   systemctl stop "$selected_service" 2>/dev/null || true
                   systemctl disable "$selected_service" 2>/dev/null || true
                   rm -f "$svc_file" 2>/dev/null || true
                   remove_tunnel_assets "$display_name"
                   [ -n "$display_name" ] && rm -f "$CONFIG_DIR/$display_name.yaml" 2>/dev/null || true
                   systemctl daemon-reload 2>/dev/null || true
                   remove_auto_restart "${selected_service%.service}"
                   print_success "Service removed"
                   pause
                   return
               fi ;;
            *) print_error "Invalid choice"
               sleep 1 ;;
        esac
    done
}

# ═══════════════════════════════════════
#  Status
# ═══════════════════════════════════════
show_status() {
    show_banner
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  Paqet-X Status                                               ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}\n"

    local ver="Not installed"
    [ -f "$BIN_DIR/$BIN_NAME" ] && ver=$("$BIN_DIR/$BIN_NAME" version 2>/dev/null | head -1)

    echo -e "┌──────────────────────────────────────────────────────────────┐"
    printf "│ %-18s : %-39s │\n" "OS" "$(detect_os)"
    printf "│ %-18s : %-39s │\n" "Architecture" "$(detect_arch 2>/dev/null)"
    printf "│ %-18s : %-39s │\n" "Public IP" "$(get_public_ip)"
    printf "│ %-18s : %-39s │\n" "Paqet-X" "$ver"
    echo -e "└──────────────────────────────────────────────────────────────┘"

    local services=()
    mapfile -t services < <(systemctl list-unit-files --type=service --no-legend --no-pager 2>/dev/null |
                          grep -E '^paqet-x-.*\.service' | grep -Ev -- '-(firewall|tproxy)\.service$' | awk '{print $1}')
    if [ ${#services[@]} -gt 0 ]; then
        echo -e "\n${CYAN}Tunnels:${NC}\n"
        for svc in "${services[@]}"; do
            local st=$(systemctl is-active "$svc" 2>/dev/null)
            local icon; case "$st" in active) icon="${GREEN}🟢${NC}" ;; failed) icon="${RED}🔴${NC}" ;; *) icon="${YELLOW}🟡${NC}" ;; esac
            echo -e " $icon ${svc%.service} ($st)"
        done
    else
        echo -e "\n${YELLOW}No tunnels configured${NC}"
    fi
    pause
}

# ═══════════════════════════════════════
#  Uninstall
# ═══════════════════════════════════════
uninstall_paqet() {
    show_banner
    echo -e "${RED}Uninstall Paqet-X${NC}\n"
    echo " 1. Remove binary only"
    echo " 2. Remove everything (binary + configs + services + firewall rules)"
    echo " 0. Cancel"
    read -p "Choice [0-2]: " choice
    case $choice in
        0) return ;;
        1) rm -f "$BIN_DIR/$BIN_NAME"; print_success "Binary removed" ;;
        2)
            print_warning "This removes every Paqet-X tunnel created by this installer."
            read -p "Type YES to confirm: " confirm
            if [ "$confirm" = YES ]; then
                local svc name
                while read -r svc; do
                    [ -n "$svc" ] || continue
                    name="${svc#paqet-x-}"; name="${name%.service}"
                    stop_tunnel "$name" || true
                    systemctl disable "$svc" >/dev/null 2>&1 || true
                    remove_tunnel_assets "$name"
                    rm -f "$SERVICE_DIR/$svc" "$CONFIG_DIR/$name.yaml"
                    remove_auto_restart "${svc%.service}"
                done < <(systemctl list-unit-files --type=service --no-legend --no-pager 2>/dev/null | awk '/^paqet-x-.*\.service/ && $1 !~ /-(firewall|tproxy)\.service$/ {print $1}')
                systemctl daemon-reload
                rm -f "$BIN_DIR/$BIN_NAME" "$HEV_BIN"
                rm -rf "$INSTALL_DIR" "$CONFIG_DIR" "$LIBEXEC_DIR"
                print_success "Paqet-X completely removed"
            fi ;;
    esac
    pause
}

# ═══════════════════════════════════════
#  Check Dependencies
# ═══════════════════════════════════════
check_dependencies() {
    local missing_deps=()
    local os=$(detect_os)

    local common_deps=("curl" "wget" "iptables" "lsof" "jq" "sha256sum")

    case $os in
        ubuntu|debian)
            common_deps+=("libpcap-dev" "iproute2" "cron" "dig") ;;
        centos|rhel|fedora|rocky|almalinux)
            common_deps+=("libpcap-devel" "iproute" "cronie" "bind-utils") ;;
    esac

    for dep in "${common_deps[@]}"; do
        if ! command -v "$dep" &>/dev/null &&
           ! dpkg -l | grep -q "$dep" 2>/dev/null &&
           ! rpm -q "$dep" &>/dev/null 2>&1; then
            missing_deps+=("$dep")
        fi
    done

    if [ ${#missing_deps[@]} -eq 0 ]; then
        return 0
    else
        echo "${missing_deps[@]}"
        return 1
    fi
}

# ═══════════════════════════════════════
#  Main Menu
# ═══════════════════════════════════════
main_menu() {
    while true; do
        show_banner
        echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║  Main Menu                                                     ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}\n"

        # Show Paqet-X binary status
        if [ -f "$BIN_DIR/$BIN_NAME" ]; then
            echo -e "${GREEN}✅ Paqet-X is installed${NC}"
            local core_version
            core_version=$("$BIN_DIR/$BIN_NAME" version 2>/dev/null | grep "^Version:" | head -1 | cut -d':' -f2 | xargs)
            [ -z "$core_version" ] && core_version=$("$BIN_DIR/$BIN_NAME" version 2>/dev/null | head -1)
            if [ -n "$core_version" ]; then
                echo -e "   ${GREEN}└─ Version: ${CYAN}$core_version${NC}"
            fi
        else
            echo -e "${YELLOW}⚠️  Paqet-X not installed${NC}"
        fi

        # Show dependency status
        local missing_deps
        missing_deps=$(check_dependencies)
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ Dependencies are installed${NC}"
        else
            echo -e "${YELLOW}⚠️  Missing dependencies: $missing_deps${NC}"
        fi

        # Show active tunnels count
        local tunnel_count
        tunnel_count=$(systemctl list-unit-files --type=service --no-legend --no-pager 2>/dev/null |
                      awk '$1 ~ /^paqet-x-.*\.service$/ && $1 !~ /-(firewall|tproxy)\.service$/ {n++} END{print n+0}')
        local active_count
        active_count=$(systemctl list-units --type=service --state=active --no-legend --no-pager 2>/dev/null |
                      awk '$1 ~ /^paqet-x-.*\.service$/ && $1 !~ /-(firewall|tproxy)\.service$/ {n++} END{print n+0}')
        echo -e "${CYAN}📊 Tunnels: ${WHITE}$active_count${NC} active / ${WHITE}$tunnel_count${NC} total"

        echo -e "\n${CYAN}1.${NC} 📦 Install Dependencies"
        echo -e "${CYAN}2.${NC} 📥 Install / Update Paqet-X Core"
        echo -e "${CYAN}3.${NC} 🌍 Configure Server (Kharej)"
        echo -e "${CYAN}4.${NC} 🇮🇷 Configure Client (Iran)"
        echo -e "${CYAN}5.${NC} ⚙️  Service Management"
        echo -e "${CYAN}6.${NC} 📊 Status"
        echo -e "${CYAN}7.${NC} 🗑️  Uninstall"
        echo -e "${CYAN}0.${NC} 🚪 Exit"
        echo ""

        read -p "Choose [0-7]: " choice
        case $choice in
            0) echo -e "\n${GREEN}Goodbye! 👋${NC}\n"; exit 0 ;;
            1) install_dependencies ;;
            2) install_paqet ;;
            3) configure_server ;;
            4) configure_client ;;
            5) manage_services ;;
            6) show_status ;;
            7) uninstall_paqet ;;
            *) print_error "Invalid"; sleep 1 ;;
        esac
    done
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    check_root
    main_menu
fi
