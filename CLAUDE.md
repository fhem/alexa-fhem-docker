# CLAUDE.md

Project memory for Claude Code. Keep entries short, dated and backed by a source.

## Target platforms and base image variants

The image is published for `linux/amd64`, `linux/arm/v7` and `linux/arm64`
(`.github/workflows/build.yml`, step "Build and push Docker image for all plattforms").
Any base image change must keep all three, `linux/arm/v7` is the one that drops out first.

### Platforms per base image (checked 2026-11-02)

Source: `https://hub.docker.com/v2/repositories/library/node/tags/<tag>` (`.images[].architecture/variant`)
and the OCI index of `gcr.io/distroless/<image>:latest`.

| Base image | Platforms | arm/v7 |
|---|---|---|
| `node:22.23.4-bookworm-slim` | amd64, arm/v7, arm64, ppc64le | yes |
| `node:22.23.4-trixie-slim` | amd64, arm64, ppc64le, s390x | **no** |
| `node:22.23.4-alpine3.24` | amd64, arm/v6, arm/v7, arm64, s390x | yes |
| `gcr.io/distroless/nodejs22-debian13` | amd64, arm64, arm/v7, s390x, ppc64le | yes |
| `node:24-bookworm-slim` | amd64, arm64, ppc64le | **no** |
| `node:24-trixie-slim` | amd64, arm64, ppc64le, s390x | **no** |
| `node:24-alpine3.24` | amd64, arm64, s390x | **no** |
| `gcr.io/distroless/nodejs24-debian13` | amd64, arm64, s390x, ppc64le | **no** |

Consequences:
- Debian Trixie is not possible without dropping `arm/v7`.
- No Node 24 base image offers `arm/v7`; moving to Node 24 means dropping `arm/v7`.
  alexa-fhem probably needs a patch for Node 24 as well (not verified).

### Decision (2026-11)

- **Version 6** (`dev`): `node:22.23.4-alpine3.24`, first pre-release `v6.0.0-beta.1` (PR #353).
- **Version 5** (`v5` branch): stays on `node:22.23.4-bookworm-slim`, last release `v5.2.2`.
- **Distroless rejected:** `/usr/bin` and `/usr/sbin` are empty (no shell). alexa-fhem spawns
  `ssh` and `ssh-keygen` at runtime (`lib/server.js`, `lib/user.js` in the npm package), and
  `src/entry.sh` / `src/health-check.sh` need bash, su, useradd, jq, curl.

### Alpine specifics (found while switching, see PR #353)

- BusyBox `su -` sets `PATH=/bin:/usr/bin`, `node` in `/usr/local/bin` is not found
  -> `util-linux-login` provides util-linux `su` (as on Debian).
- BusyBox `realpath -e` and `chown --no-dereference` are missing -> `coreutils`, `findutils`.
- `useradd` warns for uid 6062 (built-in `UID_MAX` 6000) -> `UID_MAX`/`GID_MAX 60000` in `/etc/login.defs`.
- Alpine OpenSSH rejects the Debian-only `gss-*` `KexAlgorithms`, so they were removed from `src/entry.sh`.
- `LANG`/`LC_ALL` never reach alexa-fhem under `su -` on Alpine (no `pam_env` locale);
  Node then defaults to `en-US`, so the log format is unchanged. The variables were removed.
