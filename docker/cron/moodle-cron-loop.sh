#!/bin/sh
set -eu

child=
stop() {
    trap - TERM INT
    if [ -n "$child" ]; then
        kill -TERM "$child" 2>/dev/null || :
        wait "$child" 2>/dev/null || :
    fi
    exit 0
}
trap stop TERM INT

echo "[cron] Moodle cron loop started."
while true; do
    echo "[cron] $(date -Iseconds) running admin/cli/cron.php"
    # Background + wait lets PID 1 handle SIGTERM immediately during backups.
    su -s /bin/sh www-data -c 'php /var/www/moodle/admin/cli/cron.php --keep-alive=0' &
    child=$!
    if wait "$child"; then
        echo "[cron] $(date -Iseconds) completed successfully"
    else
        code=$?
        echo "[cron] $(date -Iseconds) failed with exit code ${code}" >&2
    fi
    child=
    sleep 60 &
    child=$!
    wait "$child"
    child=
done
