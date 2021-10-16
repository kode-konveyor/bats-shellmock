#!/usr/bin/env bats
#shellcheck disable=SC2030,SC2031

load test_helper
#---------------------------------------------------------------------
# File: shellmock.bats
# Purpose:
#     This is a bats testing script that is used to test the features
#     of the mock framework itself.
#
#     You can run the tests via:  bats shellmock.bats
#---------------------------------------------------------------------
setup() {
  skipIfNot "$BATS_TEST_DESCRIPTION"
  shellmock_clean
  TEST_TEMP_DIR="$(temp_make)"
  cd "${TEST_TEMP_DIR}" || exit
  unset SHELLMOCK_V1_COMPATIBILITY
  export BATSLIB_TEMP_PRESERVE_ON_FAILURE=1
}

teardown() {
  if [ -z "$TEST_FUNCTION" ]; then
    shellmock_clean
    temp_del "$TEST_TEMP_DIR"
  else
    echo Single Test Keeping
    echo stubs: "${BATS_TEST_DESCRIPTION}/${TEMP_STUBS}"
    echo and TEST_TEMP_DIR: "${TEST_TEMP_DIR}"
  fi
}

@test "shellmock_expect --status 0" {

  shellmock_expect cp --status 0 --match "a b" --output "mock a b success"

  run cp a b
  assert_success
  assert_output "mock a b success"

  shellmock_verify
  shellmock_verify_times 1
  shellmock_verify_command 0 'cp-stub a b'
}

@test "shellmock_expect --status 1" {

  shellmock_expect cp --status 1 --match "a b" --output "mock a b failed"

  run cp a b
  assert_failure 1
  assert_output "mock a b failed"

  shellmock_verify
  shellmock_verify_times 1
  shellmock_verify_command 0 'cp-stub a b'
}

@test "shellmock_expect-multiple-responses" {

  shellmock_expect cp --status 0 --match "a b" --output "mock a b success"
  shellmock_expect cp --status 1 --match "a b" --output "mock a b failed"

  run cp a b
  assert_success
  assert_output "mock a b success"

  run cp a b
  assert_failure 1
  assert_output "mock a b failed"

  # not a match
  run cp a c
  assert_failure 99

  shellmock_verify
  shellmock_verify_times 3
  shellmock_verify_command 0 'cp-stub a b'
  shellmock_verify_command 1 'cp-stub a b'
  shellmock_verify_command 2 'cp-stub a c'
}

@test "shellmock_expect --status 0 partial-match" {

  shellmock_expect cp --status 0 --type partial --match "a" --output "mock success"

  run cp a b
  assert_success
  assert_output "mock success"

  run cp a c
  assert_success
  assert_output "mock success"

  shellmock_verify
  shellmock_verify_times 2
  shellmock_verify_command 0 'cp-stub a b'
  shellmock_verify_command 1 'cp-stub a c'
}

@test "shellmock_expect --status 0 partial-match with double quotes" {

  shellmock_expect cp --status 0 --type partial --match '"a file.c"' --output "mock success"

  run cp "a file.c" b
  assert_success
  assert_output "mock success"

  run cp "a file.c" c
  assert_success
  assert_output "mock success"

  shellmock_verify
  shellmock_verify_times 2
  shellmock_verify_command 0 'cp-stub "a file.c" b'
  shellmock_verify_command 1 'cp-stub "a file.c" c'
}

@test "shellmock_expect --status 0 partial-match with single quotes" {

  shellmock_expect cp --status 0 --type partial --match "'a file.c'" --output "mock success"

  run cp 'a file.c' b
  assert_success
  assert_output "mock success"

  run cp 'a file.c' c
  assert_success
  assert_output "mock success"

  # Because the input parameters into the mock are normalized the single
  # quotes will appear as double quotes in the shellmock.out file.

  shellmock_verify
  shellmock_verify_times 2
  shellmock_verify_command 0 'cp-stub "a file.c" b'
  shellmock_verify_command 1 'cp-stub "a file.c" c'
}

@test "shellmock_expect failed matches" {

  shellmock_expect cp --status 0 --type exact --match "a b" --output "mock a b success"

  run cp a b
  assert_success
  assert_output "mock a b success"

  run cp a c
  assert_failure 99

  grep 'No record match found stdin:\*\* cmd:cp args:\*a c\*' "${SHELLMOCK_CAPTURE_ERR}"

  shellmock_verify
  shellmock_verify_times 2
  shellmock_verify_command 0 'cp-stub a b'
  shellmock_verify_command 1 'cp-stub a c'
}

