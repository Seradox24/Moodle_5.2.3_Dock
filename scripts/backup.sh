#!/bin/sh
set -eu
umask 0077

cd "$(dirname "$0")/.."
. ./scripts/lib/compose-env.sh

env_file=.env
dest_arg=
while [ "$#" -gt 0 ]; do
    case "$1" in
        --env-file)
            [ "$#" -ge 2 ] || { echo "--env-file requires a path." >&2; exit 1; }
            env_file=$2
            shift 2
            ;;
        *)
            [ -z "$dest_arg" ] || { echo "Unexpected argument: $1" >&2; exit 1; }
            dest_arg=$1
            shift
            ;;
    esac
done
compose_init "$env_file"

timestamp="$(date +%Y%m%d_%H%M%S)"
dest="${dest_arg:-backups/${timestamp}}"
[ ! -e "$dest" ] || { echo "Backup destination already exists: $dest" >&2; exit 1; }

running="$(compose ps --status running --services)"
for service in db app web cron; do
    printf '%s\n' "$running" | grep -qx "$service" || {
        echo "Service $service must be running before this backup." >&2
        exit 1
    }
done

mkdir -p "$dest"
compose images > "$dest/images.txt"
: > "$dest/image-digests.txt"
for service in app web cron db redis; do
    cid=$(compose ps -a -q "$service")
    [ -n "$cid" ] || { echo "Missing deployed service: $service" >&2; exit 1; }
    image_id=$(docker inspect --format '{{.Image}}' "$cid")
    image=$image_id
    repo_digests="$(docker image inspect --format '{{json .RepoDigests}}' "$image")" || exit 1
    labels="$(docker image inspect --format '{{json .Config.Labels}}' "$image")" || exit 1
    printf '%s %s %s %s %s\n' "$service" "$cid" "$image_id" "$repo_digests" "$labels" >> "$dest/image-digests.txt"
    if [ "$service" = app ]; then app_cid=$cid; app_image=$image_id; fi
done
# Selected repository metadata; image-digests.txt records the actual deployment.
cp "$COMPOSE_RELEASE_FILE" "$dest/release.env"

# Freeze writers so DB, files and installed plugin versions match this backup.
resume=true
cleanup() {
    result=$?
    trap - 0
    if [ "$resume" = true ]; then
        compose start app cron web || result=1
    fi
    exit "$result"
}
trap cleanup 0
trap 'exit 130' INT
trap 'exit 143' TERM
echo "Pausing web, cron and app for a consistent backup..."
compose stop --timeout 120 web cron app

echo "Backing up PostgreSQL..."
compose exec -T db sh -lc \
    'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' \
    > "${dest}/database.dump"

echo "Backing up moodledata..."
docker run --rm --network none --read-only --volumes-from "$app_cid:ro" --user www-data --entrypoint tar "$app_image" -C /var/moodledata -czf - . \
    > "${dest}/moodledata.tar.gz"

echo "Backing up code, plugins and themes..."
docker run --rm --network none --read-only --volumes-from "$app_cid:ro" --user www-data --entrypoint tar "$app_image" -C /var/www/moodle/public -czf - . \
    > "${dest}/moodle-code.tar.gz"

docker run --rm --network none --read-only --volumes-from "$app_cid:ro" --entrypoint cat "$app_image" /var/www/moodle/public/.deployment-ref \
    > "${dest}/deployment-ref.txt"

(cd "$dest" && sha256sum database.dump moodledata.tar.gz moodle-code.tar.gz images.txt image-digests.txt deployment-ref.txt release.env > SHA256SUMS)

compose start app cron web
resume=false
trap - 0

echo "Backup created at ${dest}"
