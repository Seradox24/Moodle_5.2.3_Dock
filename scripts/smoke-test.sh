#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

[ -f .env ] || {
    echo "Missing .env" >&2
    exit 1
}

url="$(docker compose config --environment | sed -n 's/^MOODLE_WWWROOT=//p')"
[ -n "$url" ] || { echo "MOODLE_WWWROOT is missing" >&2; exit 1; }
url="${url%/}"

echo "== Containers =="
docker compose ps

echo
echo "== PostgreSQL =="
docker compose exec -T db sh -lc 'pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"'

echo
echo "== Redis =="
docker compose exec -T redis redis-cli ping

echo
echo "== Moodle, database, PHP extensions and plugin permissions =="
docker compose exec -T --user www-data app php /usr/local/bin/check-runtime.php

echo
echo "== HTTP =="
status="$(curl -fsSL --connect-timeout 10 --max-time 120 --max-redirs 5 -o /dev/null -w '%{http_code}' "$url/login/index.php")"
[ "$status" = "200" ] || { echo "Unexpected login HTTP status: $status" >&2; exit 1; }
echo "Login HTTP $status ($url/login/index.php)"

echo
echo "Smoke test completed."
