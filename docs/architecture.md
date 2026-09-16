# Moodle architecture

```text
Client / LAN
   |
http://<server-ip>:18080     (MOODLE_HTTP_BIND / MOODLE_HTTP_PORT)
   |
 web (Nginx)
   |
 FastCGI
   |
 app (PHP-FPM + Moodle 5.2.3)
   | \
   |  +--> Redis
   |
   +-----> PostgreSQL
   |
   +-----> moodledata

cron (same app image)
   +-----> PostgreSQL
   +-----> Redis when required
   +-----> moodledata

PostgreSQL --> postgres-data

code-init --> moodle-code (seeded once from the verified image)
app       --> moodle-code (read/write, installs plugins and themes)
web       --> moodle-code (read-only, serves the same static assets)
cron      --> moodle-code (read-only, executes the same plugin code)
```

## Isolation

Only the web service is published to the host. The bind address is
configurable via `MOODLE_HTTP_BIND`:

- `0.0.0.0` for direct access by server IP (current, no domain/TLS);
- a specific LAN IP to publish only on that interface (production `.env`);
- `127.0.0.1` when a host Nginx reverse proxy is placed in front later.

PostgreSQL, Redis and PHP-FPM are not published to the host.

The `data` network is marked internal.

`code-init` has no network access and exits after preparing or checking the code
volume. The application waits for its successful completion. An existing volume
is never overwritten automatically, and a different core reference requires an
explicit upgrade. See `plugins.md`.

PHP writes as UID/GID 33. Nginx workers belong to GID 33 to read plugin assets
created with restricted permissions; their volume mount is read-only.
The container root filesystems stay read-only, with writes limited to their
declared volumes and temporary filesystems.

`/healthz` checks Nginx locally without following Moodle redirects to the external
IP/port. The smoke test additionally checks the public login URL and Moodle's
database, extensions and plugin permissions. Each service rotates Docker logs.

Future Identity/SSO, Integration API, LRS and analytics components remain
separate deployable stacks.
