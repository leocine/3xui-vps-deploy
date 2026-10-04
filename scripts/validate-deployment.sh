#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <panel-domain> [deploy-state-file] [client-email]" >&2
}

domain="${1:-}"
state_file="${2:-/root/3xui-deploy-state.env}"
client_email="${3:-admin}"
if [[ -z "$domain" ]]; then
  usage
  exit 64
fi

# Overrides allow read-only checks of non-default installs and local fixtures.
install_env="${XUI_INSTALL_ENV:-/etc/x-ui/install-result.env}"
db="${XUI_DB_PATH:-/etc/x-ui/x-ui.db}"
config_file="${XUI_CONFIG_PATH:-/usr/local/x-ui/bin/config.json}"
panel_binary="${XUI_PANEL_BINARY:-/usr/local/x-ui/x-ui}"
xray_binary="${XUI_XRAY_BINARY:-}"

test -f "$install_env"
test -f "$db"

# shellcheck disable=SC1090
. "$install_env"

if [[ -f "$state_file" ]]; then
  # shellcheck disable=SC1090
  . "$state_file"
fi

echo "xui_active=$(systemctl is-active x-ui)"
echo "panel_version=$("$panel_binary" -v 2>/dev/null || echo unavailable)"
if [[ -z "$xray_binary" ]]; then
  case "$(uname -m)" in
    x86_64) xray_arch=amd64 ;;
    aarch64|arm64) xray_arch=arm64 ;;
    armv7l) xray_arch=arm32-v7a ;;
    armv6l) xray_arch=arm32-v6a ;;
    i386|i686) xray_arch=386 ;;
    *) xray_arch=unknown ;;
  esac
  xray_binary="${config_file%/*}/xray-linux-${xray_arch}"
fi
echo "xray_version=$("$xray_binary" version 2>/dev/null | head -1 || echo unavailable)"
echo "panel_credentials_present=$(test -n "${XUI_USERNAME:-}" && test -n "${XUI_PASSWORD:-}" && echo yes || echo no)"
echo "panel_port=${XUI_PANEL_PORT:-}"
echo "panel_path_present=$(test -n "${XUI_WEB_BASE_PATH:-}" && echo yes || echo no)"
echo "panel_https_local=$(curl -k -sS -o /dev/null -w '%{http_code}' "https://127.0.0.1:${XUI_PANEL_PORT}/${XUI_WEB_BASE_PATH}/")"
echo "cert_exists=$(test -f "/etc/letsencrypt/live/${domain}/fullchain.pem" && test -f "/etc/letsencrypt/live/${domain}/privkey.pem" && echo yes || echo no)"

echo "clash_settings_begin"
sqlite3 -readonly "$db" "SELECT key,value FROM settings WHERE key IN ('subClashEnable','subClashPath') ORDER BY key;"
echo "clash_settings_end"
echo "panel_time_location=$(sqlite3 -readonly "$db" "SELECT value FROM settings WHERE key='timeLocation';" 2>/dev/null || echo unavailable)"

echo "client_lifecycle_begin"
sql_quote="'"
sql_double_quote="''"
client_email_sql="${client_email//$sql_quote/$sql_double_quote}"
if lifecycle=$(sqlite3 -readonly -header "$db" "SELECT email,enable,total_gb AS quota_bytes,expiry_time AS expiry_ms,traffic_reset,traffic_reset_day,reset AS renewal_days,reset_day AS renewal_month_day,reset_weekday AS renewal_weekday,reset_max AS renewal_max FROM clients WHERE email='${client_email_sql}';" 2>/dev/null); then
  printf '%s\n' "${lifecycle:-not_found}"
else
  echo unavailable
fi
echo "client_lifecycle_end"

echo "inbounds_begin"
sqlite3 -readonly "$db" "SELECT remark,protocol,port,enable FROM inbounds ORDER BY port;"
echo "inbounds_end"

