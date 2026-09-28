#!/bin/sh
# Removes the containers, networks and volumes of one selected test project.
# Refuses the production project name, requires --force, never prunes globally
# and only removes the project's built images when --remove-images is passed.
set -eu

cd "$(dirname "$0")/.."
. ./scripts/lib/compose-env.sh

env_file=.env
force=false
remove_images=false
while [ "$#" -gt 0 ]; do
    case "$1" in
        --env-file)
            [ "$#" -ge 2 ] || { echo "--env-file requires a path." >&2; exit 1; }
            env_file=$2
            shift 2
            ;;
        --force)
            force=true
            shift
            ;;
        --remove-images)
            remove_images=true
            shift
            ;;
        *) echo "Unknown argument: $1" >&2; exit 1 ;;
    esac
done

compose_init "$env_file" quiet
project="$(compose_env_value COMPOSE_PROJECT_NAME lms-moodle)"
[ "$project" != "lms-moodle" ] || {
    echo "ERROR: refusing to clean the production project 'lms-moodle'. Select a test or client project." >&2
    exit 1
}

containers="$(docker ps -a -q --filter "label=com.docker.compose.project=$project")"
volumes="$(docker volume ls -q --filter "label=com.docker.compose.project=$project")"

if [ "$remove_images" = true ] && [ "$force" != true ]; then
    echo 'ERROR: --remove-images always requires --force, including empty projects.' >&2
    exit 1
fi

remove_project_images() {
    namespace="$(compose_env_value IMAGE_NAMESPACE lms)"
    release_tag="$(compose_env_value RELEASE_IMAGE_TAG '')"
    if [ -n "$release_tag" ]; then
        for image in "$namespace/moodle-app:$release_tag" "$namespace/moodle-web:$release_tag"; do
            if docker image inspect "$image" >/dev/null 2>&1; then
                users=$(docker ps -a -q --filter "ancestor=$image")
                if [ -n "$users" ]; then
                    echo "ERROR: image $image is referenced by existing containers; preserving it." >&2
                    return 1
                fi
                docker image rm "$image" >/dev/null
                echo "Removed image $image"
            fi
        done
    fi
}

if [ -z "$containers" ] && [ -z "$volumes" ]; then
    if [ "$remove_images" = true ]; then
        remove_project_images
    fi
    echo "Nothing to clean for project $project."
    exit 0
fi

if [ "$force" != true ]; then
    echo "Project $project still owns these resources:" >&2
    [ -z "$containers" ] || docker ps -a --filter "label=com.docker.compose.project=$project" --format '  container {{.Names}}' >&2
    [ -z "$volumes" ] || printf '  volume %s\n' $volumes >&2
    echo "Re-run with --force to remove them and --remove-images to also drop the project's built images." >&2
    exit 1
fi

compose down -v --remove-orphans

remaining_containers="$(docker ps -a -q --filter "label=com.docker.compose.project=$project")"
[ -z "$remaining_containers" ] || { echo "ERROR: containers remain for project $project." >&2; exit 1; }
remaining_volumes="$(docker volume ls -q --filter "label=com.docker.compose.project=$project")"
[ -z "$remaining_volumes" ] || { echo "ERROR: volumes remain for project $project: $remaining_volumes" >&2; exit 1; }

if [ "$remove_images" = true ]; then
    remove_project_images
fi

echo "Project $project cleaned. Volumes and containers removed."
