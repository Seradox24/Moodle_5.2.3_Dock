#!/bin/sh
set -eu

cd "$(dirname "$0")/.."
. ./scripts/lib/compose-env.sh

env_file=.env
if [ "${1:-}" = "--env-file" ]; then
    [ "$#" -ge 2 ] || { echo "--env-file requires a path." >&2; exit 1; }
    env_file=$2
    shift 2
fi
[ "$#" -gt 0 ] || { echo "Usage: sh scripts/compose.sh [--env-file PATH] COMPOSE_ARGS..." >&2; exit 2; }

compose_init "$env_file"
compose "$@"
