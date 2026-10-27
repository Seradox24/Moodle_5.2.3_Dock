#!/bin/sh
# Restore only into a fresh isolated Compose project, never over existing data.
set -eu
umask 0077
cd "$(dirname "$0")/.."
. ./scripts/lib/compose-env.sh
[ "$#" -eq 4 ] && [ "$1" = --env-file ] && [ "$3" = --backup ] || {
    echo 'Usage: restore.sh --env-file ABSOLUTE_PROFILE --backup ABSOLUTE_BACKUP' >&2
    exit 1
}
env_file=$2
backup=$(CDPATH= cd -- "$4" && pwd -P)
compose_init "$env_file"
sh scripts/preflight.sh --env-file "$COMPOSE_ENV_FILE" --fresh-install
(cd "$backup" && sha256sum -c SHA256SUMS)
cmp "$backup/release.env" "$COMPOSE_RELEASE_FILE" || {
    echo 'Restore requires the matching release metadata and images.' >&2
    exit 1
}
compose create app
app_cid=$(compose ps -a -q app)
app_image=$(docker inspect --format '{{.Image}}' "$app_cid")
for volume in moodledata moodle-code; do
    actual=$(compose config --format json | python3 -c 'import json,sys; print(json.load(sys.stdin)["volumes"][sys.argv[1]]["name"])' "$volume")
    docker run --rm -i --network none --read-only --mount "type=volume,source=$actual,target=/restore" --entrypoint tar "$app_image" -C /restore -xzf - < "$backup/$volume.tar.gz"
done
compose up -d --wait db redis
compose exec -T db sh -c 'pg_restore --exit-on-error --no-owner -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < "$backup/database.dump"
compose up -d --wait app web cron
compose exec -T --user www-data app php /usr/local/bin/check-runtime.php
echo 'Restore finished. Verify login, files and scheduled tasks before any proxy cutover.'
