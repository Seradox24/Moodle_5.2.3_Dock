#!/bin/sh
set -eu

cd "$(dirname "$0")/.."
. ./scripts/lib/compose-env.sh

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

env_file=.env
config_only=false
quiet_context=false
fresh_install=false
while [ "$#" -gt 0 ]; do
    case "$1" in
        --env-file)
            [ "$#" -ge 2 ] || fail "--env-file requires a path."
            env_file=$2
            shift 2
            ;;
        --config-only)
            config_only=true
            shift
            ;;
        --quiet-context)
            quiet_context=true
            shift
            ;;
        --fresh-install)
            fresh_install=true
            shift
            ;;
        *) fail "Unknown argument: $1" ;;
    esac
done
[ "$fresh_install" = false ] || [ "$config_only" = false ] || fail "--fresh-install cannot be combined with --config-only."

command -v docker >/dev/null 2>&1 || fail "Docker is not installed."
docker compose version >/dev/null 2>&1 || fail "Docker Compose v2 plugin is not available."
if [ "$quiet_context" = true ]; then
    compose_init "$env_file" quiet no-config || fail "Cannot initialize selected environment."
else
    compose_init "$env_file" quiet no-config || fail "Cannot initialize selected environment."
fi
value() { compose_env_value "$1" "${2:-}"; }

known_keys='COMPOSE_PROJECT_NAME,IMAGE_NAMESPACE,MOODLE_WWWROOT,MOODLE_HTTP_BIND,MOODLE_HTTP_PORT,POSTGRES_DB,POSTGRES_USER,POSTGRES_PASSWORD,MOODLE_DB_PREFIX,MOODLE_SITE_FULLNAME,MOODLE_SITE_SHORTNAME,MOODLE_LANG,MOODLE_ADMIN_USER,MOODLE_ADMIN_PASSWORD,MOODLE_ADMIN_EMAIL,MOODLE_PLUGIN_INSTALL,MOODLE_REVERSEPROXY,MOODLE_SSLPROXY,MOODLE_ROUTER_CONFIGURED,MOODLE_REDIS_SESSIONS,MOODLE_REDIS_HOST,MOODLE_REDIS_PORT,MOODLE_REDIS_DATABASE,MOODLE_REDIS_PREFIX,MOODLE_MAX_UPLOAD_MB,MOODLE_MAX_REQUEST_MB,MOODLE_MEMORY_LIMIT_MB,MOODLE_MAX_EXECUTION_SECONDS,MOODLE_FPM_MAX_CHILDREN,MOODLE_FASTCGI_READ_TIMEOUT_SECONDS,COMPOSE_FILE,COMPOSE_PROFILES,COMPOSE_ENV_FILES,MOODLE_GIT_TAG,MOODLE_GIT_REF,RELEASE_IMAGE_TAG,LAUNCHER_VERSION,MOODLE_VERSION,DEBIAN_IMAGE,PHP_IMAGE,NGINX_IMAGE,POSTGRES_IMAGE,REDIS_IMAGE,MOODLE_DB_HOST,MOODLE_DB_PORT,MOODLE_MAIL_ENABLED,TZ'
obsolete_keys='MOODLE_GIT_TAG,MOODLE_GIT_REF,RELEASE_IMAGE_TAG,LAUNCHER_VERSION,MOODLE_VERSION,DEBIAN_IMAGE,PHP_IMAGE,NGINX_IMAGE,POSTGRES_IMAGE,REDIS_IMAGE,MOODLE_DB_HOST,MOODLE_DB_PORT,MOODLE_MAIL_ENABLED,TZ,SSO_ENABLED,SSO_ISSUER_URL,SSO_CLIENT_ID,INTEGRATION_API_URL'
forbidden_keys='COMPOSE_FILE,COMPOSE_PROFILES,COMPOSE_ENV_FILES'
audit_output=$(awk -v known="$known_keys" -v obsolete="$obsolete_keys" -v forbidden="$forbidden_keys" -f ./scripts/lib/audit-env.awk "$COMPOSE_ENV_FILE") || fail "Could not inspect environment variable names in $COMPOSE_ENV_FILE."
while IFS='|' read -r category item; do
    case "$category" in
        DUPLICATE) fail "Duplicate variable in $COMPOSE_ENV_FILE: $item" ;;
        FORBIDDEN) fail "Do not set $item in the selected environment file; it controls Compose itself." ;;
        OBSOLETE) echo "WARNING: $item has no implementation in this release or is release-controlled; remove it from $COMPOSE_ENV_FILE." >&2 ;;
        UNKNOWN) echo "WARNING: unknown environment variable in selected profile: $item" >&2 ;;
    esac
