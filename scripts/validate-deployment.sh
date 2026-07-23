#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <panel-domain> [deploy-state-file]" >&2
}

domain="${1:-}"
state_file="${2:-/root/3xui-deploy-state.env}"
if [[ -z "$domain" ]]; then
  usage
  exit 64
fi

install_env="/etc/x-ui/install-result.env"
db="/etc/x-ui/x-ui.db"

test -f "$install_env"
test -f "$db"

# shellcheck disable=SC1090
. "$install_env"

if [[ -f "$state_file" ]]; then
  # shellcheck disable=SC1090
  . "$state_file"
fi

echo "xui_active=$(systemctl is-active x-ui)"
echo "xray_version=$(/usr/local/x-ui/bin/xray-linux-amd64 version | head -1)"
echo "panel_username=${XUI_USERNAME:-}"
echo "panel_password=${XUI_PASSWORD:-}"
echo "panel_port=${XUI_PANEL_PORT:-}"
echo "panel_path=${XUI_WEB_BASE_PATH:-}"
echo "panel_url=https://${domain}:${XUI_PANEL_PORT}/${XUI_WEB_BASE_PATH}/"
echo "panel_https_local=$(curl -k -sS -o /dev/null -w '%{http_code}' "https://127.0.0.1:${XUI_PANEL_PORT}/${XUI_WEB_BASE_PATH}/")"
echo "cert_exists=$(test -f "/etc/letsencrypt/live/${domain}/fullchain.pem" && test -f "/etc/letsencrypt/live/${domain}/privkey.pem" && echo yes || echo no)"

echo "clash_settings_begin"
sqlite3 "$db" "SELECT key,value FROM settings WHERE key IN ('subClashEnable','subClashPath') ORDER BY key;"
echo "clash_settings_end"

echo "inbounds_begin"
sqlite3 "$db" "SELECT remark,protocol,port,enable FROM inbounds ORDER BY port;"
echo "inbounds_end"

echo "tables_begin"
sqlite3 "$db" ".tables" | tr ' ' '\n' | grep -E '^(clients|client_inbounds)$' || true
echo "tables_end"

echo "admin_client_count=$(sqlite3 "$db" "SELECT COUNT(*) FROM clients WHERE email='admin';" 2>/dev/null || echo unavailable)"
echo "admin_assoc_count=$(sqlite3 "$db" "SELECT COUNT(*) FROM client_inbounds ci JOIN clients c ON c.id=ci.client_id WHERE c.email='admin';" 2>/dev/null || echo unavailable)"
echo "admin_sub_ids=$(sqlite3 "$db" "SELECT COUNT(DISTINCT c.sub_id) FROM client_inbounds ci JOIN clients c ON c.id=ci.client_id WHERE c.email='admin';" 2>/dev/null || echo unavailable)"

tcp_ports=("${XUI_PANEL_PORT}")
for maybe_port in "${TCP443_PORT:-}" "${TCP_RANDOM_PORT:-}" "${XHTTP_PORT:-}"; do
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

echo "reset_script=$(test -x /usr/local/bin/3xui-reset-traffic.sh && echo yes || echo no)"
if [[ -f /etc/3xui-reset-traffic.env ]]; then
  echo "reset_env=$(stat -c '%a %U %G %n' /etc/3xui-reset-traffic.env)"
fi
echo "reset_cron=$(crontab -l 2>/dev/null | grep '/usr/local/bin/3xui-reset-traffic.sh' || true)"
if [[ -f /var/log/3xui-reset-traffic.log ]]; then
  echo "reset_log_last=$(tail -n 1 /var/log/3xui-reset-traffic.log)"
fi

echo "config_ports_begin"
for p in "${TCP443_PORT:-}" "${TCP_RANDOM_PORT:-}" "${XHTTP_PORT:-}" "${HY2_PORT:-}"; do
  [[ -n "$p" ]] || continue
  grep -q "\"port\": $p" /usr/local/x-ui/bin/config.json && echo "config_port_${p}=present" || echo "config_port_${p}=missing"
done
echo "config_ports_end"

if [[ -f "$state_file" ]]; then
  echo "state_begin"
  sed -n '1,40p' "$state_file"
  echo "state_end"
fi
