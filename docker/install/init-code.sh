#!/bin/sh
set -eu
umask 0007

# Optional paths allow testing the initialisation lifecycle in an isolated directory.
source=${1:-/opt/moodle-public}
target=${2:-/var/www/moodle/public}
reference=${3:-/var/www/moodle/.build-ref}
marker="$target/.deployment-ref"
expected="$(cat "$reference")"

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

if [ -f "$marker" ]; then
    [ "$(cat "$marker")" = "$expected" ] || fail \
        "moodle-code belongs to a different Moodle release. Follow docs/plugins.md before upgrading the core."
    [ -f "$target/version.php" ] && [ -f "$target/config.php" ] && [ -f "$target/lib/setup.php" ] || fail \
        "moodle-code is incomplete. Restore the code backup; it will not be overwritten automatically."
    echo "[code-init] Existing Moodle code and installed plugins preserved."
    exit 0
fi

[ -d "$target" ] || fail "The moodle-code volume is not mounted."
[ -z "$(find "$target" -mindepth 1 -maxdepth 1 -print -quit)" ] || fail \
    "Uninitialised, non-empty moodle-code volume. Check or restore it before continuing."

echo "[code-init] Copying the verified Moodle source into moodle-code..."
cp -a "$source/." "$target/"
# www-data UID/GID in the Debian PHP image; Nginx joins GID 33.
chown -R 33:33 "$target"
chmod -R u+rwX,g+rwX,o-rwx "$target"
find "$target" -type d -exec chmod 2770 {} +
# Write the marker last: an interrupted copy must not be accepted as complete.
printf '%s\n' "$expected" > "$marker"
chown 0:33 "$marker"
chmod 0440 "$marker"
echo "[code-init] Shared code ready; plugin directories are writable by www-data."
