#!/bin/sh
set -eu

: "${MOODLE_SITE_FULLNAME:?Set the real site full name in .env}"
: "${MOODLE_SITE_SHORTNAME:?Set the real site short name in .env}"
: "${MOODLE_ADMIN_PASSWORD:?Set the admin password in .env}"
: "${MOODLE_ADMIN_EMAIL:?Set the real admin email in .env}"

exec php /usr/local/bin/install-database.php
