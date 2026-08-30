#!/bin/bash
#
# Build a dev container from a template, as a consumer would get it.
#
#   ./build.sh <template-id>
#
# Option values default to the `default` in devcontainer-template.json. Override
# them with TEMPLATE_ARGS, in the same JSON shape `devcontainer templates apply`
# takes for -a/--template-args:
#
#   TEMPLATE_ARGS='{"imageVariant":"jammy"}' ./build.sh ubuntu
#
# The resolved values are written to test-project/template-options.env so the
# test script can assert against them. Substitution only touches the template
# body -- the test folder is copied in afterwards, so `${templateOption:...}`
# inside a test script is never replaced.

set -e

# Cleanup lives here because this script is what decides the names: the
# workspace folder set below becomes the image name `devcontainer up` builds,
# so matching on that name anywhere else would repeat a convention it does not
# own.
#
#   ./build.sh clean           what a run leaves behind, for every template
#   ./build.sh clean <id>      the same, for one of them
#
# test.sh drops its container on the way out but never the image, because
# dropping it would make the next run rebuild from scratch. That is why images
# pile up and why this exists.
if [ "$1" = "clean" ] ; then
    for t in ${2:-$(ls src)} ; do
        docker ps -aq --filter "label=test-container=${t}" | xargs -r docker rm -f
        docker images -q --filter "reference=vsc-${t}-*-features" \
                         --filter "reference=vsc-${t}-*-features-uid" \
            | xargs -r docker rmi -f
        rm -rf "/tmp/${t}"
    done

    # Not optional. Removing the images leaves buildkit holding snapshots that
    # reference them, and the next build dies on "parent snapshot ... does not
    # exist" until the cache goes too. -a rather than dangling-only because
    # that is what was seen to clear it; whether -f alone suffices is untested.
    docker builder prune -af
    exit 0
fi

TEMPLATE_ID="$1"

shopt -s dotglob

# Validated up front: a typo here would otherwise fall back to the defaults and
# the run would look like it had honoured the override.
if [ -z "${TEMPLATE_ARGS}" ] ; then
    TEMPLATE_ARGS='{}'
elif ! jq -e 'type == "object"' >/dev/null 2>&1 <<<"${TEMPLATE_ARGS}" ; then
    echo "TEMPLATE_ARGS is not a JSON object: ${TEMPLATE_ARGS}" >&2
    exit 1
fi

SRC_DIR="/tmp/${TEMPLATE_ID}"
ID_LABEL="test-container=${TEMPLATE_ID}"

# A previous run may have been kept for inspection (KEEP=1 in test.sh). Both
# halves of what it left have to go, unconditionally -- KEEP means "leave it up
# after the test", not "reuse it next time".
#
# The directory, or `cp -R` would nest the template inside the stale one. And
# the container, or `devcontainer up` would adopt it rather than create one,
# leaving its bind mount pointing at the directory just deleted. `exec` then
# fails with "current working directory is outside of container mount namespace
# root", which reads like a docker fault rather than a stale container.
rm -rf "${SRC_DIR}"
docker ps -aq --filter "label=${ID_LABEL}" | xargs -r docker rm -f > /dev/null

cp -R "src/${TEMPLATE_ID}" "${SRC_DIR}"

# Collected as `name=value` lines while substituting, written out once the test
# folder exists.
RESOLVED_OPTIONS=()

pushd "${SRC_DIR}"

# Configure templates only if `devcontainer-template.json` contains the `options` property.
OPTION_PROPERTY=( $(jq -r '.options' devcontainer-template.json) )

if [ "${OPTION_PROPERTY}" != "" ] && [ "${OPTION_PROPERTY}" != "null" ] ; then
    OPTIONS=( $(jq -r '.options | keys[]' devcontainer-template.json) )

    if [ "${OPTIONS[0]}" != "" ] && [ "${OPTIONS[0]}" != "null" ] ; then
        echo "(!) Configuring template options for '${TEMPLATE_ID}'"
        for OPTION in "${OPTIONS[@]}"
        do
            OPTION_KEY="\${templateOption:$OPTION}"

            # TEMPLATE_ARGS wins over the declared default when it carries this key.
            OPTION_VALUE=$(jq -r --arg k "${OPTION}" '.[$k] // empty' <<<"${TEMPLATE_ARGS}")
            if [ -z "${OPTION_VALUE}" ] ; then
                OPTION_VALUE=$(jq -r ".options | .${OPTION} | .default" devcontainer-template.json)
            else
                echo "(!) Option '${OPTION}' overridden by TEMPLATE_ARGS"
            fi

            if [ "${OPTION_VALUE}" = "" ] || [ "${OPTION_VALUE}" = "null" ] ; then
                echo "Template '${TEMPLATE_ID}' is missing a default value for option '${OPTION}'"
                exit 1
            fi

            echo "(!) Replacing '${OPTION_KEY}' with '${OPTION_VALUE}'"
            OPTION_VALUE_ESCAPED=$(sed -e 's/[]\/$*.^[]/\\&/g' <<<"${OPTION_VALUE}")
            find ./ -type f -print0 | xargs -0 sed -i "s/${OPTION_KEY}/${OPTION_VALUE_ESCAPED}/g"

            RESOLVED_OPTIONS+=( "$(printf 'TEMPLATE_OPTION_%s=%q' "${OPTION}" "${OPTION_VALUE}")" )
        done
    fi
fi

popd

TEST_DIR="test/${TEMPLATE_ID}"
if [ -d "${TEST_DIR}" ] ; then
    echo "(*) Copying test folder"
    DEST_DIR="${SRC_DIR}/test-project"
    mkdir -p ${DEST_DIR}
    cp -Rp ${TEST_DIR}/* ${DEST_DIR}
    cp -Rp test/test-utils/* ${DEST_DIR}

    # Always written, even with no options, so `source` in a test script does
    # not have to guard on the file existing.
    echo "(*) Writing resolved options to test-project/template-options.env"
    printf '%s\n' "${RESOLVED_OPTIONS[@]}" > "${DEST_DIR}/template-options.env"
fi

export DOCKER_BUILDKIT=1

echo "Building Dev Container"
devcontainer up --id-label ${ID_LABEL} --workspace-folder "${SRC_DIR}"
