#!/bin/sh
# Isolated lifecycle test; run as root in a disposable Alpine/Nginx container.
set -eu

initialiser=${1:?Pass the path to init-code.sh}
[ "$(id -u)" = 0 ] || { echo "Run this test as root in a disposable container." >&2; exit 1; }
work="$(mktemp -d)"
trap 'rm -rf "$work"' 0
chmod 0755 "$work"
seed="$work/seed"
code="$work/code"
ref="$work/ref"
mkdir -p "$seed/lib" "$seed/theme" "$seed/mod/forum" "$code"
printf '%s\n' test-source-reference > "$ref"
printf '%s\n' original-version > "$seed/version.php"
printf '%s\n' bootstrap > "$seed/config.php"
printf '%s\n' setup > "$seed/lib/setup.php"
printf '%s\n' bundled-plugin > "$seed/mod/forum/version.php"

sh "$initialiser" "$seed" "$code" "$ref"
cmp "$seed/version.php" "$code/version.php"
[ "$(stat -c '%u:%g' "$code/theme")" = '33:33' ]
[ "$(stat -c '%a' "$code/theme")" = '2770' ]
[ "$(stat -c '%a' "$code/version.php")" = '660' ]
echo 'PASS: first seed, code ownership and restricted permissions'

# Exercise the actual PHP writer / Nginx reader group relationship.
addgroup -S -g 33 moodle-code
addgroup nginx moodle-code
adduser -S -D -H -u 33 -G moodle-code appcheck
su -s /bin/sh appcheck -c "umask 0007; mkdir '$code/theme/demo'; printf 'asset' > '$code/theme/demo/style.css'"
su -s /bin/sh nginx -c "test -r '$code/theme/demo/style.css'"
printf '%s\n' upgraded-bundled-plugin > "$code/mod/forum/version.php"
sh "$initialiser" "$seed" "$code" "$ref"
[ "$(cat "$code/theme/demo/style.css")" = asset ]
[ "$(cat "$code/mod/forum/version.php")" = upgraded-bundled-plugin ]
echo 'PASS: web plugin writes, Nginx asset reads and restart preservation'

printf '%s\n' other-release > "$work/other-ref"
if sh "$initialiser" "$seed" "$code" "$work/other-ref"; then
    echo 'FAIL: accepted a core/image reference mismatch' >&2; exit 1
fi
[ "$(cat "$code/theme/demo/style.css")" = asset ]
echo 'PASS: mismatched image cannot overwrite installed plugins'

mkdir "$work/unmarked"
printf '%s\n' keep-me > "$work/unmarked/existing-plugin"
if sh "$initialiser" "$seed" "$work/unmarked" "$ref"; then
    echo 'FAIL: accepted a non-empty unmarked volume' >&2; exit 1
fi
[ "$(cat "$work/unmarked/existing-plugin")" = keep-me ]
echo 'PASS: partial/unmarked content is preserved and rejected'

rm "$code/lib/setup.php"
if sh "$initialiser" "$seed" "$code" "$ref"; then
    echo 'FAIL: accepted an incomplete code volume' >&2; exit 1
fi
echo 'PASS: incomplete code volume is rejected'
