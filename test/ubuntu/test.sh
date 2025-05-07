#!/bin/bash
cd $(dirname "$0")
source test-utils.sh

# Template specific tests
check "distro1" [ ! $(lsb_release -c | grep nobel) ]

# Report result
reportResults
