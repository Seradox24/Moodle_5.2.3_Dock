#!/bin/sh
# Starts an existing installation. Never runs the database installer; use
# install.sh for a new project.
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
sh ./scripts/preflight.sh --env-file "$COMPOSE_ENV_FILE" --config-only
echo "Starting the selected project (no database installer)..."
compose up -d --wait
echo "Start completed."
