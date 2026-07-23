#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <panel-domain>" >&2
}

domain="${1:-}"
if [[ -z "$domain" ]]; then
  usage
  exit 64
fi

db="/etc/x-ui/x-ui.db"
install_env="/etc/x-ui/install-result.env"
cert="/etc/letsencrypt/live/${domain}/fullchain.pem"
key="/etc/letsencrypt/live/${domain}/privkey.pem"

test -f "$db"
test -f "$install_env"

if [[ ! -f "$cert" || ! -f "$key" ]]; then
  certbot certonly \
    --standalone \
    -d "$domain" \
    --agree-tos \
    --register-unsafely-without-email \
    --non-interactive \
    --keep-until-expiring
fi

test -f "$cert"
test -f "$key"

backup="/etc/x-ui/x-ui.db.bak.panel-https.$(date +%Y%m%d%H%M%S)"
cp "$db" "$backup"

sqlite3 "$db" <<SQL
DELETE FROM settings WHERE key IN ('webCertFile','webKeyFile','subClashEnable','subClashPath');
INSERT INTO settings(key,value) VALUES('webCertFile','$cert');
INSERT INTO settings(key,value) VALUES('webKeyFile','$key');
INSERT INTO settings(key,value) VALUES('subClashEnable','true');
INSERT INTO settings(key,value) VALUES('subClashPath','/clash/');
SQL

systemctl restart x-ui
sleep 3
systemctl is-active --quiet x-ui

# shellcheck disable=SC1090
. "$install_env"
code="$(curl -k -sS -o /dev/null -w '%{http_code}' "https://127.0.0.1:${XUI_PANEL_PORT}/${XUI_WEB_BASE_PATH}/")"

echo "panel_https_configured"
echo "database_backup=$backup"
echo "webCertFile=$cert"
echo "webKeyFile=$key"
echo "subClashEnable=true"
echo "subClashPath=/clash/"
echo "local_https_http_code=$code"
