#!/bin/sh
set -eu
umask 077

repo_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd -P)
example="$repo_root/.env.example"
output=.env
project_name=lms-moodle-dev

while [ "$#" -gt 0 ]; do
    case "$1" in
        --output)
            [ "$#" -ge 2 ] || { echo "ERROR: --output requires a path." >&2; exit 2; }
            output=$2
            shift 2
            ;;
        --project-name)
            [ "$#" -ge 2 ] || { echo "ERROR: --project-name requires a value." >&2; exit 2; }
            project_name=$2
            shift 2
            ;;
        --help)
            echo "Usage: sh scripts/prepare-env.sh [--output PATH] [--project-name NAME]"
            echo "Relative output paths are resolved from the repository root."
            exit 0
            ;;
        *) echo "ERROR: unknown argument: $1" >&2; exit 2 ;;
    esac
done

case "$project_name" in
    ''|[!a-z0-9]*|*[!a-z0-9_-]*)
        echo "ERROR: project name must use lowercase letters, digits, '_' or '-', and start with a letter or digit." >&2
        exit 1
        ;;
esac

if [ "${#project_name}" -gt 63 ]; then
    echo "ERROR: project name must not exceed 63 characters." >&2
    exit 1
fi

if [ ! -f "$example" ]; then
    echo "ERROR: .env.example is missing." >&2
    exit 1
fi

if ! command -v openssl >/dev/null 2>&1; then
    echo "ERROR: openssl is required to generate private passwords." >&2
    exit 1
fi

if [ -z "$output" ]; then
    echo "ERROR: output path is required." >&2
    exit 1
fi

# Generate into the same directory and link atomically so concurrent/repeated
# preparation can never replace an existing private profile.

case "$output" in
    /*) target=$output ;;
    *) target="$repo_root/$output" ;;
esac
target_dir=$(dirname "$target")
target_name=$(basename "$target")
[ -d "$target_dir" ] || { echo "ERROR: output directory does not exist: $target_dir" >&2; exit 1; }
target_dir=$(CDPATH= cd -- "$target_dir" && pwd -P)
target="$target_dir/$target_name"
[ ! -e "$target" ] && [ ! -L "$target" ] || {
    echo "ERROR: refusing to overwrite existing environment file: $target" >&2
    exit 1
}

db_password=$(openssl rand -base64 32)
admin_password=$(openssl rand -base64 32)
tmp=$(mktemp "$target_dir/.moodle-env.XXXXXX")
trap 'rm -f "$tmp"' 0
trap 'exit 1' HUP INT TERM

{
    printf '%s\n%s\n' "$db_password" "$admin_password"
    cat "$example"
} | awk -v project_name="$project_name" '
    NR == 1 { db_password = $0; next }
    NR == 2 { admin_password = $0; next }
    $0 == "COMPOSE_PROJECT_NAME=lms-moodle" {
        print "COMPOSE_PROJECT_NAME=" project_name
        project_found = 1
        next
    }
    $0 == "IMAGE_NAMESPACE=lms" { print "IMAGE_NAMESPACE=lmsdev"; next }
    $0 == "MOODLE_WWWROOT=https://moodle.example.com" {
        print "MOODLE_WWWROOT=http://localhost:18080"
        url_found = 1
        next
    }
    $0 == "MOODLE_SSLPROXY=true" {
        print "MOODLE_SSLPROXY=false"
        ssl_found = 1
        next
    }
    $0 == "POSTGRES_PASSWORD=CHANGE_ME_STRONG_DB_PASSWORD" {
        print "POSTGRES_PASSWORD=" db_password
        db_found = 1
        next
    }
    $0 == "MOODLE_ADMIN_PASSWORD=CHANGE_ME_STRONG_ADMIN_PASSWORD" {
        print "MOODLE_ADMIN_PASSWORD=" admin_password
        admin_found = 1
        next
    }
    { print }
    END { if (!project_found || !url_found || !ssl_found || !db_found || !admin_found) exit 1 }
' > "$tmp" || { echo "ERROR: could not prepare the private environment file." >&2; exit 1; }

chmod 600 "$tmp"
ln "$tmp" "$target" || {
    echo "ERROR: refusing to overwrite existing environment file: $target" >&2
    exit 1
}
rm -f "$tmp"
trap - 0 HUP INT TERM
printf 'Created private environment file: %s\n' "$target"
