#!/bin/bash
#
# Smoke test for the rohd template. See test.md for what each check is for and,
# more importantly, what is deliberately left out.
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

# ---------------------------------------------------------------------------
# 1. Did the template render, and per the options?
# ---------------------------------------------------------------------------

# Substitution only runs for names declared in devcontainer-template.json, so a
# typo or a missing declaration leaves the placeholder untouched and ships it
# to the user verbatim.
no_leftover_placeholders() {
    ! grep -rlF '${templateOption:' "$P" \
        --exclude-dir=.dart_tool --exclude-dir=build --exclude-dir=test-project
}
check "no unsubstituted placeholders" no_leftover_placeholders

check "pubspec name is '${TEMPLATE_OPTION_projectName}'" \
      grep -qxF "name: ${TEMPLATE_OPTION_projectName}" "$P/pubspec.yaml"

check "pubspec description is '${TEMPLATE_OPTION_description}'" \
      grep -qxF "description: ${TEMPLATE_OPTION_description}" "$P/pubspec.yaml"

# `dart analyze` further down would also catch a wrong import, as an unresolved
# one. These stay because they put a name on the failure: "import in bin/..."
# reads better than the same fault buried in analyzer output.
for f in bin/generate_rtl.dart test/counter_test.dart ; do
    check "import in $f" \
          grep -qF "import 'package:${TEMPLATE_OPTION_projectName}/counter.dart';" "$P/$f"
done

# ---------------------------------------------------------------------------
# 2. Did the environment the template declares actually get built?
# ---------------------------------------------------------------------------

# Three things in one line: the local dart feature ran, the dartVersion option
# reached it, and the SDK is on the remote user's PATH. That last one is worth
# having -- install.sh runs as root, this test runs as the remote user, so a
# symlink landing outside the user's PATH would pass the build and fail here.
dart_version_matches() {
    dart --version 2>&1 | grep -qF "Dart SDK version: ${TEMPLATE_OPTION_dartVersion}"
}
check "dart is ${TEMPLATE_OPTION_dartVersion}" dart_version_matches

# prezto makes zsh the login shell.
login_shell_is_zsh() {
    case "$(getent passwd "$(id -un)" | cut -d: -f7)" in
        */zsh) return 0 ;;
        *)     return 1 ;;
    esac
}
check "login shell is zsh" login_shell_is_zsh

# Asserts on state rather than on what a command prints. `fzf --zsh` defines the
# widget functions, so their presence is the evidence that prezto's extraZshrc
# ran and that the fzf feature is installed.
#
# Deliberately not `bindkey "^R"`: with zsh-autosuggestions loaded the widget
# gets wrapped and the key binds to _zsh_autosuggest_bound_1_fzf-history-widget
# instead, which would fail a match on the plain name. The function is defined
# either way.
#
# `-i` is required because ~/.zshrc is only sourced for interactive shells.
# It works without a tty: non-interactive zsh does not see the function,
# interactive zsh does.
fzf_zsh_integration_loaded() {
    zsh -i -c '(( $+functions[fzf-history-widget] ))'
}
check "fzf zsh integration loaded" fzf_zsh_integration_loaded

# ---------------------------------------------------------------------------
# 3. Does the generated project start clean?
# ---------------------------------------------------------------------------

# `dart pub get` runs from the dart feature's updateContentCommand, and the CLI
# fails the build when a lifecycle command fails -- so under this harness the
# check below is not reached when pub get breaks. It is here to assert the end
# state directly instead of relying on that behaviour, which differs by client:
# the VS Code extension reports the failure and opens the container anyway.
# See "검출되지 않는 것" in test.md.
pub_get_resolved() {
    [ -f "$P/.dart_tool/package_config.json" ] \
        && grep -qF '"name": "rohd"' "$P/.dart_tool/package_config.json"
}
check "pub get resolved rohd" pub_get_resolved

# Exactly one, at the root. A second one under packages/ means the workspace
# wiring in pubspec.yaml (`workspace:` / `resolution: workspace`) broke and the
# sub-package resolved on its own.
one_package_config() {
    local n
    n=$(find "$P" -name package_config.json -not -path '*/build/*' | wc -l)
    [ "$n" -eq 1 ] || { echo "found $n package_config.json, expected 1"; return 1; }
}
check "single package_config.json" one_package_config

# Catches what only exists once the placeholders are substituted. The generated
# package name sorts unpredictably against rohd and rohd_patches, so an
# import-ordering lint would otherwise land on every project this template
# produces -- which is how that exact bug was found.
check "dart analyze" bash -c "cd '$P' && dart analyze"

reportResults