@test "shellmock_expect failed partial matches" {
  shellmock_expect cp --status 0 --type partial --match "a" --output "mock success"

  run cp a b
  assert_success
  assert_output "mock success"

  run cp a c
  assert_success
  assert_output "mock success"

  run cp b b
  assert_failure
  grep 'No record match found stdin:\*\* cmd:cp args:\*b b\*' "${SHELLMOCK_CAPTURE_ERR}"

  shellmock_verify
  shellmock_verify_times 3
  shellmock_verify_command 0 'cp-stub a b'
  shellmock_verify_command 1 'cp-stub a c'
  shellmock_verify_command 2 'cp-stub b b'
}

@test "shellmock_expect execute on match" {

  shellmock_expect cp --status 0 --type exact --match "a b" --exec "echo executed."

  run cp a b
  assert_success
  assert_output "executed."

  shellmock_verify
  shellmock_verify_times "1"
  shellmock_verify_command 0 'cp-stub a b'
}

@test "shellmock_expect execute on match args with double quotes" {

  shellmock_expect cp --status 0 --type exact --match '"a b.c" b' --exec "echo executed."

  run cp "a b.c" b
  assert_success
  assert_output "executed."

  shellmock_verify
  shellmock_verify_times "1"
  shellmock_verify_command 0 'cp-stub "a b.c" b'
}

@test "shellmock_expect execute on match args with single quotes" {

  shellmock_expect cp --status 0 --type exact --match "'a b.c' b" --exec "echo executed."

  run cp 'a b.c' b
  assert_success
  assert_output "executed."

  # Single quotes will be converted to double quotes when the arguments are normalized.
  # so match on double quotes instead.

  shellmock_verify
  shellmock_verify_times "1"
  shellmock_verify_command 0 'cp-stub "a b.c" b'
}

@test "shellmock_expect execute on partial match" {

  shellmock_expect cp --status 0 --type partial --match "a" --exec "echo executed."

  run cp a b
  assert_success
  assert_output "executed."

  run cp a c
  assert_success
  assert_output "executed."

  shellmock_verify
  shellmock_verify_times "2"
  shellmock_verify_command 0 'cp-stub a b'
  shellmock_verify_command 1 'cp-stub a c'
}

@test "shellmock_expect execute on match with {} substitution" {

  shellmock_expect cp --status 0 --type exact --match "a b" --exec "echo t1 {} tn"

  run cp a b
  assert_success
  assert_output "t1 a b tn"

  shellmock_verify
  shellmock_verify_times "1"
  shellmock_verify_command 0 'cp-stub a b'
}

@test "shellmock_expect source" {

  shellmock_expect source-test.bash --status 0 --type exact --match "" --source "${BATS_TEST_DIRNAME}/test.bash"

  #shellcheck disable=SC1091
  . source-test.bash

  assert_equal "${TEST_PROP}" "test-prop"

  shellmock_verify
  shellmock_verify_times "1"
  shellmock_verify_command 0 'source-test.bash-stub'
}

@test "shellmock_expect multiple responses" {
  shellmock_expect cp --status 0 --match "a b" --output "mock a b success"
  shellmock_expect cp --status 1 --match "a b" --output "mock a b failed"

  run cp a b
  assert_output "mock a b success"
  assert_success

  run cp a b
  assert_failure 1
  assert_output "mock a b failed"

  # not a match
  run cp a c
  assert_failure 99

  shellmock_verify
  shellmock_verify_times "3"
  shellmock_verify_command 0 'cp-stub a b'
  shellmock_verify_command 1 'cp-stub a b'
  shellmock_verify_command 2 'cp-stub a c'
}

@test "shellmock_clean inside directory with spaces" {

  export TEMP_SUB_DIR="$TEST_TEMP_DIR/temp dir"
  mkdir -p "$TEMP_SUB_DIR/${TEMP_STUBS}"
  export BATS_TEST_DIRNAME="$TEMP_SUB_DIR"
  export CAPTURE_FILE="$BATS_TEST_DIRNAME/${TEMP_STUBS}/shellmock.out"
  export SHELLMOCK_CAPTURE_ERR="$BATS_TEST_DIRNAME/${TEMP_STUBS}/shellmock.err"
  export PATH="$BATS_TEST_DIRNAME/${TEMP_STUBS}:$PATH"

  touch "$CAPTURE_FILE"
  touch "${SHELLMOCK_CAPTURE_ERR}"
  mkdir -p "$BATS_TEST_DIRNAME/${TEMP_STUBS}"

  shellmock_clean
  [ ! -f "$CAPTURE_FILE" ]
  [ ! -f "${SHELLMOCK_CAPTURE_ERR}" ]
  [ ! -d "$BATS_TEST_DIRNAME/${TEMP_STUBS}" ]
}

