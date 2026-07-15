# Changelog

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
