#!/bin/sh
set -eu

: "${MOODLE_SITE_FULLNAME:?Set the real site full name in .env}"
: "${MOODLE_SITE_SHORTNAME:?Set the real site short name in .env}"
: "${MOODLE_ADMIN_PASSWORD:?Set the admin password in .env}"
: "${MOODLE_ADMIN_EMAIL:?Set the real admin email in .env}"

exec php /var/www/moodle/admin/cli/install_database.php \
    --agree-license \
    --lang="${MOODLE_LANG:-es}" \
    --fullname="${MOODLE_SITE_FULLNAME}" \
    --shortname="${MOODLE_SITE_SHORTNAME}" \
    --adminuser="${MOODLE_ADMIN_USER:-admin}" \
    --adminpass="${MOODLE_ADMIN_PASSWORD}" \
    --adminemail="${MOODLE_ADMIN_EMAIL}"
