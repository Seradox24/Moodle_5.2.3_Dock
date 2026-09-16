#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

command -v docker >/dev/null 2>&1 || fail "Docker is not installed."
docker compose version >/dev/null 2>&1 || fail "Docker Compose v2 plugin is not available."

[ -f .env ] || fail ".env does not exist. Run: cp .env.example .env"

docker compose config --quiet
# Let Compose parse dotenv quotes/escaping; never source .env as a shell script.
resolved="$(docker compose config --environment)"
value() {
    printf '%s\n' "$resolved" | awk -v key="$1" 'index($0, key "=") == 1 {print substr($0, length(key) + 2); exit}'
}

missing=""
for key in MOODLE_WWWROOT POSTGRES_PASSWORD MOODLE_ADMIN_PASSWORD MOODLE_ADMIN_USER MOODLE_ADMIN_EMAIL MOODLE_SITE_FULLNAME MOODLE_SITE_SHORTNAME; do
    current="$(value "$key")"
    case "$current" in
        ''|*CHANGE_ME_*|*example.com*) missing="$missing $key" ;;
    esac
done
[ -z "$missing" ] || fail "Complete these values in .env:$missing"
case "$(value MOODLE_WWWROOT)" in
    http://*|https://*) ;;
    *) fail "MOODLE_WWWROOT must be an absolute http:// or https:// URL." ;;
esac

if [ "${1:-}" = "--config-only" ]; then
    echo "Configuration OK."
    exit 0
fi

command -v curl >/dev/null 2>&1 || fail "curl is not installed. Install it with: sudo apt-get install -y curl"
docker info >/dev/null 2>&1 || fail "Docker Engine is not running or this user cannot access it."
port="$(value MOODLE_HTTP_PORT)"
port="${port:-18080}"

if command -v ss >/dev/null 2>&1; then
    if ss -ltn | awk '{print $4}' | grep -Eq ":${port}$"; then
        fail "Host port ${port} is already in use. Choose another MOODLE_HTTP_PORT."
    fi
fi

echo "Preflight OK."
