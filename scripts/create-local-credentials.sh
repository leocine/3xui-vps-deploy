#!/bin/bash
# Create a local-only credential template without accepting a password argument.
set -euo pipefail
set +x

usage() {
  echo "Usage: $0 <name> <ipv4> <ssh-port> <ssh-user> <system> <panel-domain>" >&2
  exit 64
}

[[ "$(uname -s)" == "Darwin" ]] || { echo "This helper currently requires macOS." >&2; exit 1; }
[[ $# -eq 6 ]] || usage

name="$1"
vps_ip="$2"
ssh_port="$3"
ssh_user="$4"
system_name="$5"
panel_domain="$6"

[[ "$name" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "Invalid credential name." >&2; exit 1; }
[[ "$vps_ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || { echo "Invalid IPv4 address." >&2; exit 1; }
[[ "$ssh_port" =~ ^[1-9][0-9]{0,4}$ ]] && (( ssh_port <= 65535 )) || { echo "Invalid SSH port." >&2; exit 1; }
[[ "$ssh_user" =~ ^[A-Za-z_][A-Za-z0-9_-]*$ ]] || { echo "Invalid SSH user." >&2; exit 1; }
[[ "$system_name" == "Debian" || "$system_name" == "Ubuntu" ]] || { echo "System must be Debian or Ubuntu." >&2; exit 1; }
[[ "$panel_domain" =~ ^[A-Za-z0-9.-]+$ ]] || { echo "Invalid panel domain." >&2; exit 1; }

credential_dir="$HOME/.config/3xui-vps-deploy"
credential_file="$credential_dir/$name.env"

if [[ -e "$credential_file" ]]; then
  echo "Credential file already exists: $credential_file" >&2
  exit 1
fi

umask 077
mkdir -p "$credential_dir"
chmod 700 "$credential_dir"

cat >"$credential_file" <<EOF
# Local-only VPS credentials. Do not commit, sync, or share this file.
VPS_IP=$vps_ip
SSH_PORT=$ssh_port
SSH_USER=$ssh_user
SSH_PASSWORD=
SYSTEM=$system_name
PANEL_DOMAIN=$panel_domain
EOF
chmod 600 "$credential_file"

open -e "$credential_file"
echo "Credential template opened: $credential_file"
