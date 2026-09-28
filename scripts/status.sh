#!/bin/sh
# Reports the selected project status. Exit 0 only when the five long-running
# services are up.
set -eu

cd "$(dirname "$0")/.."
. ./scripts/lib/compose-env.sh

env_file=.env
while [ "$#" -gt 0 ]; do
    case "$1" in
        --env-file)
            [ "$#" -ge 2 ] || { echo "--env-file requires a path." >&2; exit 1; }
            env_file=$2
            shift 2
            ;;
        *) echo "Unknown argument: $1" >&2; exit 1 ;;
    esac
done

compose_init "$env_file"
compose ps

running="$(compose ps --status running --services)" || exit 1
missing=""
for service in db redis app web cron; do
    printf '%s\n' "$running" | grep -qx "$service" || missing="$missing $service"
done
if [ -n "$missing" ]; then
    echo "ERROR: services not running:$missing" >&2
    exit 1
fi
echo "Status OK: db, redis, app, web and cron are running."
