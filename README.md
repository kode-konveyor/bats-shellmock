![BASH](https://raw.githubusercontent.com/odb/official-bash-logo/master/assets/Logos/Identity/PNG/BASH_logo-transparent-bg-color.png)

# Bats Shell Mock

## Overview

**Shellmock** is a bash shell script mocking utility/framework. It was written to be a companion of the [Bash Automated Testing System](https://github.com/bats-core/bats-core).

Typically, mocking frameworks return certain outputs when particular inputs are provided. When enabling mocks for scripts, **Shellmock** defines the "input" as the command line arguments to the script and it defines the "output" as the exit status and any standard output. In addition it will allow you to provide an alternate stubbed behavior. In most testing scenarios just knowing what was called and the command line args is sufficient, but some advanced test cases may require new behavior.

Given the bash command "cp file1 file2", a stub might be defined to return status 0. The stub could also echo "cp file1 file2" to standard out. Using Bats **status**, **line** or **output** variables you can verify that "cp file1 file2" was written which would confirm that the script was called. The example below is a snippet from a **bats** script. It is assumed that **mycmd** is the script being tested and it calls "cp file1 file2" during its execution.

```bash
run mycmd
[ "${status}" = "0" ]
[ "${line[0]}" = "cp file1 file2" ]
```

One approach for stubbing is to create bash scripts with the same names as the real scripts or programs and then override the **PATH** to the stubs and there by short circuiting the real path. Depending on the number of scripts to stub this can be taxing and the stubbing logic can become complex. This is where **Shellmock** helps. **Shellmock** lets you define the mocks inline within the **bats** tests. It creates and manages the stub scripts behind the scenes. The added benefit is that you can view the tests and the test data together making tests easier to manage.

## Enabling Mocks in your Bats tests

The first step is to source **shellmock** in the **setup()** function and call the **shellmock\_cleanup** function from the bats **teardown** function. These two steps will make **shellmock** functions available to your testcases and perform appropriate cleanup in between tests.

Adding the **skipIfNot** function in **setup()** will help with troubleshooting. This will allow users to define the **TEST\_FUNCTION** environment variable to run a single test or a subset of tests and turn on the associated debug logs.

```bash
# Source the shellmock functions into the shell.
. shellmock

setup() {
  skipIfNot "$BATS_TEST_DESCRIPTION"
  shellmock_clean
}

teardown() {
  if [ -z "$TEST_FUNCTION" ]; then
    shellmock_clean
  else
    echo Single Test Keeping stubs: "${BATS_TEST_DESCRIPTION}/${TEMP_STUBS}"
  fi
}
```

## Environment Variables

<table><colgroup><col style="width: 50%" /><col style="width: 50%" /></colgroup><tbody><tr class="odd"><td style="text-align: left;"><p>Name</p></td><td style="text-align: left;"><p>Purpose</p></td></tr><tr class="even"><td style="text-align: left;"><p>TEST_FUNCTION</p></td><td style="text-align: left;"><p>Shellmock variable that is used to run single tests and control debugging output in shellmock. When set to the name of a test case then all tmp and debug output is preserved after the test completes. If you give each test a unique name then only that one test will be executed. You have to leverage the <strong>skipIfNot</strong> function in <strong>setup</strong> or in the test case to take advantage of the feature.</p></td></tr><tr class="odd"><td style="text-align: left;"><p>SHELLMOCK_V1_COMPATIBILITY</p></td><td style="text-align: left;"><p>v1.2 introduced logic that handles matching arguments differently when they contain spaces. As a result old tests could fail to match. This flag allows the old tests to continue to pass.</p></td></tr></tbody></table>

## Adding Mocks in one of your tests

In the `sample.sh` script below, the status code from **grep** is used to control the logic flow of the script. We can use Shellmock’s **shellmock\_expect** command to simulate various success and failures scenarios depending on the arguments passed into the **grep** command.

**sample.sh**

```bash
echo "sample line" > sample.out

grep "sample line" sample.out > /dev/null
if [ $? -ne 0 ]; then
    echo "sample not found"
    exit 1
fi

echo "sample found"
```

In the sections that follow we will create some test cases against **sample.sh**.

### Success Scenario using exact matching

This testcase is simply using bats and calling the real **grep** command. No mocking was involved. This was included to show that testcases can be a mixture of mocks and real commands.

```bash
@test "sample.sh-success" {

    run ./sample.sh

    [ "$status" = "0" ]

    # Validate using lines array.
    [ "${lines[0]}" = "sample found" ]

    # Optionally since this is a single line you can use $output
    [ "$output" = "sample found" ]
}
```

### Failure Scenario using exact matching

In this failure scenario we are creating a stub that will return a status of 1 if the **grep** is called in one of the two ways below:

```
grep "sample line" sample.out.

or

grep *sample line* sample.out

These will look the same in the stub’s input args.
```

The testcase is using the default match type which is an exact match.

```bash
@test "sample.sh-failure" {

    shellmock_expect grep --status 1 --match '"sample line" sample.out'

    shellmock_debug "starting the test"

    run ./sample.sh

    # Only significant when debugging is occurring it captures bats variables to output files
    # to make it easier to see what you are missing.
    shellmock_dump

    [ "$status" = "1" ]
    [ "$output" = "sample not found" ]

    # called to create the capture array to allow expect verifications.
    shellmock_verify
    shellmock_verify_command 0 'grep-stub "sample line" sample.out'
}
```

After the status and output of the script has been validated as needed, then the final piece is to verify that all of the expected mocks were called. The function **shellmock\_verify** reads the **shellmock.out** file which contains a record of all mock invocations. The lines of the file are written to an array variable called **capture**.

Arguments that contain quotes in them were a challenge. The scripting cannot tell the difference between single or double quotes. Therefore when single quotes are specified in the matching then **shellmock** converts them to double quotes. The capture output will contain double quotes even if the original script was called with single quotes.

The original version 1 did not make any distinction and this new feature was added in version 2. In v1 no quotes would appear in the verification output. It would appear like three arguments were passed instead of two.

### Success Scenario leveraging a partial mock

In this test scenario we are only matching one of the arguments: "sample line". Any filename could be passed and still match the mock.

```bash
@test "sample.sh-success-partial-mock" {

    shellmock_expect grep --status 0 --type partial --match '"sample line"'

    run ./sample.sh

    shellmock_dump

    [ "$status" = "0" ]

    # Validate using lines array.
    [ "${lines[0]}" = "sample found" ]

    # Optionally since this is a single line you can use $output
    [ "$output" = "sample found" ]

    shellmock_verify
    shellmock_verify_times 1
    shellmock_verify_command 0 'grep-stub "sample line" sample.out'
}
```

### Success Scenario demonstrating single vs double quotes

This testcase is the same as the one above except that single quotes where used around the argument.

```bash
@test "sample.sh-success-partial-mock-with-single-quotes" {

    shellmock_expect grep --status 0 --type partial --match "'sample line'"

    run ./sample.sh

    shellmock_dump

    [ "$status" = "0" ]

    # Validate using lines array.
    [ "${lines[0]}" = "sample found" ]

    # Optionally since this is a single line you can use $output
    [ "$output" = "sample found" ]

    shellmock_verify
    shellmock_verify_times 1

    # Note that it is "sample line" in the capture output.
    shellmock_verify_command 0 'grep-stub "sample line" sample.out'
}
```

### Scenario with RegEx matching

This scenario was easier to show just using grep directly from the bats file. I created two mocks for grep, one with file names that start with *s* and one with file names starting with *b*. The two mocks return 0 and 1 respectively.

```bash
@test "sample.sh-mock-with-regex" {

    shellmock_expect grep --status 0 --type regex --match '"sample line" s.*'
    shellmock_expect grep --status 1 --type regex --match '"sample line" b.*'

    # The first two patterns leverage the first mock.
    run grep "sample line" sample.out
    [ "$status" = "0" ]

    run grep "sample line" sample1.out
    [ "$status" = "0" ]

    # These two patterns leverage the second mock.
    run grep "sample line" bfile.out
    [ "$status" = "1" ]

    run grep "sample line" bats.out
    [ "$status" = "1" ]

    shellmock_dump

    shellmock_verify
    shellmock_verify_times 4
    shellmock_verify_command 0 'grep-stub "sample line" sample.out'
    shellmock_verify_command 1 'grep-stub "sample line" sample1.out'
    shellmock_verify_command 2 'grep-stub "sample line" bfile.out'
    shellmock_verify_command 3 'grep-stub "sample line" bats.out'
}
```

The test bats files are another good source for examples as it contains examples of all of the **shellmock** features.

## Shellmock Functions

This section contains a list of the function provided by **shellmock** also with example usages.

### skipIfNot

**skipIfNot** is a very useful function that would be a great addition to **bats** itself. For now I have included this function in **shellmock**. This function will allow you to target particular tests while excluding others. To use it you must define an environment variable called **TEST\_FUNCTION**.

**TEST\_FUNCTION** may contain one or more test names delimited by a pipe. In the example below only tests "sample.sh failure" and "sample.sh success" would be executed. All others would be skipped.

```bash
$export TEST_FUNCTION="sample-failure|sample.sh-success"
```

or

```bash
TEST_FUNCTION="sample-failure" bats test
```

The next step is to instrument the **setup** function and leverage the **BATS\_TEST\_DESCRIPTION** variable. Alternatively, you can instrument each function with **skipIfNot** and pass in any alias for the test name you like.

```bash
setup() { # Source the shellmock functions into the shell.
    . ../bin/shellmock

    skipIfNot "$BATS_TEST_DESCRIPTION"

    shellmock_clean
}

@test "sample-failure" {

. . .

}
```

### shellmock\_clean

**shellmock\_clean** cleans up various temp files used by **shellmock**:

-   the **tmpstubs** directory - that is used to store stub data and scripts

-   **shellmock.out** - lists every stub call made

-   **shellmock.err** - lists errors encountered the stubs (ie not match found)

This command should be placed in the **setup** and **teardown** functions. To aid in troubleshooting, I typically recommend only calling it if **TEST\_FUNCTION** is not set. This keeps stubs scripts and data from being deleted and allows you to investigate issues easier.

A useful practice is to place the cleanup in an if statement and ignore cleanup if the TEST\_FUNCTION variable is set or some other debug variable. This allows you to have debugging access to the shellmock temp files for troubleshooting tests.

### shellmock\_debug

**shellmock\_debug** provides a means to capture output statement that might help troubleshoot testing issues.

It can be used in the shellmock script or in your bats scripts if useful.

The output is captured in shellmock-debut.out and will only be available if TEST\_FUNCTION is set.

### shellmock\_dump

**shellmock\_dump** can prove quite useful to troubleshoot testing issues. It will dump the contains of the **bats** **$lines** variable which basically equates to any standard out that has been generated by the script under test.

The output is captured in shellmock-debug.out and will only be available if **TEST\_FUNCTION** is set.

### shellmock\_verify

**shellmock\_verify** converts all **shellmock.out** lines into a variable array called **capture**. This allows testers to verify which stubs were called and in what order.

```bash
@test "sample.sh-failure" {
.
.
.
shellmock_verify
[ "${capture[0]}" = "some-stub arg1 arg2" ]
[ "${capture[1]}" = "some-stub2 arg1 arg2" ]
# or
shellmock_verify_command 0 "some-stub arg1 arg2"
shellmock_verify_command 1 "some-stub2 arg1 arg2"

}
```

### shellmock\_verify\_times

**shellmock\_verify\_times** used after **shellmock\_verify** this checks the number of calls to the mock. It allows testers to verify how many times stubs were called. It is a more descriptive way to write `[ "${#capture[@]}" = "10" ]`.

```bash
@test "sample.sh-failure" {
.
.
.
shellmock_verify
shellmock_verify_times 10
shellmock_verify_command 0 "some-stub arg1 arg2"
}
```

### shellmock\_verify\_command

**shellmock\_verify\_command** used after **shellmock\_verify** this checks the command of the nth calls to the mock. It allows testers to verify the command in the call. It is a more descriptive way to write `[ "${capture[0]}" = 'cp-stub a b' ]`.

```bash
@test "sample.sh-failure" {
.
.
.
shellmock_verify
shellmock_verify_command 0 "some-stub arg1 arg2"
shellmock_verify_command 1 "some-stub2 arg1 arg2"
}
```

### shellmock\_expect

**shellmock\_expect** allows you specify the command to be mocked and how the function should be mocked. The behavior can be in terms of status code, output to echo or a custom behavior that you provide.

```bash
usage: shellmock_expect [cmd]
    [--type partial | exact | regex ]
    [--status #]
    --match [arg1 arg2 arg3…]
    [--exec cmdstring ]
    [--source cmdstring]
    [--output texttoecho]
```

|Item|Description|Required?|Comment|
|----|-----------|--------|--------|
|cmd| unix command to mock|Yes.||
|-t,--type|Type of argument list matching: partial, exact regex|No.|Defaults to exact|
|-T,--stdin-match-type|Type of stdin matching: partial, exact, or regex|No.|Defaults to exact. Only the first line of stdin is considered.|
|-m,--match,--match-args|Arguments passed to cmd that indicate a match to mock.| No.|Defaults to empty string.|
|-M,--match-stdin|stdin data that is expected to be considered a match.| No.|Defaults to empty string.|
| -e,--exec|Command string to execute for custom behavior.| No.| Defines both the output and status code.|
|-S,--source |command string to source.| No.||
| -o,--output|Text string to echo if there is a match.| No.||
| -s,--status|status code to return|No. Defaults to 0||


Matching is defined based on the argument list and the stdin data stream. That means if there is a stdin for the command, the default "no stdin" match will not work.

If a command is mocked by **shellmock\_expect** but there is no match for the particular call, it will return with 99 as status code, in the hope that it will break the calling code.

**shellmock\_expect** supports returning a single or multiple responses for a given match criteria. The responses will be returned in the order defined. Once all response are seen the last response will be returned indefinitely.


#### examples

These examples assume that the "grep string1 file1" is the unix command being mocked to be used in other scripts under test. For simplicity of understanding, I am calling the **grep** command directly from bats to show what the behavior would look like.

##### Basic mock with success status

This example mocks **grep** to return a 0 status when the input is "string1 file1". In order to verify that the function was called you would need to use **shellmock\_verify** and do a comparison.

```bash
shellmock_expect grep --match "string1 file2"

run grep string1 file2

shellmock_verify
```

##### Basic mock with failed status

This scenario show a status of 1 being returned for the same inputs.

```bash
shellmock_expect grep --status 1 --match "string1 file2"

run grep string1 file2

shellmock_verify
```

##### Mock with partial mock

If the **grep** command is run it will return a status 0 if arg1 is "string1" regardless of the rest of the args. Use **shellmock\_verify** verify each invocation if desired.

```bash
shellmock_expect grep --status 0 --type partial --match string1

run grep string1 file2

run grep string1 file3

shellmock_verify
```

##### Mock with whitespace in the parameters

If the **grep** command is run by the script under test it will return a status 0 if arg1 is "string1" regardless of the rest of the args. In order to verify that the function was called you would need to use **shellmock\_verify** and do a comparison.

If the --match argument were "*string1 string2* file", where the double quotes and single quotes are swapped, then shellmock treats the string as if it were *"string1 string2" file*.

```bash
shellmock_expect grep --status 0 --type partial --match *"string1 string2"*

run grep "string1 string2" file2

run grep "string1 string2" file3

shellmock_verify
```

##### Mock with regex

This example shows the use of regex match type.

The regular expression is evaluated by the **AWK** command. Refer to **AWK** documentation for details. Any **AWK** special characters will need to be escaped in the match criteria.

```bash
shellmock_expect grep --status 0 --type regex --match "s.\* f.\*"

run grep string1 file2

run grep string1 file3

shellmock_verify
```

##### Mock with custom script

If the **grep** command is run by a script under test it will return a status 0 if arg1 is "string1" and arg2 is "file1". It will also write "mycustom string1 file1" to stdout. The use of the {} in the --exec script will cause any arguments passed to the mocked script to be expanded in place of the braces as seen below.

For this example you can verify the **status**, the **output**/**line**, and the **capture** variables.

```bash
shellmock_expect grep --status 0 --type partial --match "string1" --exec "echo mycustom {}"

    run grep string1 file1

    shellmock_dump
    [ "$status" = "0" ]
    [ "${lines[0]}" = "mycustom string1 file1" ]

    run grep string1 file2
    shellmock_dump
    [ "$status" = "0" ]
    [ "${lines[0]}" = "mycustom string1 file2" ]

    shellmock_verify
    shellmock_verify_times 2
    shellmock_verify_command 0 'grep-stub string1 file1'
    shellmock_verify_command 1 'grep-stub string1 file2'

```

This example shows the use of **echo** as the script, however, it could also be any user defined script that you want in place of the mocked command. The {} braces are a way to forward arguments from the mock script into your script.

## Debugging Tests

If the **shellmock\_clean** function is short circuited then the temp files will remain.

shellmock.out contains all of the mock commands that have been run and is used by the **shellmock\_verify** command.

If you following the sample and set TEST\_FUNCTION then the tmpstubs directory will remain and not be cleaned up. Inside that directory you will find err out and debug files.

For each file there will be two .tmp data files:

-   shellmock.out - shows which mocks were executed and their parameters

-   shellmock.err - shows the results of the matches

-   shellmock-debug.out - shows the results of what would have been sent to standard out array $lines which bats also allows you to match on.

-   \*.playback.capture.tmp - shows defines each of the expectations. There will be on of these files for every mocked script.

-   \*.playback.state.tmp - keeps track of multiple responses for the same mock

## Installing Bash Shell Mock from source

Check out a copy of the **shellmock** repository. Then, either add the **shellmock**
`bin` directory to your `$PATH`, or run the provided `install.sh`
command with the location to the prefix in which you want to install
**Shellmock**. For example, to install Bats into `/usr/local`,

    $ git clone [repository_url]
    $ cd bash_shell_mock
    $ ./install.sh /usr/local

Note that you may need to run `install.sh` with `sudo` if you do not
have permission to write to the installation prefix.


## Limitations

The **Shellmock** mocking approach does have impact on how write your scripts. The key to using any mocking in unix scripts is that the scripts must be reached via the PATH variable and you can not use full or relative pathing to the script. **Shellmock** uses the PATH variable to short circuit calling the "real" script or program.

## Dependencies

This project requires some additional dependencies:

-   [shellcheck](https://github.com/koalaman/shellcheck/wiki) - linting tool required for shellmock development.

-   [Bash Automated Testing System](https://github.com/bats-core/bats-core) - required to use shellmock for testing.

## Linting Shellcheck

Shellcheck has been integrated into the build process to provide the posix shell linting capabilities.

There is one globally disabled shellcheck rule related to the use of $?. It was quite rampant and it seemed good enough for now to ignore this one.

```
#!/usr/bin/env bash
#shellcheck disable=SC2181
```

Others are disabled as required such as the use of single quotes in awk commands that wrap the awk scripts. In those cases it was necessary to ignore SC2016 since we expect awk $ variables NOT to be expanded by the shell.

Shellcheck allows file, function and line item exclusions. In this project we favor line item exclusions. To add a line item exception place the exclusion directly about the line of code.

```
#shellcheck disable=SC2016
    AWK_STDIN_SCRIPT='BEGIN"@@"{if ($4=="E" && ($5…
```

It may make sense, however, to exclude at a higher level if for some reason there is a high number of expected failures as is the case in the **shellmock\_expect()** function. That function generates a shell script itself so shellcheck has a field day in that one. As a result we excluded two items within the function.

```
#shellcheck disable=SC2016,SC2129
shellmock_expect()
```

## Looking up Error Details

[Shellcheck Errors](https://github.com/koalaman/shellcheck/wiki/Checks) describes how to lookup a particular error. There is a page created for each one. You access the page by appending the error code that was reported by shellcheck.
```
https://github.com/koalaman/shellcheck/wiki/Checks/[error]
```

At the time of this writing they also provided a link in the page to take you to an enumerated list of all errors.

## Contributors

This project was originally developed by Capital One’s Open Source Projects group.

* [ckstettler](https://github.com/ckstettler)
* @CaptianQuirk
* @sheosinha
* @tyleroconnell

After the group abandoned the code, in 2021, it has forked and updated by [Duane May](https://github.com/duanemay).

## License

Unless indicated otherwise, this project continues to be licensed
under the Apache License, Version 2.0.
You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
.
