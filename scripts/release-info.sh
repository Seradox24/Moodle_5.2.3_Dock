#!/bin/sh
# Diagnostic: project, effective release metadata, image identifiers, code
# volume marker and embedded-script parity. Prints no secrets. Exit 0 when the
# deployed pieces match the versioned release in releases/release.env.
set -eu

cd "$(dirname "$0")/.."
. ./scripts/lib/compose-env.sh

env_file=.env
while [ "$#" -gt 0 ]; do
    case "$1" in
        --env-file)
            [ "$#" -ge 2 ] || { echo "--env-file requires a path." >&2; exit 1; }
            env_file=$2
            shift 2
            ;;
        *) echo "Unknown argument: $1" >&2; exit 1 ;;
    esac
done

compose_init "$env_file"

namespace="$(compose_env_value IMAGE_NAMESPACE lms)"
release_tag="$(compose_env_value RELEASE_IMAGE_TAG '')"
launcher="$(compose_env_value LAUNCHER_VERSION unknown)"
moodle="$(compose_env_value MOODLE_VERSION unknown)"
core_ref="$(compose_env_value MOODLE_GIT_REF '')"

echo
echo "Repository release: launcher=$launcher moodle=$moodle tag=$release_tag"
echo "Running services: $(compose ps --status running --services | tr '\n' ' ')"

status=0
for service in app web cron; do
    cid=$(compose ps -a -q "$service")
    if [ -z "$cid" ]; then
        echo "MISSING: $service container"
        status=1
        continue
    fi
    image=$(docker inspect --format '{{.Image}}' "$cid")
    if [ "$(docker inspect --format '{{.State.Running}}' "$cid")" != true ]; then
        echo "STOPPED: $service"; status=1
    fi
    image_id="$(docker image inspect --format '{{.Id}}' "$image")"
    image_launcher="$(docker image inspect --format '{{index .Config.Labels "io.lms.launcher.version"}}' "$image")"
    image_moodle="$(docker image inspect --format '{{index .Config.Labels "io.lms.moodle.version"}}' "$image")"
    image_revision="$(docker image inspect --format '{{index .Config.Labels "org.opencontainers.image.revision"}}' "$image")"
    echo "IMAGE $service: $image id=$image_id launcher=$image_launcher moodle=$image_moodle core=$image_revision"
    if [ "$image_launcher" != "$launcher" ] || [ "$image_moodle" != "$moodle" ] || [ "$image_revision" != "$core_ref" ]; then
        echo "MISMATCH: $service image labels do not match the versioned release"
        status=1
    fi
done

app_cid=$(compose ps -q app)
if [ -n "$app_cid" ]; then
    # Paths are passed inside a shell string to survive MSYS/Git Bash argument
    # conversion when the launcher runs on Windows.
    hash_line=$(docker exec "$app_cid" sh -c 'sha256sum /usr/local/bin/check-runtime.php') || exit 1
    image_hash=$(printf '%s\n' "$hash_line" | awk '{print $1}')
    local_hash="$(sha256sum docker/install/check-runtime.php | awk '{print $1}')"
    if [ -n "$image_hash" ] && [ "$image_hash" = "$local_hash" ]; then
        echo "CHECK-RUNTIME: embedded script matches the repository (${local_hash%?????????????????????????????????????????????????????}...)"
    else
        echo "DIFFERS: the check-runtime.php embedded in the image does not match the repository." >&2
        echo "          Deliver the smoke-test fix by rebuilding the release; copying the file to the server does not update the image." >&2
        status=1
    fi

    marker=$(docker exec "$app_cid" sh -c 'cat /var/www/moodle/public/.deployment-ref') || exit 1
    if [ -z "$marker" ]; then
        echo "MISSING: moodle-code volume has no .deployment-ref marker (project not initialised?)"
        status=1
    elif [ "$marker" = "$core_ref" ]; then
        echo "CODE VOLUME: .deployment-ref matches the versioned core commit"
    else
        echo "DIFFERS: moodle-code marker '$marker' does not match the release core commit '$core_ref'"
        status=1
    fi
fi

echo
if [ "$status" -eq 0 ]; then
    echo "Release check OK: the selected project matches launcher $launcher / Moodle $moodle."
else
    echo "Release check found mismatches; review the lines above before operating." >&2
    exit 1
fi
