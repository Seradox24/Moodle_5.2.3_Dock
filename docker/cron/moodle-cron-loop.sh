#!/bin/sh
set -eu

echo "[cron] Moodle cron loop started."

while true; do
    echo "[cron] $(date -Iseconds) running admin/cli/cron.php"

    if su -s /bin/sh www-data -c 'php /var/www/moodle/admin/cli/cron.php'; then
        echo "[cron] $(date -Iseconds) completed successfully"
    else
        code=$?
        echo "[cron] $(date -Iseconds) failed with exit code ${code}" >&2
    fi

    sleep 60
done