@test "shellmock_expect inside directory with spaces" {

  shellmock_expect cp --exec "echo executed."

  run cp
  assert_success
  assert_output "executed."
  assert_file_exist "${CAPTURE_FILE}"
  assert_dir_exist "${BATS_TEST_DIRNAME}/${TEMP_STUBS}"

  #shellcheck disable=SC2031
  export TEMP_SUB_DIR="${TEST_TEMP_DIR}/temp dir"
  mkdir -p "${TEMP_SUB_DIR}/${TEMP_STUBS}"

  #shellcheck disable=SC2031
  mv "${BATS_TEST_DIRNAME}/${TEMP_STUBS}" "${TEMP_SUB_DIR}"

  #shellcheck disable=SC2031
  export BATS_TEST_DIRNAME="${TEMP_SUB_DIR}"

  #shellcheck disable=SC2031
  export CAPTURE_FILE="${BATS_TEST_DIRNAME}/${TEMP_STUBS}/shellmock.out"

  shellmock_verify
  shellmock_verify_times 1
  shellmock_verify_command 0 "cp-stub"
}

@test "shellmock_verify inside directory with spaces" {

  shellmock_expect cp --exec "echo executed."

  run cp
  assert_success
  assert_output "executed."
  assert_file_exist "${CAPTURE_FILE}"
  assert_dir_exist "${BATS_TEST_DIRNAME}/${TEMP_STUBS}"

  #shellcheck disable=SC2031
  export TEMP_SUB_DIR="${TEST_TEMP_DIR}/temp dir"
  mkdir -p "${TEMP_SUB_DIR}/${TEMP_STUBS}"

  #shellcheck disable=SC2031
  mv "${BATS_TEST_DIRNAME}/${TEMP_STUBS}" "${TEMP_SUB_DIR}"

  #shellcheck disable=SC2031
  export BATS_TEST_DIRNAME="${TEMP_SUB_DIR}"

  #shellcheck disable=SC2031
  export CAPTURE_FILE="${BATS_TEST_DIRNAME}/${TEMP_STUBS}/shellmock.out"

  shellmock_verify
  shellmock_verify_times 1
  shellmock_verify_command 0 "cp-stub"
}

@test "shellmock_expect --match '--version'" {

  shellmock_expect foo --match "--version" --output "Foo version"

  run foo --version
  assert_success
  assert_output "Foo version"

  shellmock_verify
  shellmock_verify_times 1
  shellmock_verify_command 0 "foo-stub --version"
}

@test "shellmock_expect --status 0 regex-match" {

  shellmock_expect cp --status 0 --type regex --match "-a -s script\(\'t.*\'\)" --output "mock success"

  run cp -a -s "script('testit')"
  assert_success
  assert_output "mock success"

  run cp -a -s "script('testit2')"

  assert_success
  assert_output "mock success"

  run cp -a -s "script('Testit2')"
  assert_failure 99

  shellmock_verify
  shellmock_verify_times 3
  shellmock_verify_command 0 "cp-stub -a -s script('testit')"
  shellmock_verify_command 1 "cp-stub -a -s script('testit2')"
  shellmock_verify_command 2 "cp-stub -a -s script('Testit2')"
}

@test "shellmock_expect quotes compatibility test" {

  export SHELLMOCK_V1_COMPATIBILITY="enabled"

  shellmock_expect cp --status 0 --match "a b c" --output "mock a b success"

  run cp "a b" c
  assert_success
  assert_output "mock a b success"

  shellmock_verify
  shellmock_verify_command 0 "cp-stub a b c"
}

@test "shellmock_expect --status 0 with stdin" {

  #---------------------------------------------------------------
  # Had issues getting the run echo "a b" | cat to work so
  # I used the exec feature to create stubs to invoke the cat-stub
  #---------------------------------------------------------------
  shellmock_expect helper --status 0 --match "a b" --exec 'echo a b | cat'
  shellmock_expect helper --status 0 --match "a c" --exec 'echo a c | cat'

  shellmock_expect cat --status 0 --match-stdin "a b" --output "mock success"

  run helper a b
  assert_success
  assert_output "mock success"

  run helper a c
  assert_failure 99

  shellmock_verify
  shellmock_verify_times 4
  shellmock_verify_command 0 'helper-stub a b'
  shellmock_verify_command 1 'a b | cat-stub'
  shellmock_verify_command 2 'helper-stub a c'
  shellmock_verify_command 3 'a c | cat-stub'
}

