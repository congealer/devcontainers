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

TEMPLATE_ID="$1"

set -e

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

# A previous run may have been kept for inspection (KEEP=1 in test.sh). Without
# this, `cp -R` would nest the template inside the stale directory.
rm -rf "${SRC_DIR}"
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
echo "(*) Installing @devcontainer/cli"
npm install -g @devcontainers/cli

echo "Building Dev Container"
ID_LABEL="test-container=${TEMPLATE_ID}"
devcontainer up --id-label ${ID_LABEL} --workspace-folder "${SRC_DIR}"
