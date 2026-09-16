#!/bin/sh
set -eu
umask 0077

cd "$(dirname "$0")/.."

timestamp="$(date +%Y%m%d_%H%M%S)"
dest="${1:-backups/${timestamp}}"
[ ! -e "$dest" ] || { echo "Backup destination already exists: $dest" >&2; exit 1; }

running="$(docker compose ps --status running --services)"
for service in db app web cron; do
    printf '%s\n' "$running" | grep -qx "$service" || {
        echo "Service $service must be running before this backup." >&2
        exit 1
    }
done

mkdir -p "$dest"
docker compose images > "$dest/images.txt"

# Freeze writers so DB, files and installed plugin versions match this backup.
resume=true
cleanup() {
    result=$?
    trap - 0
    if [ "$resume" = true ]; then
        docker compose start app cron web || result=1
    fi
    exit "$result"
}
trap cleanup 0
trap 'exit 130' INT
trap 'exit 143' TERM
echo "Pausing web, cron and app for a consistent backup..."
docker compose stop --timeout 120 web cron app

echo "Backing up PostgreSQL..."
docker compose exec -T db sh -lc \
    'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' \
    > "${dest}/database.dump"

echo "Backing up moodledata..."
docker compose run --rm -T --no-deps --user www-data --entrypoint tar app -C /var/moodledata -czf - . \
    > "${dest}/moodledata.tar.gz"

echo "Backing up code, plugins and themes..."
docker compose run --rm -T --no-deps --user www-data --entrypoint tar app -C /var/www/moodle/public -czf - . \
    > "${dest}/moodle-code.tar.gz"

(cd "$dest" && sha256sum database.dump moodledata.tar.gz moodle-code.tar.gz images.txt > SHA256SUMS)

docker compose start app cron web
resume=false
trap - 0

echo "Backup created at ${dest}"