done <<EOF
$audit_output
EOF

missing=""
for key in MOODLE_WWWROOT POSTGRES_PASSWORD MOODLE_ADMIN_PASSWORD MOODLE_ADMIN_USER MOODLE_ADMIN_EMAIL MOODLE_SITE_FULLNAME MOODLE_SITE_SHORTNAME; do
    current="$(value "$key")"
    case "$current" in
        ''|*CHANGE_ME_*|*example.com*) missing="$missing $key" ;;
    esac
done
[ -z "$missing" ] || fail "Complete these values in $COMPOSE_ENV_FILE:$missing"

valid_port() {
    printf '%s\n' "$1" | awk '$0 ~ /^[1-9][0-9]*$/ && length($0) <= 5 && $0 + 0 <= 65535 {ok=1} END {exit !ok}'
}
project="$(value COMPOSE_PROJECT_NAME lms-moodle)"
printf '%s\n' "$project" | grep -Eq '^[a-z0-9][a-z0-9_-]{0,62}$' || fail "COMPOSE_PROJECT_NAME must start with a lowercase letter or digit and contain only lowercase letters, digits, hyphens or underscores (max 63)."
namespace="$(value IMAGE_NAMESPACE lms)"
printf '%s\n' "$namespace" | grep -Eq '^[a-z0-9]+([._-][a-z0-9]+)*(:[1-9][0-9]{0,4})?(/[a-z0-9]+([._-][a-z0-9]+)*)*$' || fail "IMAGE_NAMESPACE must be a lowercase image namespace (optionally registry:port/path)."
registry="${namespace%%/*}"
case "$registry" in
    *:*) namespace_port="${registry##*:}"; valid_port "$namespace_port" || fail "IMAGE_NAMESPACE registry port must be an integer from 1 to 65535." ;;
esac

port="$(value MOODLE_HTTP_PORT 18080)"
valid_port "$port" || fail "MOODLE_HTTP_PORT must be an integer from 1 to 65535."
bind="$(value MOODLE_HTTP_BIND 127.0.0.1)"
valid_ipv4() {
    [ "$1" = 0.0.0.0 ] && return 0
    printf '%s\n' "$1" | awk -F. 'NF != 4 {exit 1} {for (i = 1; i <= 4; i++) if ($i !~ /^[0-9][0-9]?[0-9]?$/ || $i + 0 > 255) exit 1}'
}
valid_ipv4 "$bind" || fail "MOODLE_HTTP_BIND must be 0.0.0.0, 127.0.0.1 or a valid IPv4 address."
case "$bind" in
    127.*) [ "$bind" = 127.0.0.1 ] || fail "Only 127.0.0.1 is supported as a loopback bind address." ;;
esac

url="$(value MOODLE_WWWROOT)"
if ! url_parts=$(printf '%s\n' "$url" | awk -f ./scripts/lib/validate-wwwroot.awk); then
    fail "MOODLE_WWWROOT must be an absolute http(s) URL with a DNS name or IPv4 host, optional valid port and no path/query/userinfo."
fi
old_ifs=$IFS
IFS='|'
set -- $url_parts
IFS=$old_ifs
url_scheme=$1
url_host=$2
url_port=$3

for key in MOODLE_PLUGIN_INSTALL MOODLE_REVERSEPROXY MOODLE_SSLPROXY MOODLE_ROUTER_CONFIGURED MOODLE_REDIS_SESSIONS; do
    compose_env_has "$key" || continue
    current="$(value "$key")"
    case "$current" in
        true|false) ;;
        *) fail "$key must be exactly 'true' or 'false'." ;;
    esac
done

