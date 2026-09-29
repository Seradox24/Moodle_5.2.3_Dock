#!/bin/sh
# Optional local test profile. Production is created manually from .env.example.
set -eu
umask 077

repo_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd -P)
output=.env
project_name=lms-moodle-dev
while [ "$#" -gt 0 ]; do
    case "$1" in
        --output) [ "$#" -ge 2 ] || { echo "ERROR: --output requires a path." >&2; exit 2; }; output=$2; shift 2 ;;
        --project-name) [ "$#" -ge 2 ] || { echo "ERROR: --project-name requires a value." >&2; exit 2; }; project_name=$2; shift 2 ;;
        --help) echo "Usage: sh scripts/prepare-env.sh [--output PATH] [--project-name NAME]"; exit 0 ;;
        *) echo "ERROR: unknown argument: $1" >&2; exit 2 ;;
    esac
done
printf '%s\n' "$project_name" | grep -Eq '^[a-z0-9][a-z0-9_-]{0,62}$' || {
    echo "ERROR: invalid project name." >&2
    exit 1
}
command -v openssl >/dev/null 2>&1 || { echo "ERROR: openssl is required." >&2; exit 1; }
[ -n "$output" ] || { echo "ERROR: output path is required." >&2; exit 1; }
case "$output" in
    /*) target=$output ;;
    *) target="$repo_root/$output" ;;
esac
target_dir=$(dirname "$target")
target_name=$(basename "$target")
[ -d "$target_dir" ] || { echo "ERROR: output directory does not exist: $target_dir" >&2; exit 1; }
target_dir=$(CDPATH= cd -- "$target_dir" && pwd -P)
target="$target_dir/$target_name"
[ ! -e "$target" ] && [ ! -L "$target" ] || { echo "ERROR: refusing to overwrite $target" >&2; exit 1; }

db_password=$(openssl rand -hex 24)
admin_password=$(openssl rand -hex 24)
tmp=$(mktemp "$target_dir/.moodle-env.XXXXXX")
trap 'rm -f "$tmp"' 0
trap 'exit 1' HUP INT TERM
cat > "$tmp" <<EOF
# Local test profile. Never use as the production URL.
COMPOSE_PROJECT_NAME=$project_name
IMAGE_NAMESPACE=lmsdev
MOODLE_WWWROOT=http://localhost:18080
MOODLE_SSLPROXY=false
MOODLE_REVERSEPROXY=true
POSTGRES_PASSWORD=$db_password
MOODLE_SITE_FULLNAME=Plataforma Moodle
MOODLE_SITE_SHORTNAME=Moodle
MOODLE_ADMIN_PASSWORD=$admin_password
MOODLE_ADMIN_EMAIL=admin@moodle.invalid
EOF
chmod 600 "$tmp"
ln "$tmp" "$target" || { echo "ERROR: refusing to overwrite $target" >&2; exit 1; }
rm -f "$tmp"
trap - 0 HUP INT TERM
printf 'Created private local profile: %s\n' "$target"
echo 'Edit MOODLE_ADMIN_EMAIL before sending any real mail.'
