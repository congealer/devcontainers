#!/bin/bash
#
# Run a template's test script inside the container build.sh left running.
#
#   ./test.sh <template-id>
#   KEEP=1 ./test.sh <template-id>    # leave the container and /tmp/<id> behind
#
# Cleanup hangs off an EXIT trap rather than sitting at the end of the script.
# With `set -e`, a failing test ended the script at the `devcontainer exec`
# line and the cleanup below it was never reached, so every failed run leaked a
# container. The trap runs either way and the failing exit code still
# propagates.
#
# `set -e` stays. `devcontainer exec` is the last command today, so the exit
# status would propagate without it -- but only for as long as that holds. It
# also covers anything above the exec failing.
#
# KEEP=1 is the escape hatch for debugging a template that will not go green:
# it keeps the container so it can be exec'd into by hand. build.sh wipes
# /tmp/<id> on its next run, so a kept directory does not poison a retry.

TEMPLATE_ID="$1"
set -e

SRC_DIR="/tmp/${TEMPLATE_ID}"
ID_LABEL="test-container=${TEMPLATE_ID}"

cleanup() {
    # Empty when the container is already gone; `docker rm -f` with no argument
    # is an error, hence the guard.
    docker rm -f $(docker container ls -f "label=${ID_LABEL}" -q) 2>/dev/null || true
    rm -rf "${SRC_DIR}"
}

if [ -n "${KEEP}" ] ; then
    echo "(!) KEEP is set -- leaving the container and ${SRC_DIR} in place"
    echo "(!) devcontainer exec --workspace-folder ${SRC_DIR} --id-label ${ID_LABEL} bash"
else
    trap cleanup EXIT
fi

echo "Running Smoke Test"

devcontainer exec --workspace-folder "${SRC_DIR}" --id-label ${ID_LABEL} /bin/sh -c 'set -e && if [ -f "test-project/test.sh" ]; then cd test-project && if [ "$(id -u)" = "0" ]; then chmod +x test.sh; else sudo chmod +x test.sh; fi && ./test.sh; else ls -a; fi'
