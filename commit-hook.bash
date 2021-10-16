#!/usr/bin/env bash
#---------------------------------------------------------------------------------------------
# Purpose: commit-hook.sh is used to run pre-PR publish steps. It performs three primary functions:
# - Runs all bats tests on shellmock
# - Runs all bats tests on the sample-bats
# - Runs shellcheck against the code and fails if lint errors are found.
#---------------------------------------------------------------------------------------------

set -e

lint() {
    echo "INFO: Linting $1"
    if ! shellcheck -s bash -x "$1"; then
        echo "ERROR: shellcheck of $1 has errors"
        exit 1
    fi
}

echo -n "Starting: "
date +%Y-%m-%dT%H:%M:%S%z
lint commit-hook.bash
lint load.bash
lint src/shellmock.bash
lint test/shellmock.bats
lint test/test_helper.bash
lint test/test.bash

if [[ ! -d node_modules ]]; then
  echo "INFO: NPM Installing dependencies"
  npm install
fi
echo "INFO: Running bats tests"
npm test
