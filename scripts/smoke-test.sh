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
compose_init "$env_file"

url="$(compose_env_value MOODLE_WWWROOT http://localhost:18080)"
[ -n "$url" ] || { echo "MOODLE_WWWROOT is missing" >&2; exit 1; }
url="${url%/}"

echo "== Containers =="
compose ps

echo
echo "== PostgreSQL =="
compose exec -T db sh -lc 'pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"'

echo
echo "== Redis =="
compose exec -T redis redis-cli ping

echo
echo "== Moodle, database, PHP extensions and plugin permissions =="
compose exec -T --user www-data app php /usr/local/bin/check-runtime.php

echo
echo "== HTTP =="
status="$(curl -fsSL --connect-timeout 10 --max-time 120 --max-redirs 5 -o /dev/null -w '%{http_code}' "$url/login/index.php")"
[ "$status" = "200" ] || { echo "Unexpected login HTTP status: $status" >&2; exit 1; }
echo "Login HTTP $status ($url/login/index.php)"

echo
echo "== Moodle router =="
check_route() {
    path=$1
    expected=$2
    actual="$(curl -sS --connect-timeout 10 --max-time 30 -o /dev/null -w '%{http_code}' "$url$path")" || exit 1
    [ "$actual" = "$expected" ] || { echo "Unexpected HTTP status for $path: $actual (expected $expected)" >&2; exit 1; }
    echo "$path HTTP $actual"
}
check_route /core/check/controller/test 200
check_route /api/rest/v2/openapi.json 200
check_route /not/a/valid/request 404
check_route /lib/exampleshimroute.php 302
check_route /lib/exampleshimroute2.php 302

echo
echo "Smoke test completed."
