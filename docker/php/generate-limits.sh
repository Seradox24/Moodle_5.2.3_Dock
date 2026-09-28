#!/bin/sh
# Renders the operational limits from the selected environment into the tmpfs
# /run/php so the read-only image filesystem stays untouched. Invalid values
# abort startup with a clear message.
set -eu

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

is_int() {
    case "$1" in
        ''|*[!0-9]*) return 1 ;;
    esac
}

upload=${MOODLE_MAX_UPLOAD_MB:-256}
request=${MOODLE_MAX_REQUEST_MB:-300}
memory=${MOODLE_MEMORY_LIMIT_MB:-512}
execution=${MOODLE_MAX_EXECUTION_SECONDS:-30}
children=${MOODLE_FPM_MAX_CHILDREN:-5}

for pair in \
    "MOODLE_MAX_UPLOAD_MB:$upload" \
    "MOODLE_MAX_REQUEST_MB:$request" \
    "MOODLE_MEMORY_LIMIT_MB:$memory" \
    "MOODLE_MAX_EXECUTION_SECONDS:$execution" \
    "MOODLE_FPM_MAX_CHILDREN:$children"
do
    name=${pair%%:*}
    value=${pair#*:}
    is_int "$value" || fail "$name must be an integer."
done

[ "$upload" -ge 1 ] && [ "$upload" -le 10240 ] || fail "MOODLE_MAX_UPLOAD_MB must be between 1 and 10240."
[ "$request" -ge 1 ] && [ "$request" -le 10240 ] || fail "MOODLE_MAX_REQUEST_MB must be between 1 and 10240."
[ "$request" -gt "$upload" ] || fail "MOODLE_MAX_REQUEST_MB must be greater than MOODLE_MAX_UPLOAD_MB so the full request (with form overhead) fits."
[ "$memory" -ge 128 ] && [ "$memory" -le 65536 ] || fail "MOODLE_MEMORY_LIMIT_MB must be between 128 and 65536."
[ "$execution" -ge 5 ] && [ "$execution" -le 7200 ] || fail "MOODLE_MAX_EXECUTION_SECONDS must be between 5 and 7200."
# The dynamic pool keeps start_servers=2 and max_spare_servers=3.
[ "$children" -ge 3 ] && [ "$children" -le 512 ] || fail "MOODLE_FPM_MAX_CHILDREN must be between 3 and 512."

dir=/run/php
mkdir -p "$dir"

cat > "$dir/zz-limits.ini" <<EOF
upload_max_filesize = ${upload}M
post_max_size = ${request}M
memory_limit = ${memory}M
max_execution_time = ${execution}
EOF

cat > "$dir/fpm-pool.conf" <<EOF
pm.max_children = ${children}
EOF

echo "[limits] upload=${upload}M request=${request}M memory=${memory}M execution=${execution}s fpm_max_children=${children}"
