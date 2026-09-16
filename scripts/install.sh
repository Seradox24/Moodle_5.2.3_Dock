#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

[ -f .env ] || {
    echo "Missing .env. Copy .env.example to .env first." >&2
    exit 1
}

sh ./scripts/preflight.sh

echo "Building Moodle images..."
docker compose build

echo "Starting PostgreSQL and Redis..."
docker compose up -d db redis

echo "Initialising shared code and starting Moodle PHP-FPM..."
docker compose up -d --wait app

echo "Installing Moodle database..."
docker compose exec -T --user www-data app sh /usr/local/bin/install-database.sh

echo "Starting web and cron..."
docker compose up -d --wait web cron

echo
echo "Fresh Moodle installation completed."
echo "Public URL: $(grep "^MOODLE_WWWROOT=" .env | cut -d= -f2-)"
echo "Run: sh ./scripts/smoke-test.sh"
