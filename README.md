# Moodle 5.2.3 Docker deployment

Official deployment repository (`lms-moodle`) for a **fresh / vanilla
Moodle 5.2.3 installation** on the server.

This is not a migration repository and does not depend on any previous Moodle
database, `moodledata`, or server installation.

## Moodle source

Release:

```text
v5.2.3
```

Pinned commit:

```text
344232c15336c71b80f9aca8359ce0e0a9f3d116
```

The Docker build fetches the official Git tag and verifies the commit before
continuing.

## Stack

```text
http://<server-ip>:18080
     |
    web                (optional host Nginx/TLS can be added later)
     |
    app
   / | \
 db redis moodledata

cron -> db / redis / moodledata
db   -> postgres-data
```

Access is by IP for now (no domain). `MOODLE_HTTP_BIND` controls the host
interface: `0.0.0.0` to reach it from the LAN by server IP, `127.0.0.1` when a
host reverse proxy is placed in front later.

Services:

- `web`: Nginx
- `app`: PHP 8.3 FPM + Moodle 5.2.3
- `cron`: same Moodle application image
- `db`: PostgreSQL 16
- `redis`: Redis
- `code-init`: one-shot initialisation of the shared code volume (exits with code 0).

## First installation

```bash
cp -n .env.example .env
chmod 600 .env
```

Use the prepared private `.env` for the server, or copy `.env.example` for a new
environment. Complete the real site identity and administrator email, plus all
`CHANGE_ME_...` values. Configuration reference: `docs/production-config.md`.

Linux:

```bash
sh ./scripts/preflight.sh
sh ./scripts/install.sh
```

Windows (Docker Desktop + PowerShell):

```powershell
if (-not (Test-Path .env)) { Copy-Item .env.example .env }
# edit .env and replace all CHANGE_ME_... values
.\scripts\windows\preflight.ps1
.\scripts\windows\install.ps1
```

If script execution is blocked by the execution policy:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\preflight.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\windows\install.ps1
```

The installation is performed explicitly with Moodle's CLI database installer.
Starting containers does **not** automatically reinstall or overwrite Moodle.

Both platforms run the same `compose.yaml`; only the helper scripts differ
(`scripts/*.sh` for Linux, `scripts/windows/*.ps1` for Windows).

## Normal operation

```bash
docker compose up -d
docker compose down
```

Recreating containers does not reinstall Moodle. The installed state lives in:

```text
postgres-data
moodledata
moodle-code
```

The verified image seeds `moodle-code` on the first start. Installed plugins and
themes then live in this persistent volume, shared by `app`, `cron` and `web`.
The real `config.php` and the bootstrap outside `public/` remain in the app image.

## Redis

Redis is deployed from the first version but Redis-backed Moodle sessions are
disabled initially:

```env
MOODLE_REDIS_SESSIONS=false
```

It can be enabled later after the base installation has been validated.

## Plugins

The first build is intentionally vanilla Moodle.

No third-party plugin is included initially. Installation from Moodle's admin
interface is enabled with `MOODLE_PLUGIN_INSTALL=true`, including theme ZIPs.
Only `app` writes to the shared code at runtime; `web` and `cron` mount it read-only.
See `docs/plugins.md` for permissions, installation and core update handling.

See:

```text
plugins/manifest.lock
```

## Future platform

Identity/SSO, Integration/API Layer, LRS, analytics, backend services and other
platform components remain independent deployable stacks.

Moodle will integrate with them later through explicit contracts instead of
embedding them in this Compose project.

## Documentation

- `docs/ubuntu-26-deploy.md`
- `docs/deploy-runbook.md`
- `docs/windows-test.md`
- `docs/production-config.md`
- `docs/plugins.md`
- `docs/architecture.md`
- `docs/first-install.md`
- `docs/operations.md`
- `docs/server-conventions.md`

## Multi-service server conventions

This stack is intentionally namespaced for a server that will also host other
platform services.

Defaults:

```text
COMPOSE_PROJECT_NAME=lms-moodle
IMAGE_NAMESPACE=lms
MOODLE_HTTP_BIND=0.0.0.0
MOODLE_HTTP_PORT=18080
```

The private production `.env` binds to the specific LAN IP of the server.

Images:

```text
lms/moodle-web:5.2.3
lms/moodle-app:5.2.3
```

No `container_name` values are used, and PostgreSQL/Redis/PHP-FPM are not
published to the host.

See `docs/server-conventions.md`.
