# Changelog

## v1.0.17

- Added a non-blocking skill version check that runs before final delivery after every deployment, reset workflow, troubleshooting task, or dry-run.
- Added `references/version-check.md` with GitHub Release/Tag lookup, semver comparison, and upgrade reminder wording.
- Final deployment and traffic-reset reports now include skill version check status.

## v1.0.16

- HY2 port-hopping NAT rules must now be persisted with nftables or iptables-persistent; one-off runtime-only rules are explicitly forbidden.
- Validation now checks both the active NAT rule and its saved configuration, requires the persistence service to be enabled, and verifies the rule survives a safe reload.
- Added troubleshooting for port hopping that stops working after an unplanned VPS reboot.
- Added Sub-Store cache diagnosis for cases where a directly exported HY2 node works but transformed subscriptions still contain stale `mport` or address settings.

## v1.0.15

- New VPS deployments now collect the monthly traffic reset day and configure the 3x-ui traffic reset script by default.
- Deployment validation now checks the reset script, 600-permission config file, cron entry, and log path.
- README no longer lists every version's update details; detailed update notes live in GitHub Releases.

## v1.0.14

- Added a monthly 3x-ui traffic reset workflow for already-installed VPS instances.
- Added `scripts/3xui-reset-traffic.sh`, a VPS-side script template that reads an API Token from a 600-permission config file and resets inbound/client traffic through the current 3x-ui API.
- Added `references/reset-traffic.md` covering read-only preflight checks, reset date collection, API compatibility checks, cron setup, logging, testing, and safety limits.
- Updated README usage and directory structure for the new reset workflow.

## v1.0.13

- Added a README directory structure section explaining `SKILL.md`, `agents/`, `scripts/`, and `references/`.
- Bumped the documented stable version to `v1.0.13`.

## v1.0.12

- Added 3x-ui 3.5.0 automation notes from a real VMISS deployment.
- Documented Bearer API token usage for `/panel/api/*` and the CSRF failure mode when scripts POST `/login`.
- Clarified HTTPS setup for non-interactive installs, including `webCertFile` and `webKeyFile`.
- Expanded Xray Core pinning guidance for replacing `26.7.11` with `26.6.27` and parsing `xray x25519` output.
- Added 3x-ui 3.5.0 `clients` / `client_inbounds` guidance so the four inbounds share one logical `admin` client via a shared `subId`.
- Tightened HY2 guidance: keep unsupported tuning fields out of the 3x-ui/Xray wire shape and implement port hopping with nftables only.
- Clarified validation rules for panel HTTPS, `config.json` consistency, and cases where external client downloads fail.

## v1.0.11

- Stable release before the VMISS deployment notes.
