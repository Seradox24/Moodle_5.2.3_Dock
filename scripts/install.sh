#!/bin/sh
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

compose_init "$env_file" quiet no-config

sh ./scripts/preflight.sh --env-file "$COMPOSE_ENV_FILE" --fresh-install

echo "Building Moodle images..."
compose build

echo "Starting PostgreSQL and Redis..."
compose up -d db redis

echo "Initialising shared code and starting Moodle PHP-FPM..."
compose up -d --wait app

echo "Installing Moodle database..."
compose exec -T --user www-data app sh /usr/local/bin/install-database.sh

echo "Starting web and cron..."
compose up -d --wait web cron

echo
echo "Fresh Moodle installation completed."
echo "Public URL: $(compose_env_value MOODLE_WWWROOT http://localhost:18080)"
echo "Run: sh ./scripts/smoke-test.sh --env-file \"$COMPOSE_ENV_FILE\""
