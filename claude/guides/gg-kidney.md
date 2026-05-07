## Commands

These commands are available in the ticket workspace and in the single repositories:

```bash
kd do add <repo> [<repo2> ...] # add repos to the ticket workspace given by their names
kd can commit # run all checks in all repos (analyze + format + tests)
kd do commit -m <message> # commit in all repos after checks pass
kd can push # check for all repos if they are ready to push (checks + commit)
kd do push # push in all repos after checks pass
kd do review # start code review in all repos
kd do cancel-review # cancel code review in all repos and return to work
kd do publish # publish all repos after review is approved (should be executed manually by a human)
```

To install kd, run:
```bash
dart pub global activate kd
```

The following commands are only available in the repositories in the ticket workspace:

### GG Commands (gg is often used by kd commands)
```bash
gg check analyze                 # static analysis
gg check format                  # formatting check
gg can commit                    # run all checks (analyze + format + tests)
gg do commit -m <message>        # commit after checks pass
gg do push                       # push after checks pass
```

### Testing
```bash
dart test                        # run all tests
dart test test/path/to/file_test.dart  # run a single test file
```

### get dependencies
```bash
dart pub get
```

For committing, always use gg do commit or kd do commit.
For pushing, always use gg do push or kd do push.


## Architecture

### gg Architecture
<!-- Begin Content CLAUDE.md inside repo gg -->
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

`gg` is a Dart CLI tool that streamlines developer workflows with pre-commit checks: code analysis, formatting, test execution with 100% coverage enforcement, and git workflow automation (commit, push, merge, publish).

## Commands

```bash
# Run all checks (analysis, format, tests)
dart run gg all

# Run tests
dart test                                              # all tests
dart test test/commands/can/can_commit_test.dart       # single file
dart test -n "pattern"                                 # by name pattern

# Individual checks
dart analyze
dart format .
```