echo "vless_pq_fields_begin"
echo "vless_mlkem_db_count=$(sqlite3 -readonly "$db" "SELECT COUNT(*) FROM inbounds WHERE protocol='vless' AND json_extract(settings,'$.decryption') LIKE 'mlkem768x25519plus.%';" 2>/dev/null || echo unavailable)"
echo "vless_mldsa_db_count=$(sqlite3 -readonly "$db" "SELECT COUNT(*) FROM inbounds WHERE protocol='vless' AND COALESCE(json_extract(stream_settings,'$.realitySettings.mldsa65Seed'),'')!='';" 2>/dev/null || echo unavailable)"
echo "vless_mlkem_runtime=$(grep -Eq '"decryption"[[:space:]]*:[[:space:]]*"mlkem768x25519plus\.' "$config_file" 2>/dev/null && echo present || echo absent)"
echo "vless_mldsa_runtime=$(grep -Eq '"mldsa65Seed"[[:space:]]*:[[:space:]]*"[^\"]+"' "$config_file" 2>/dev/null && echo present || echo absent)"
echo "vless_pq_fields_end"

echo "tables_begin"
sqlite3 -readonly "$db" ".tables" | tr ' ' '\n' | grep -E '^(clients|client_inbounds)$' || true
echo "tables_end"

echo "admin_client_count=$(sqlite3 -readonly "$db" "SELECT COUNT(*) FROM clients WHERE email='admin';" 2>/dev/null || echo unavailable)"
echo "admin_assoc_count=$(sqlite3 -readonly "$db" "SELECT COUNT(*) FROM client_inbounds ci JOIN clients c ON c.id=ci.client_id WHERE c.email='admin';" 2>/dev/null || echo unavailable)"
echo "admin_sub_ids=$(sqlite3 -readonly "$db" "SELECT COUNT(DISTINCT c.sub_id) FROM client_inbounds ci JOIN clients c ON c.id=ci.client_id WHERE c.email='admin';" 2>/dev/null || echo unavailable)"

tcp_ports=("${XUI_PANEL_PORT}")
for maybe_port in "${TCP443_PORT:-}" "${TCP_RANDOM_PORT:-}" "${XHTTP_PORT:-}" "${PQ_TCP_PORT:-}"; do
  [[ -n "$maybe_port" ]] && tcp_ports+=("$maybe_port")
done

if ((${#tcp_ports[@]} > 0)); then
  tcp_regex="$(IFS='|'; echo "${tcp_ports[*]}")"
  echo "listeners_tcp_begin"
  ss -lntup | grep -E ":(${tcp_regex})\\b" || true
  echo "listeners_tcp_end"
fi

if [[ -n "${HY2_PORT:-}" ]]; then
  echo "listeners_udp_begin"
  ss -lunp | grep -E ":${HY2_PORT}\\b" || true
  echo "listeners_udp_end"
fi

echo "nft_runtime_begin"
nft list ruleset 2>/dev/null | grep -A5 -B2 'xui_hy2_nat' || true
echo "nft_runtime_end"
if [[ -n "${HY2_HOP_RANGE:-}" && -n "${HY2_PORT:-}" ]]; then
  echo "nft_persist=$(grep -q "udp dport ${HY2_HOP_RANGE} redirect to :${HY2_PORT}" /etc/nftables.conf 2>/dev/null && echo yes || echo no)"
fi
echo "nft_enabled=$(systemctl is-enabled nftables 2>/dev/null || true)"

echo "ipv6_disabled=$(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null || true)"
echo "ipv4_prefer=$(grep -E '^precedence ::ffff:0:0/96' /etc/gai.conf 2>/dev/null || true)"
echo "bbr=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || true)"
echo "qdisc=$(sysctl -n net.core.default_qdisc 2>/dev/null || true)"


echo "config_ports_begin"
for p in "${TCP443_PORT:-}" "${TCP_RANDOM_PORT:-}" "${XHTTP_PORT:-}" "${PQ_TCP_PORT:-}" "${HY2_PORT:-}"; do
  [[ -n "$p" ]] || continue
  grep -Eq "\"port\"[[:space:]]*:[[:space:]]*${p}([[:space:]]*[,}]|[[:space:]]*$)" "$config_file" 2>/dev/null && echo "config_port_${p}=present" || echo "config_port_${p}=missing"
done
echo "config_ports_end"
