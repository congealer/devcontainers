#!/bin/bash
cd $(dirname "$0")
source test-utils.sh

# Template specific tests
check "distro" [ ! $(lsb_release -c | grep nobel) ]
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
