# Wrapper around the scripts under script/ and the devcontainer CLI.
#
# There is no `devcontainer templates test` subcommand -- that exists only for
# Features -- so testing a template means building a container from it and
# running the template's own test.sh inside. The two scripts under script/ do
# that; this file only calls them, and CI calls this file, so a local run and a
# CI run take the same path.

NAMESPACE    ?= congealer/devcontainers
REGISTRY     ?= ghcr.io
DEVCONTAINER ?= devcontainer

TEMPLATES := $(notdir $(wildcard src/*))

BUILD := ./script/build.sh
TEST  := ./script/test.sh

# Catch a mistyped template id here rather than letting cp fail on it further
# down, where the error says nothing about what was actually wrong.
define require-template
$(if $(filter $(1),$(TEMPLATES)),,\
	$(error unknown template '$(1)'. available: $(TEMPLATES)))
endef

.DEFAULT_GOAL := help
.PHONY: help build test prepare release-check docs release clean distclean

# build-% is a prerequisite of test-%, so make would treat it as an
# intermediate file and try to delete it afterwards. Nothing of that name
# exists, but the attempted `rm` shows up in every run.
.PRECIOUS: build-%

help:  ## Show this help
	@grep -hE '^[a-z][a-z%-]*:.*##' $(MAKEFILE_LIST) | sed -E 's/:[^#]*## /\t/' | expand -t 22
	@echo
	@echo "templates: $(TEMPLATES)"

# A failing template does not stop the loop -- one broken template should not
# hide the state of the others -- but it does have to reach the exit code. A
# bare `for` would report the status of the last template only, so `make test`
# would come back green with an earlier one failing. CI does not rely on this:
# its matrix calls test-<id> per job.
build:  ## Build a container for every template under src/
	@rc=0 ; for t in $(TEMPLATES) ; do \
	    $(MAKE) --no-print-directory build-$$t || rc=1 ; \
	done ; exit $$rc

test:  ## Build and test every template under src/
	@rc=0 ; for t in $(TEMPLATES) ; do \
	    $(MAKE) --no-print-directory test-$$t || rc=1 ; \
	done ; exit $$rc

# Option values default to each option's `default`. Override them the way
# `devcontainer templates apply -a` takes them:
#
#   make build-rohd TEMPLATE_ARGS='{"projectName":"zzz_top"}'
build-%:  ## One template: render it and bring the container up
	$(call require-template,$*)
	$(BUILD) $*

# Depends on the build so `make test-rohd` alone works. Run build-% separately
# when iterating: the container stays up between test runs as long as the test
# passes with KEEP=1.
#
#   make test-rohd KEEP=1
test-%: build-%  ## One template: run its test.sh in the container, then tear down
	$(TEST) $*

prepare:  ## Pick a template and bump its version, then refresh the docs
	@./prepare.py

# A prerequisite of release rather than advice in a comment: publishing a
# template whose version is already up there is a no-op the CLI reports with a
# warning and exit code 0, so nothing else would catch it.
release-check:  ## Fail if a template changed since its version was committed
	@./prepare.py --check

# '-p' wants the folder the templates live in, despite the help text calling it
# the project root that holds src/ and test/. Given '.' it walks every child of
# the repository root -- test/, dev.md and all -- looking for a
# devcontainer-template.json. There is no --namespace either; owner and repo
# are separate flags.
docs:  ## Regenerate every src/<template>/README.md from its metadata and NOTES.md
	$(DEVCONTAINER) templates generate-docs -p src \
	    --github-owner $(word 1,$(subst /, ,$(NAMESPACE))) \
	    --github-repo $(word 2,$(subst /, ,$(NAMESPACE)))

# Publishes with your own credentials when run locally; the release workflow
# runs this same target so both paths go through release-check. A version that
# is already published is skipped, so this uploads whatever template had its
# version bumped and nothing else.
release: release-check  ## Publish every template under src/ to the registry
	@gh auth status > /dev/null 2>&1 \
	    || { echo "gh is not logged in - run 'gh auth login'"; exit 1; }
	GITHUB_TOKEN=$$(gh auth token) $(DEVCONTAINER) templates publish \
	    -r $(REGISTRY) -n $(NAMESPACE) ./src

clean:  ## Remove what the runs left behind, for every template
	$(BUILD) clean

clean-%:  ## The same, for one template
	$(call require-template,$*)
	$(BUILD) clean $*

# Back to the state before any test ever ran, so the next one downloads the
# base images again. `clean` has already removed the containers and the build
# cache, so everything still here is unreferenced and goes -- no need to know
# what the templates pull, or to keep a list of it in step with them.
distclean: clean  ## Also drop the base images
	@docker image prune -af
