#!/bin/sh
set -eu
umask 0007

if [ "${1:-}" = "init-code" ]; then
    exec sh /usr/local/bin/init-code.sh
fi

marker=/var/www/moodle/public/.deployment-ref
if [ ! -r "$marker" ] || [ "$(cat "$marker")" != "$(cat /var/www/moodle/.build-ref)" ]; then
    echo "ERROR: Shared Moodle code is not initialised or does not match this image. Check code-init logs." >&2
    exit 1
fi

exec docker-php-entrypoint "$@"
