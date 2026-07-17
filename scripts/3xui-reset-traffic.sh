#!/usr/bin/env bash
set -euo pipefail
umask 077

CONFIG_FILE="${CONFIG_FILE:-/etc/3xui-reset-traffic.env}"
LOG_FILE="${LOG_FILE:-/var/log/3xui-reset-traffic.log}"

log() {
  printf '[%s] %s\n' "$(date '+%F %T')" "$*" | tee -a "$LOG_FILE"
}

fail() {
  log "ERROR: $*"
  exit 1
}

if [[ ! -r "$CONFIG_FILE" ]]; then
  fail "Config file not readable: $CONFIG_FILE"
fi

perm="$(stat -c '%a' "$CONFIG_FILE" 2>/dev/null || true)"
if [[ "$perm" != "600" ]]; then
  fail "Config file permission must be 600: $CONFIG_FILE"
fi

# shellcheck disable=SC1090
. "$CONFIG_FILE"

[[ -n "${XUI_BASE_URL:-}" ]] || fail "XUI_BASE_URL is empty"
[[ -n "${XUI_API_TOKEN:-}" ]] || fail "XUI_API_TOKEN is empty"

XUI_BASE_URL="${XUI_BASE_URL%/}"
CURL_INSECURE="${CURL_INSECURE:-false}"

curl_args=(--silent --show-error --fail --connect-timeout 10 --max-time 60)
if [[ "$CURL_INSECURE" == "true" ]]; then
  curl_args+=(-k)
fi

tmp_cfg="$(mktemp)"
tmp_body="$(mktemp)"
cleanup() {
  rm -f "$tmp_cfg" "$tmp_body"
}
trap cleanup EXIT
chmod 600 "$tmp_cfg" "$tmp_body"
printf 'header = "Authorization: Bearer %s"\n' "$XUI_API_TOKEN" >"$tmp_cfg"

api() {
  local method="$1"
  local path="$2"
  local url="$XUI_BASE_URL$path"

  if [[ "$method" == "GET" ]]; then
    curl "${curl_args[@]}" --config "$tmp_cfg" "$url"
  else
    curl "${curl_args[@]}" --config "$tmp_cfg" -X "$method" --data '' "$url"
  fi
}

json_success() {
  python3 -c '
import json, sys
data = json.load(sys.stdin)
success = data.get("success")
if success is False:
    print(data.get("msg") or data.get("message") or "API returned success=false", file=sys.stderr)
    sys.exit(1)
' || return 1
}

summarize_inbounds() {
  python3 -c '
import json, sys
data = json.load(sys.stdin)
items = data.get("obj", data if isinstance(data, list) else [])
if not isinstance(items, list):
    items = []
client_count = 0
ids = []
traffic_total = 0
for inbound in items:
    if not isinstance(inbound, dict):
        continue
    inbound_id = inbound.get("id")
    if inbound_id is not None:
        ids.append(str(inbound_id))
    traffic_total += int(inbound.get("up") or 0) + int(inbound.get("down") or 0)
    stats = inbound.get("clientStats")
    if isinstance(stats, list):
        client_count += len(stats)
        for stat in stats:
            if isinstance(stat, dict):
                traffic_total += int(stat.get("up") or 0) + int(stat.get("down") or 0)
        continue
    settings = inbound.get("settings")
    if isinstance(settings, str):
        try:
            settings = json.loads(settings)
        except Exception:
            settings = {}
    if isinstance(settings, dict):
        clients = settings.get("clients")
        if isinstance(clients, list):
            client_count += len(clients)
print(f"inbound_count={len(items)}")
print(f"client_count={client_count}")
print("inbound_ids=" + ",".join(ids))
print(f"traffic_total={traffic_total}")
'
}

log "Start 3x-ui traffic reset"

version="$(/usr/local/x-ui/x-ui version 2>/dev/null | head -1 || true)"
[[ -n "$version" ]] && log "3x-ui version: $version"

list_json="$(api GET "/panel/api/inbounds/list")" || fail "Failed to list inbounds"
printf '%s' "$list_json" | json_success || fail "List inbounds API failed"
summary="$(printf '%s' "$list_json" | summarize_inbounds)"

inbound_count="$(printf '%s\n' "$summary" | awk -F= '/^inbound_count=/{print $2}')"
client_count="$(printf '%s\n' "$summary" | awk -F= '/^client_count=/{print $2}')"
inbound_ids="$(printf '%s\n' "$summary" | awk -F= '/^inbound_ids=/{print $2}')"

log "Current inbound count: ${inbound_count:-0}"
log "Current client count: ${client_count:-0}"

reset_inbounds="$(api POST "/panel/api/inbounds/resetAllTraffics")" || fail "Failed to reset inbound traffic"
printf '%s' "$reset_inbounds" | json_success || fail "Reset inbound traffic API failed"
log "Reset inbound traffic success"

if reset_clients="$(api POST "/panel/api/clients/resetAllTraffics" 2>&1)" && printf '%s' "$reset_clients" | json_success; then
  log "Reset client traffic success"
else
  log "WARNING: /panel/api/clients/resetAllTraffics unavailable; falling back to inbound-scoped client reset"
  IFS=',' read -r -a ids <<<"${inbound_ids:-}"
  for inbound_id in "${ids[@]}"; do
    [[ -n "$inbound_id" ]] || continue
    reset_clients="$(api POST "/panel/api/inbounds/resetAllClientTraffics/$inbound_id")" || fail "Failed to reset client traffic for inbound $inbound_id"
    printf '%s' "$reset_clients" | json_success || fail "Reset client traffic API failed for inbound $inbound_id"
  done
  log "Reset client traffic success"
fi

after_json="$(api GET "/panel/api/inbounds/list")" || fail "Failed to verify inbounds"
printf '%s' "$after_json" | json_success || fail "Verify inbounds API failed"
after_summary="$(printf '%s' "$after_json" | summarize_inbounds)"
traffic_total="$(printf '%s\n' "$after_summary" | awk -F= '/^traffic_total=/{print $2}')"

if [[ "${traffic_total:-0}" == "0" ]]; then
  log "Traffic counters verified as zero"
else
  log "WARNING: API calls succeeded, but reported traffic total is ${traffic_total:-unknown}; check panel stats"
fi

log "Reset finished"
