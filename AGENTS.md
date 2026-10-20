# AGENTS.md

This repository is `todo`, a command-line task manager written in the Loup
programming language, as part of the loup-cmd series of example
applications. Tasks live in a JSON file. The program is `host.dual` Loup:
developed with `loup run` and shipped as a native executable.

## Skills

| Skill | Location | Use it when |
|-------|----------|-------------|
| `loup-programmer` | [skills/loup-programmer/SKILL.md](skills/loup-programmer/SKILL.md) | Writing, reviewing, debugging or explaining Loup code: `.lpscr`, `.loup`, `.lphc`, `.lpweb` or `.lpfree` source files, `.lppkg` manifests, `@mode(...)` directives, or the `loup` / `loup-bootstrap` commands. |

Read `skills/loup-programmer/SKILL.md` before writing or changing any Loup code
in this repository. It links to detailed references under
`skills/loup-programmer/references/` for syntax, types and ownership, execution
modes and projects, errors and diagnostics, the standard library, and common
mistakes. Load those only as needed.

## Code layout

```text
.
├── package.lppkg                # Loup manifest: name, version, toolchain, [build] entry, [test] pattern
├── Makefile                     # run, check, test, build, e2e, e2e-run, ci, clean
├── source/                      # all Loup code; modules import each other by path from here
│   ├── main.loup                # entry point: func main() calls run(runtime.args())
│   ├── appinfo.loup             # APP_NAME, APP_VERSION, APP_SUMMARY, exit statuses
│   ├── cli/
│   │   ├── args.loup            # struct Options, parse_args(), disallowed()
│   │   ├── usage.loup           # usage(), version_line()
│   │   └── app.loup             # run(), dispatch(): command and option checks
│   ├── commands/
│   │   ├── runner.loup          # allowed_options(), execute(), run_command(): load, run, save, print
│   │   ├── common.loup          # Outcome, parse_id, check_values, sorted, filter_tasks, task_line
│   │   ├── add.loup             # cmd_add
│   │   ├── list.loup            # cmd_list, select_tasks
│   │   ├── done.loup            # cmd_done (done and undo), cmd_rm, parse_ids
│   │   ├── edit.loup            # cmd_edit
│   │   └── due.loup             # cmd_due, due_note
│   ├── model/
│   │   ├── task.loup            # Task, Store, new_task, add_task, find_index, remove_at
│   │   ├── dates.loup           # valid_iso, parse_due, days_between, today() ($TODO_TODAY)
│   │   └── ids.loup             # new_uuid
│   └── storage/
│       ├── json.loup            # Json enum, parse_json, write_json
│       └── file.loup            # store_path, Store <-> JSON, load_store, save_store
├── tests/
│   ├── *_test.loup              # unit tests: func test_*(): void
│   ├── e2e.sh                   # end-to-end tests (a todo file under $TMP, TODO_TODAY fixed)
│   └── run-from-source.sh       # `loup run` wrapper for make e2e-run
├── specs/todo/                  # requirements.md, design.md, tasks.md
├── skills/loup-programmer/      # the Loup skill and its references
├── .github/workflows/ci.yml     # installs Loup and runs `make ci`
└── build/                       # build output (git-ignored)
```

## Build, run and test

Prerequisites: Loup 1.26.0 (`loup` and `loup-bootstrap` on `PATH`), `make`,
and `clang` 17 or later for native builds.

Loup Lite comes from <https://github.com/code-craft-ai-company/loup-releases>;
[README.md](README.md#installing-loup-lite) has the install commands.

| Task | Command | Notes |
|------|---------|-------|
| Run from source | `make run ARGS="add buy milk -p high"` | `loup run source/main.loup -- ARGS`; uses `$TODO_FILE` or `./todo.json` |
| Type-check | `make check` | checks `source/main.loup` and every module it imports; tests are not checked |
| Run all tests | `make test` | every `tests/*_test.loup`, sequentially |
| Run matching tests | `make test TEST_ARGS="--filter due"` | tests whose name contains `due` |
| Run one test file | `make test TEST_ARGS="--file tests/json_test.loup"` | |
| Build | `make build` | native binary at `build/todo` |
| Run the binary | `TODO_FILE=/tmp/t.json build/todo list` | |
| End-to-end tests | `make e2e` | runs `tests/e2e.sh build/todo` |
| Same, interpreted | `make e2e-run` | runs `tests/e2e.sh` through `loup run` |
| Everything CI runs | `make ci` | check, test, build, e2e, e2e-run, then `build/todo --version` |
| Clean | `make clean` | removes `build/` and `.temp/` |

Run `make ci` before reporting a change as done. `loup run` and the native
build do not support the same things, so a change can pass `make test` and
still fail `make build`.

Do not call `loup test` or `loup check` directly on Linux x86-64. There `loup`
is the self-hosted driver: it refuses `check`, and its test runner cannot
resolve this project's imports. The Makefile uses `loup-bootstrap` (Stage0) for
both, and sets `LOUPPATH=source` for tests. Tests run with `--no-parallel`:
the parallel runner fails intermittently on this suite.

## Making a change

1. Update the spec in `specs/todo/` (see [specs/README.md](specs/README.md)).
2. Change the code under `source/`.
3. Add or update unit tests in `tests/` and cases in `tests/e2e.sh`.
4. Run `make ci`.
5. Tick the finished tasks in `specs/todo/tasks.md`.

Keep commands pure: a `cmd_*` function takes the `Store` (`edits` when it
changes it), the options, today's date and anything random (the UUID), and
returns an `Outcome`. Only `commands/runner.loup` touches the file and
prints.

## Conventions

- Every source file is `@mode(host.dual)` with the `.loup` extension. Only
  `source/main.loup` has a `main()`.
- Modules import each other by path from `source/`:
  `from model.task import (Task);`. Tests import them the same way. Do not
  use relative imports (`from .args import ...`): the self-hosted `loup run`
  on Linux x86-64 fails on them.
- Native-build pitfalls in Loup 1.26.0 that this code works around:
  - build each struct in one module only (its factory: `new_task`,
    `empty_store`, `new_outcome`); a struct constructed both in its own
    module and elsewhere is corrupted;
  - write a `match` that builds a string in statement form, with a `return`
    in each arm;
  - do not use `system.json` (link error) or `Uuid.v4()` (no entropy) in
    `source/`; tests may use `system.json`;
  - rename with `runtime.fs().rename`, not `io.fs.rename`;
  - check `exists`/`isFile`/`isDir` before reading or writing: native
    `IoError`s cannot be caught;
  - `list.is_empty()` does not compile natively; use `len() == 0`.
- Struct fields read from another module must be `pub`; fields that are
  assigned must be `var`.
- Keep `APP_VERSION` in `source/appinfo.loup` equal to `version` in
  `package.lppkg`.
- The skill's examples use the `loup init` layout (`src/`, `tests/`, and
  `from ..src.x import` in tests). This project uses `source/` and
  `tests/` with plain imports; follow this file.
- The skill documents toolchain 1.25.1; this project targets 1.26.0. When
  they disagree, trust the toolchain's behaviour.
