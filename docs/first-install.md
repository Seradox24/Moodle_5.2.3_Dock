# Fresh installation

This repository is for a NEW Moodle 5.2.3 installation.

It does not assume an existing Moodle database or existing `moodledata`.

## Prepare

Linux:

```bash
cp -n .env.example .env
chmod 600 .env
```

Windows:

```powershell
if (-not (Test-Path .env)) { Copy-Item .env.example .env }
```

Use the prepared private `.env` if available. Otherwise set real values for:

```text
POSTGRES_PASSWORD
MOODLE_ADMIN_PASSWORD
MOODLE_ADMIN_EMAIL
MOODLE_SITE_FULLNAME
MOODLE_SITE_SHORTNAME
```

## Validate

```bash
sh ./scripts/preflight.sh
```

## Install

```bash
sh ./scripts/install.sh
```

The installation process:

1. builds the Moodle images;
2. starts PostgreSQL and Redis;
3. seeds the shared `moodle-code` volume and starts PHP-FPM;
4. runs Moodle `admin/cli/install_database.php`;
5. starts Nginx and cron.

The database installer is intentionally explicit. Container startup alone does
not silently initialize or overwrite the Moodle database.

The installer also runs preflight automatically. Missing site names or admin
email stop installation before any build or database creation. `--config-only`
on preflight checks the environment without checking the daemon or port.

## Access

There is no domain or TLS yet. The stack is reached directly by IP:

```text
http://<server-ip>:18080
```

For that, `.env` must contain:

```text
MOODLE_HTTP_BIND=0.0.0.0
MOODLE_WWWROOT=http://<server-ip>:18080
MOODLE_REVERSEPROXY=true
MOODLE_SSLPROXY=false
```

`MOODLE_REVERSEPROXY=true` is required because the published host port
(`MOODLE_HTTP_PORT`) differs from the internal container port `80`. Without it
Moodle reports a `wwwroot mismatch` and redirects in a loop.

The production `.env` can bind `MOODLE_HTTP_BIND` to the server's LAN IP rather
than all interfaces. That address must exist on the Ubuntu host.

For a local Windows test on the same machine, use:

```text
MOODLE_WWWROOT=http://localhost:18080
```

## Host Nginx (later)

When a domain and TLS are added, switch to:

```text
MOODLE_HTTP_BIND=127.0.0.1
MOODLE_WWWROOT=https://<domain>
MOODLE_REVERSEPROXY=true
MOODLE_SSLPROXY=true
```

and proxy from the host Nginx to `http://127.0.0.1:18080`, preserving the
original host and HTTPS scheme headers.
