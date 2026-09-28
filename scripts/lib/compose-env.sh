#!/bin/sh

MOODLE_MANAGED_ENV_VARS='COMPOSE_PROJECT_NAME COMPOSE_FILE COMPOSE_PROFILES COMPOSE_ENV_FILES IMAGE_NAMESPACE MOODLE_WWWROOT MOODLE_HTTP_BIND MOODLE_HTTP_PORT LAUNCHER_VERSION MOODLE_VERSION MOODLE_GIT_TAG MOODLE_GIT_REF RELEASE_IMAGE_TAG DEBIAN_IMAGE PHP_IMAGE NGINX_IMAGE POSTGRES_IMAGE REDIS_IMAGE POSTGRES_DB POSTGRES_USER POSTGRES_PASSWORD MOODLE_DB_PREFIX MOODLE_SITE_FULLNAME MOODLE_SITE_SHORTNAME MOODLE_LANG MOODLE_ADMIN_USER MOODLE_ADMIN_PASSWORD MOODLE_ADMIN_EMAIL MOODLE_PLUGIN_INSTALL MOODLE_REVERSEPROXY MOODLE_SSLPROXY MOODLE_ROUTER_CONFIGURED MOODLE_REDIS_SESSIONS MOODLE_REDIS_HOST MOODLE_REDIS_PORT MOODLE_REDIS_DATABASE MOODLE_REDIS_PREFIX MOODLE_MAX_UPLOAD_MB MOODLE_MAX_REQUEST_MB MOODLE_MEMORY_LIMIT_MB MOODLE_MAX_EXECUTION_SECONDS MOODLE_FPM_MAX_CHILDREN MOODLE_FASTCGI_READ_TIMEOUT_SECONDS'

compose_init() {
    COMPOSE_REPO_ROOT=$(pwd -P)
    selected=${1:-.env}
    COMPOSE_RELEASE_FILE=$COMPOSE_REPO_ROOT/releases/release.env
    [ -f "$COMPOSE_RELEASE_FILE" ] || {
        echo "ERROR: Versioned release metadata is missing: $COMPOSE_RELEASE_FILE" >&2
        return 1
    }
    case "$selected" in
        /*) candidate=$selected ;;
        *) candidate=$COMPOSE_REPO_ROOT/$selected ;;
    esac
    [ -f "$candidate" ] || {
        echo "ERROR: Environment file not found: $candidate" >&2
        return 1
    }
    env_dir=$(dirname "$candidate")
    env_name=$(basename "$candidate")
    COMPOSE_ENV_FILE=$(CDPATH= cd -- "$env_dir" && pwd -P)/$env_name

    profile_project=$(awk '
        {
            line = $0
            sub(/\r$/, "", line)
            if (NR == 1) sub(/^\357\273\277/, "", line)
            sub(/^[[:space:]]*export[[:space:]]+/, "", line)
            if (!match(line, /^[[:space:]]*COMPOSE_PROJECT_NAME[[:space:]]*=/)) next
            value = substr(line, index(line, "=") + 1)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            if (value ~ /^\047.*\047$/ || value ~ /^".*"$/) value = substr(value, 2, length(value) - 2)
            else sub(/[[:space:]]+#.*/, "", value)
            selected = value
            found = 1
        }
        END { if (found) printf "%s", selected }
    ' "$COMPOSE_ENV_FILE")
    profile_project=${profile_project:-lms-moodle}
    printf '%s\n' "$profile_project" | grep -Eq '^[a-z0-9][a-z0-9_-]{0,62}$' || {
        echo "ERROR: COMPOSE_PROJECT_NAME must start with a lowercase letter or digit and contain only lowercase letters, digits, hyphens or underscores (max 63)." >&2
        return 1
    }

    conflicts=""
    for key in $MOODLE_MANAGED_ENV_VARS; do
        if env | awk -v key="$key" 'index($0, key "=") == 1 {found=1; exit} END {exit !found}'; then
            conflicts="$conflicts $key"
        fi
    done
    [ -z "$conflicts" ] || {
        echo "ERROR: Unset template-managed shell variables before running this command:$conflicts" >&2
        return 1
    }

    if [ "${3:-}" != no-config ]; then
        docker compose --project-directory "$COMPOSE_REPO_ROOT" --file "$COMPOSE_REPO_ROOT/compose.yaml" --env-file "$COMPOSE_ENV_FILE" --env-file "$COMPOSE_RELEASE_FILE" config --quiet || return 1
        env_model="$COMPOSE_REPO_ROOT/compose.yaml"
    else
        env_model="$COMPOSE_REPO_ROOT/scripts/lib/environment-only.yaml"
    fi
    COMPOSE_RESOLVED_ENV=$(docker compose --project-directory "$COMPOSE_REPO_ROOT" --file "$env_model" --env-file "$COMPOSE_ENV_FILE" --env-file "$COMPOSE_RELEASE_FILE" config --environment) || return 1

    project=$(compose_env_value COMPOSE_PROJECT_NAME lms-moodle)
    url=$(compose_env_value MOODLE_WWWROOT http://localhost:18080)
    launcher=$(compose_env_value LAUNCHER_VERSION unknown)
    moodle=$(compose_env_value MOODLE_VERSION unknown)
    project=${project:-lms-moodle}
    url=${url:-http://localhost:18080}
    display_url=$(printf '%s' "$url" | sed -E 's#^(https?://)[^/@]+@#\1[redacted]@#')
    if [ "${2:-}" != quiet ]; then
        printf 'Environment file: %s\nProject: %s\nLauncher: %s\nMoodle: %s\nURL: %s\n' "$COMPOSE_ENV_FILE" "$project" "$launcher" "$moodle" "$display_url"
    fi
}

compose_env_value() {
    printf '%s\n' "$COMPOSE_RESOLVED_ENV" | awk -v key="$1" 'index($0, key "=") == 1 {print substr($0, length(key) + 2); found=1; exit} END {if (!found) exit 1}' || printf '%s' "$2"
}

compose_env_has() {
    printf '%s\n' "$COMPOSE_RESOLVED_ENV" | awk -v key="$1" 'index($0, key "=") == 1 {found=1; exit} END {exit !found}'
}

compose() {
    docker compose --project-directory "$COMPOSE_REPO_ROOT" --file "$COMPOSE_REPO_ROOT/compose.yaml" --env-file "$COMPOSE_ENV_FILE" --env-file "$COMPOSE_RELEASE_FILE" "$@"
}