@test "shellmock_expect --status 0 with stdin and args" {

  #---------------------------------------------------------------
  # Had issues getting the run echo "a b" | cat to work so
  # I used the exec feature to create stubs to invoke the cat-stub
  #---------------------------------------------------------------
  shellmock_expect helper --status 0 --match "a b" --exec 'echo a b | cat -t -v'
  shellmock_expect helper --status 0 --match "a b" --exec 'echo a b | cat -p -q'

  shellmock_expect cat --status 0 --match-args "-t -v" --match-stdin "a b" --output "mock success"

  run helper a b
  assert_success
  assert_output "mock success"

  run helper a b
  assert_failure 99

  shellmock_verify
  shellmock_verify_times 4
  shellmock_verify_command 0 'helper-stub a b'
  shellmock_verify_command 1 'a b | cat-stub -t -v'
  shellmock_verify_command 2 'helper-stub a b'
  shellmock_verify_command 3 'a b | cat-stub -p -q'
}

@test "shellmock_expect --status 0 with stdin and args multi-response" {

  #---------------------------------------------------------------
  # Had issues getting the run echo "a b" | cat to work so
  # I used the exec feature to create stubs to invoke the cat-stub
  #---------------------------------------------------------------
  shellmock_expect helper --status 0 --match "a b" --exec 'echo a b | cat -t -v'
  shellmock_expect helper --status 0 --match "a b" --exec 'echo a b | cat -p -q'
  shellmock_expect helper --status 0 --match "a b" --exec 'echo a b | cat -t -v'

  shellmock_expect cat --status 0 --match-args "-t -v" --match-stdin "a b" --output "mock success 1"
  shellmock_expect cat --status 0 --match-args "-t -v" --match-stdin "a b" --output "mock success 2"

  run helper a b
  assert_success
  assert_output "mock success 1"

  run helper a b
  assert_failure

  run helper a b
  assert_success
  assert_output "mock success 2"

  shellmock_verify
  shellmock_verify_times 6
  shellmock_verify_command 0 'helper-stub a b'
  shellmock_verify_command 1 'a b | cat-stub -t -v'
  shellmock_verify_command 2 'helper-stub a b'
  shellmock_verify_command 3 'a b | cat-stub -p -q'
  shellmock_verify_command 4 'helper-stub a b'
  shellmock_verify_command 5 'a b | cat-stub -t -v'
}

@test "shellmock_expect --status 0 with stdin and regex" {

  #---------------------------------------------------------------
  # Had issues getting the run echo "a b" | cat to work so
  # I used the exec feature to create stubs to invoke the cat-stub
  #---------------------------------------------------------------
  shellmock_expect helper --status 0 --match "a b" --exec 'echo a b | cat'
  shellmock_expect helper --status 0 --match "a c" --exec 'echo a c | cat'

  shellmock_expect cat --status 0 --stdin-match-type regex --match-stdin "a.*" --output "mock success"

  run helper a b
  assert_success
  assert_output "mock success"

  run helper a c
  assert_success
  assert_output "mock success"

  shellmock_verify
  shellmock_verify_times 4
  shellmock_verify_command 0 'helper-stub a b'
  shellmock_verify_command 1 'a b | cat-stub'
  shellmock_verify_command 2 'helper-stub a c'
  shellmock_verify_command 3 'a c | cat-stub'
}

@test "shellmock_expect --status 0 with stdin partial match" {

  #---------------------------------------------------------------
  # Had issues getting the run echo "a b" | cat to work so
  # I used the exec feature to create stubs to invoke the cat-stub
  #---------------------------------------------------------------
  shellmock_expect helper --status 0 --match "a b" --exec 'echo a b | cat'
  shellmock_expect helper --status 0 --match "a c" --exec 'echo a c | cat'

  shellmock_expect cat --status 0 --stdin-match-type regex --match-stdin "a" --output "mock success"

  run helper a b
  assert_success
  assert_output "mock success"

  run helper a c
  assert_success
  assert_output "mock success"

  shellmock_verify
  shellmock_verify_times 4
  shellmock_verify_command 0 'helper-stub a b'
  shellmock_verify_command 1 'a b | cat-stub'
  shellmock_verify_command 2 'helper-stub a c'
  shellmock_verify_command 3 'a c | cat-stub'
}
