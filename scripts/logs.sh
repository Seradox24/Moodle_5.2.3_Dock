#!/bin/sh
# Shows recent logs for the selected project. Pass -f to follow and optional
# service names, e.g.: sh scripts/logs.sh --env-file .env -f app cron
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
        *) break ;;
    esac
done

follow=""
if [ "${1:-}" = "-f" ] || [ "${1:-}" = "--follow" ]; then
    follow="--follow"
    shift
fi

compose_init "$env_file"
compose logs --tail 100 $follow "$@"