[ "$(value MOODLE_REVERSEPROXY true)" = true ] || fail "MOODLE_REVERSEPROXY must be true for the published internal Nginx port."
[ "$(value MOODLE_ROUTER_CONFIGURED true)" = true ] || fail "MOODLE_ROUTER_CONFIGURED must remain true for the internal Nginx r.php fallback."
sslproxy="$(value MOODLE_SSLPROXY false)"
if [ "$sslproxy" = true ]; then
    [ "$url_scheme" = https ] || fail "MOODLE_SSLPROXY=true requires an https:// MOODLE_WWWROOT."
    [ "$bind" = 127.0.0.1 ] || fail "MOODLE_SSLPROXY=true requires MOODLE_HTTP_BIND=127.0.0.1 so the internal web port is not exposed on the LAN."
else
    [ "$url_scheme" = http ] || fail "An https:// MOODLE_WWWROOT requires MOODLE_SSLPROXY=true."
    [ "$url_port" -eq "$port" ] || fail "For direct HTTP access, the MOODLE_WWWROOT port must match MOODLE_HTTP_PORT."
fi

if [ "$sslproxy" = false ] && [ "$bind" = 127.0.0.1 ] && [ "$url_host" != localhost ] && [ "$url_host" != 127.0.0.1 ]; then
    fail "A loopback-only MOODLE_HTTP_BIND requires a local MOODLE_WWWROOT unless SSL terminates at the central proxy."
fi
if [ "$sslproxy" = false ] && [ "$bind" != 127.0.0.1 ] && [ "$bind" != 0.0.0.0 ] && { [ "$url_host" = localhost ] || [ "$url_host" = 127.0.0.1 ]; }; then
    fail "A localhost MOODLE_WWWROOT cannot use a LAN-only MOODLE_HTTP_BIND."
fi
if [ "$sslproxy" = false ] && [ "$bind" != 0.0.0.0 ] && printf '%s\n' "$url_host" | grep -Eq '^[0-9]+(\.[0-9]+){3}$' && [ "$bind" != "$url_host" ]; then
    fail "MOODLE_HTTP_BIND and the IPv4 host in MOODLE_WWWROOT must match for direct access."
fi
if [ "$bind" = 0.0.0.0 ] && [ "$url_host" = localhost ]; then
    echo "WARNING: MOODLE_WWWROOT=localhost is only suitable for clients on the server; use its LAN IP for remote access." >&2
fi

db_name="$(value POSTGRES_DB moodle)"
db_user="$(value POSTGRES_USER moodle)"
printf '%s\n' "$db_name" | grep -Eq '^[A-Za-z_][A-Za-z0-9_]{0,62}$' || fail "POSTGRES_DB must be a SQL identifier (letters, digits or underscores; max 63)."
printf '%s\n' "$db_user" | grep -Eq '^[A-Za-z_][A-Za-z0-9_]{0,62}$' || fail "POSTGRES_USER must be a SQL identifier (letters, digits or underscores; max 63)."
db_prefix="$(value MOODLE_DB_PREFIX mdl_)"
printf '%s\n' "$db_prefix" | grep -Eq '^[A-Za-z][A-Za-z0-9_]{0,9}$' || fail "MOODLE_DB_PREFIX must start with a letter and contain only letters, digits or underscores (max 10 for Moodle 5.2)."
redis_port="$(value MOODLE_REDIS_PORT 6379)"
valid_port "$redis_port" || fail "MOODLE_REDIS_PORT must be an integer from 1 to 65535."
redis_database="$(value MOODLE_REDIS_DATABASE 0)"
printf '%s\n' "$redis_database" | awk '$0 ~ /^[0-9]+$/ && $0 + 0 <= 15 {ok=1} END {exit !ok}' || fail "MOODLE_REDIS_DATABASE must be an integer from 0 to 15."

