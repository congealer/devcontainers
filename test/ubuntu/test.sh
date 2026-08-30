#!/bin/bash
#
# Smoke test for the ubuntu template.
#
# Runs inside the container build.sh created, from test-project/ within the
# rendered project; the project itself is one level up.
#
# No `set -e` on purpose: `check` collects failures so reportResults can list
# them all at once. See dev.md.

cd "$(dirname "$0")" || exit 1
source test-utils.sh

# The option values build.sh actually substituted, so checks can assert against
# how this template was configured rather than a hardcoded guess.
if [ -f ./template-options.env ] ; then
    source ./template-options.env
else
    echo "template-options.env missing -- build.sh did not write it" >&2
fi

P=..
CONFIG="$P/.devcontainer/devcontainer.json"

# The apt package each tool arrives in, and the command it provides. Three of
# the names differ, which is the whole reason this mapping is written out. The
# package column is checked against devcontainer.json at the end, so the tool
# list itself stays declared in one place.
TOOLS="
bat:batcat
lsd:lsd
fd-find:fdfind
ripgrep:rg
tig:tig
xxd:xxd
file:file
"

# ---------------------------------------------------------------------------
# 1. Did the template render, and per the options?
# ---------------------------------------------------------------------------

# Substitution only runs for names declared in devcontainer-template.json, so a
# typo or a missing declaration leaves the placeholder untouched and ships it to
# the user verbatim.
no_leftover_placeholders() {
    ! grep -rlF '${templateOption:' "$P" --exclude-dir=test-project
}
check "no unsubstituted placeholders" no_leftover_placeholders

# Doubles as a wiring test for imageVariant: the codename the container reports
# has to match the option the template was built with. If the option is declared
# but never substituted into devcontainer.json the two diverge -- which is
# exactly the state this template was in before the upstream re-apply.
check "distro is ${TEMPLATE_OPTION_imageVariant}" \
      [ "$(lsb_release -cs)" = "${TEMPLATE_OPTION_imageVariant}" ]

# ---------------------------------------------------------------------------
# 2. Is the base image carrying what the template stopped asking for?
#
# The common-utils feature was dropped because mcr.microsoft.com/devcontainers/
# base already applies it -- listing it again would install it twice. That makes
# it this template's assumption rather than something it declares, so these
# three checks are what hold the assumption up. remoteUser is not set either,
# so the user below comes from the image's own metadata.
# ---------------------------------------------------------------------------

check "running as a non-root user" bash -c '[ "$(id -u)" -ne 0 ]'
check "sudo works" sudo true
check "zsh installed" zsh --version

# ---------------------------------------------------------------------------
# 3. Did the environment the template declares actually get built?
# ---------------------------------------------------------------------------

# prezto makes zsh the login shell.
login_shell_is_zsh() {
    case "$(getent passwd "$(id -un)" | cut -d: -f7)" in
        */zsh) return 0 ;;
        *)     return 1 ;;
    esac
}
check "login shell is zsh" login_shell_is_zsh

# prezto backs up any existing ~/.zshrc and symlinks its own runcom in its place.
# That symlink is why `>> ~/.zshrc` is the wrong way to add anything here, so
# asserting on it is asserting on the reason extraZshrc exists.
#
# Not a check for the absence of ~/.oh-my-zsh: the base image installs it and it
# stays on disk. What matters is which of the two owns ~/.zshrc.
check "zshrc is a prezto runcom" [ -L "$HOME/.zshrc" ]
check "oh-my-zsh no longer owns zshrc" \
      bash -c '! readlink "$HOME/.zshrc" | grep -q oh-my-zsh'

# Asserts on state rather than on what a command prints. `fzf --zsh` defines the
# widget functions, so their presence is the evidence that prezto's extraZshrc
# ran and that the fzf feature is installed.
#
# Deliberately not `bindkey "^R"`: with zsh-autosuggestions loaded the widget
# gets wrapped and the key binds to _zsh_autosuggest_bound_1_fzf-history-widget
# instead, which would fail a match on the plain name. The function is defined
# either way.
#
# `-i` is required because ~/.zshrc is only sourced for interactive shells. It
# works without a tty: non-interactive zsh does not see the function,
# interactive zsh does.
fzf_zsh_integration_loaded() {
    zsh -i -c '(( $+functions[fzf-history-widget] ))'
}
check "fzf zsh integration loaded" fzf_zsh_integration_loaded

check "gh runs" gh --version

# `command -v` rather than running each tool: these come from the distro's own
# repository, so a package that installed has its dependencies and will start.
# What is actually worth catching is a wrong command name -- bat installs
# batcat, fd-find installs fdfind -- and a lookup catches that. Running them
# would mean a version flag per tool for no added coverage.
while IFS=: read -r pkg cmd ; do
    [ -n "$pkg" ] || continue
    check "$cmd on PATH (from $pkg)" command -v "$cmd"
done <<< "$TOOLS"

# TOOLS above only maps package to command; which packages get installed is
# declared in devcontainer.json. This fails if the two ever drift, so the list
# does not have to be maintained twice.
declared_packages() {
    sed -n '/"packages": \[/,/\]/p' "$CONFIG" \
        | grep -oE '"[a-z0-9+.-]+"' | tr -d '"' | grep -vx packages | sort
}
mapped_packages() {
    printf '%s\n' "$TOOLS" | cut -d: -f1 | grep -v '^$' | sort
}
tool_list_in_step() {
    diff <(declared_packages) <(mapped_packages)
}
check "tool list matches devcontainer.json" tool_list_in_step

reportResults
