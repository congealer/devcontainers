#!/bin/bash
cd $(dirname "$0")
source test-utils.sh

# The option values build.sh actually substituted, so checks can assert against
# how the template was configured instead of a hardcoded guess.
if [ -f ./template-options.env ] ; then
    source ./template-options.env
else
    echo "template-options.env missing -- build.sh did not write it" >&2
fi

# Template specific tests

# Doubles as a wiring test for imageVariant: the codename the container reports
# has to match the option the template was built with. If the option is
# declared but never substituted into devcontainer.json, the two diverge.
check "distro is ${TEMPLATE_OPTION_imageVariant}" \
      [ "$(lsb_release -cs)" = "${TEMPLATE_OPTION_imageVariant}" ]
check "fzf key-binding" grep -q "source <(fzf --zsh)" ~/.zshrc


REQUIRED_TOOLS="vim gvim git-lfs gh batcat lsd fdfind rg tig tldr xxd bc"
MISSING_TOOLS=""
for tool in $REQUIRED_TOOLS; do
  if ! which $tool >/dev/null 2>&1; then
    MISSING_TOOLS="$MISSING_TOOLS $tool"
  fi
done
check "utility installed" [ -z "$MISSING_TOOLS" ] || echo "Missing tools:$MISSING_TOOLS"


# Report result
reportResults