limit_value() {
    key=$1
    default=$2
    min=$3
    max=$4
    current="$(value "$key" "$default")"
    printf '%s\n' "$current" | grep -Eq '^[0-9]+$' || fail "$key must be an integer."
    [ "$current" -ge "$min" ] && [ "$current" -le "$max" ] || fail "$key must be between $min and $max."
    printf '%s' "$current"
}
upload_mb="$(limit_value MOODLE_MAX_UPLOAD_MB 256 1 10240)"
request_mb="$(limit_value MOODLE_MAX_REQUEST_MB 300 1 10240)"
memory_mb="$(limit_value MOODLE_MEMORY_LIMIT_MB 512 128 65536)"
execution_seconds="$(limit_value MOODLE_MAX_EXECUTION_SECONDS 30 5 7200)"
fpm_children="$(limit_value MOODLE_FPM_MAX_CHILDREN 5 3 512)"
fastcgi_seconds="$(limit_value MOODLE_FASTCGI_READ_TIMEOUT_SECONDS 120 5 3600)"
[ "$request_mb" -gt "$upload_mb" ] || fail "MOODLE_MAX_REQUEST_MB must be greater than MOODLE_MAX_UPLOAD_MB so the full request (with form overhead) fits."
email="$(value MOODLE_ADMIN_EMAIL)"
printf '%s\n' "$email" | grep -Eq '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' || fail "MOODLE_ADMIN_EMAIL must be a valid email address."
for key in MOODLE_ADMIN_USER MOODLE_SITE_FULLNAME MOODLE_SITE_SHORTNAME; do
    current="$(value "$key" '')"
    case "$current" in
        ''|*[![:space:]]*) ;;
        *) fail "$key must not be empty or whitespace-only." ;;
    esac
done
language="$(value MOODLE_LANG es)"
printf '%s\n' "$language" | grep -Eq '^[A-Za-z0-9_-]+$' || fail "MOODLE_LANG may contain only letters, digits, '_' or '-'."

release_tag="$(value MOODLE_GIT_TAG)"
release_ref="$(value MOODLE_GIT_REF)"
moodle_version="$(value MOODLE_VERSION)"
launcher_version="$(value LAUNCHER_VERSION)"
release_image_tag="$(value RELEASE_IMAGE_TAG)"
[ "$release_tag" = "v$moodle_version" ] || fail "Release metadata mismatch: MOODLE_GIT_TAG must correspond to MOODLE_VERSION."
printf '%s\n' "$release_ref" | grep -Eq '^[0-9a-f]{40}$' || fail "Release metadata MOODLE_GIT_REF must be a 40-character lowercase commit hash."
[ "$release_image_tag" = "moodle-${moodle_version}-launcher-${launcher_version}" ] || fail "Release metadata RELEASE_IMAGE_TAG must encode the Moodle and launcher versions."
for key in DEBIAN_IMAGE PHP_IMAGE NGINX_IMAGE POSTGRES_IMAGE REDIS_IMAGE; do
    image_ref="$(value "$key")"
    printf '%s\n' "$image_ref" | grep -Eq '^.+@sha256:[0-9a-f]{64}$' || fail "Release metadata $key must pin an image to a SHA256 digest."
done

compose config --quiet || fail "The resolved Compose configuration is invalid; review the variable named in the Compose error."

if [ "$config_only" = true ]; then
    echo "Configuration OK."
    exit 0
fi

command -v curl >/dev/null 2>&1 || fail "curl is not installed. Install it with: sudo apt-get install -y curl"
docker info >/dev/null 2>&1 || fail "Docker Engine is not running or this user cannot access it."

if [ "$fresh_install" = true ]; then
    existing_containers="$(docker ps -a -q --filter "label=com.docker.compose.project=$project")" || fail "Cannot inspect containers for project $project."
    [ -z "$existing_containers" ] || fail "Project $project already has containers; install.sh is only for a fresh project."
    existing_volumes="$(docker volume ls -q --filter "label=com.docker.compose.project=$project")" || fail "Cannot inspect volumes for project $project."
    [ -z "$existing_volumes" ] || fail "Project $project already has data volumes; refusing a fresh install."
fi

running_services="$(compose ps --status running --services)" || fail "Cannot inspect running services for project $project."

if command -v ss >/dev/null 2>&1; then
    if ! printf '%s\n' "$running_services" | grep -qx web && ss -ltn | awk '{print $4}' | grep -Eq ":${port}$"; then
        fail "Host port ${port} is already in use outside project $project. Choose another MOODLE_HTTP_PORT."
    fi
fi

echo "Preflight OK."
