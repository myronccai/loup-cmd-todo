# loup-cmd-todo

A command-line task manager in [Loup](https://code-craft.ai/references/loup):
`add`, `list`, `done`, `undo`, `rm`, `edit` and `due`, with priorities,
tags, filters and due dates, kept in a JSON file that is saved atomically.

Part of the **loup-cmd** series of example applications: classic Linux and
Windows commands, and projects for each Loup execution mode, each in its own
repository under [myronccai](https://github.com/myronccai?tab=repositories&q=loup-cmd).
This one is a `host.dual` project: you develop it interpreted with
`make run` and ship the native binary `build/todo` built from the same
sources.

## Requirements

- [Loup Lite](https://github.com/code-craft-ai-company/loup-releases) 1.26.0
  or later; see [Installing Loup Lite](#installing-loup-lite).
- `make`, and `clang` 17 or later for the native build.

## Installing Loup Lite

This example is built and tested with **Loup Lite**, the free public build of
the Loup toolchain from [Code Craft AI](https://code-craft.ai), meant for
education and training. Code Craft AI publishes the official builds,
installers and signed checksums at
**<https://github.com/code-craft-ai-company/loup-releases>**, for Linux
(x86-64, arm64), macOS (Apple silicon, Intel) and Windows (x86-64).

Linux and macOS:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.sh | sh
```

Windows (PowerShell):

```powershell
irm https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.ps1 | iex
```

The installer picks the archive for your machine, checks it against the
release's `SHA256SUMS`, unpacks it into `~/.loup`
(`%LOCALAPPDATA%\Programs\Loup` on Windows) and puts its `bin` directory on
your `PATH`; it needs no administrator rights. You get `loup`, the Stage0
compiler `loup-bootstrap` and the Wasm runtime `loup-launcher`. Open a new
shell and check:

```sh
loup --version             # loup 1.26.0 or later
```

CI installs the exact version it tests with, 1.26.0. To do the same:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/download/v1.26.0/loup-install.sh | sh -s -- --version 1.26.0
```

To install by hand, download your platform's archive from the
[releases page](https://github.com/code-craft-ai-company/loup-releases/releases),
check it against `SHA256SUMS`, unpack it anywhere and add its `bin` directory to
`PATH`. The [loup-releases README](https://github.com/code-craft-ai-company/loup-releases#verify-a-download)
explains how to verify the Sigstore signature on `SHA256SUMS`.

Loup Lite leaves out Loup's cryptography library and the full set of Loup
packages; this example needs neither. The full release is at
<https://code-craft.ai/loup/download>, and commercial use of Loup needs a
license: <https://code-craft.ai/loup/license>.

## Usage

```sh
make build                          # native binary: build/todo
make ci                             # check, unit tests, build, e2e (binary and loup run)
make run ARGS="add buy milk -p h"   # run from source with loup run
```

```text
$ build/todo add buy milk -p high -t home -d tomorrow
Added task 1: buy milk
$ build/todo add pay rent -p medium -t home -t bills -d 2026-10-18
Added task 2: pay rent
$ build/todo add call the dentist -d fri
Added task 3: call the dentist
$ build/todo add read Dune -t books
Added task 4: read Dune
$ build/todo list
 2 [ ] medium 2026-10-18  pay rent #home #bills
 1 [ ] high   2026-10-21  buy milk #home
 3 [ ] -      2026-10-23  call the dentist
 4 [ ] -      -           read Dune #books
$ build/todo done 1
Completed task 1: buy milk
$ build/todo due
 2 [ ] medium 2026-10-18  pay rent #home #bills  (2 days overdue)
 3 [ ] -      2026-10-23  call the dentist  (due in 3 days)
$ build/todo list -a -t home
 2 [ ] medium 2026-10-18  pay rent #home #bills
 1 [x] high   2026-10-21  buy milk #home
$ build/todo edit 4 read Dune Messiah -p low --untag books -t scifi
Updated task 4: read Dune Messiah
$ build/todo list -l -s dune
 4 [ ] low    -           read Dune Messiah #scifi
       created 2026-10-20, uuid 76ed6d00-1c98-40f7-866f-d55b303cab33
$ build/todo rm 7; echo "exit $?"
todo: no task with ID 7
exit 1
$ build/todo add; echo "exit $?"
todo: add: missing task text
Try 'todo --help' for more information.
exit 2
```

Commands:

| Command | Does | Options |
|---|---|---|
| `add TEXT...` | adds an open task | `-p PRIORITY`, `-t TAG`..., `-d DATE` |
| `list` (`ls`) | lists open tasks | `-a` (all), `--done`, `-t TAG`..., `-p PRIORITY`, `-s TEXT`, `--overdue`, `-l` |
| `done ID...` | marks tasks done | |
| `undo ID...` | reopens tasks | |
| `rm ID...` | removes tasks | |
| `edit ID [TEXT...]` | changes a task | `-p PRIORITY`, `-t TAG`..., `--untag TAG`..., `-d DATE` |
| `due [DAYS]` | open tasks due within DAYS days (default 7), overdue ones included | `-t TAG`..., `-p PRIORITY`, `-l` |
| `help` | prints the usage | |

- Priorities: `high`, `medium`, `low` (`h`, `m`, `l`), or `none` to clear.
- Due dates: `YYYY-MM-DD`, `today`, `tomorrow`, `+N` days, `+Nw` weeks, a
  weekday (`fri`, `monday`: the next one after today), or `none` to clear.
- Tags: letters, digits, `-`, `_` and `.`; `-t` with `list` and `due` keeps
  tasks that have every tag given.
- Order: open tasks first, then by due date (none last), priority, ID.
- Options may come anywhere before `--`, as `-p high`, `--priority high` or
  `--priority=high`; a command refuses options that are not its own.
  `-h`/`--help` and `-V`/`--version` work everywhere.

The file is `--file FILE`, else `$TODO_FILE`, else `./todo.json`. A missing
file means no tasks; it is created by the first change. IDs are never
reused. `$TODO_TODAY=YYYY-MM-DD` replaces today's date (the tests use it).

```text
$ head -16 todo.json
{
  "version": 1,
  "next_id": 5,
  "tasks": [
    {
      "id": 1,
      "uuid": "a60b0bc3-1f3a-49d4-9eb8-5dae85a7412f",
      "title": "buy milk",
      "done": true,
      "priority": "high",
      "tags": ["home"],
      "due": "2026-10-21",
      "created": "2026-10-20",
      "completed": "2026-10-20"
    },
    {
```

Exit status: `0` on success, `1` if a task ID is unknown or the file cannot
be read or written (`todo: FILE: REASON`), `2` on a usage error.

## What this example shows

**The dual workflow.** The sources are `host.dual`, so the same files run
in two ways. While you work, `make run` interprets them with `loup run`; to
ship, `make build` compiles them into `build/todo`, a 470 KB executable
that needs no Loup installation. They print the same thing:

```text
$ make run ARGS="list -t home"
loup run source/main.loup -- list -t home
 2 [ ] medium 2026-10-18  pay rent #home #bills
$ build/todo list -t home
 2 [ ] medium 2026-10-18  pay rent #home #bills
```

and `make ci` holds them to it: `make e2e` runs `tests/e2e.sh` against the
binary and `make e2e-run` runs the same 65 cases through `loup run`.

**The rest of the template, used for real.** A subcommand dispatcher with
per-command option checks; commands as pure functions from a `Store` to an
`Outcome` (lines, errors, exit status, whether to save), so the unit tests
need no files; a validating loader; and an atomic save (write `FILE.tmp`,
rename it over `FILE`).

**Where 1.26.0 forced a detour.** These are the places where the program
does not use the standard library the roadmap planned for:

- `system.json` is not used by the program: its `parse` and `stringify` are
  host builtins that native builds cannot link. `source/storage/json.loup`
  is a small JSON reader and writer instead; the unit tests check that it
  and `system.json` read each other's output.
- `core.uuid`'s `Uuid.v4()` needs an entropy source that native builds and
  the self-hosted `loup run` lack, so UUIDs are drawn from `core.random`
  seeded with the clock, and `core.uuid` only validates them.
- `core.datetime` does all the date arithmetic (`addDays`, `daysUntil`,
  `weekday`, `today`).
- In native builds, a struct constructed both in its own module and in
  another one is corrupted, so each struct is built in one module only
  (`model.task.new_task` for tasks).

## Layout

```text
source/main.loup              # entry point
source/appinfo.loup           # name, version, exit statuses
source/cli/args.loup          # options
source/cli/usage.loup         # --help and --version text
source/cli/app.loup           # run(): parse, dispatch, option checks
source/commands/runner.loup   # load, run a command, save, print
source/commands/common.loup   # Outcome, sorting, filters, task lines
source/commands/*.loup        # add, list, done/undo/rm, edit, due
source/model/task.loup        # Task, Store, IDs, priorities, tags
source/model/dates.loup       # due-date parsing and arithmetic
source/model/ids.loup         # UUIDs
source/storage/json.loup      # JSON reader and writer
source/storage/file.loup      # the todo file: format, load, atomic save
tests/*_test.loup             # unit tests (make test)
tests/e2e.sh                  # end-to-end tests (make e2e, make e2e-run)
specs/todo/                   # requirements, design, tasks
```

[AGENTS.md](AGENTS.md) has every build and test command and the conventions
for changing the code.

## License

[MIT](LICENSE), copyright 2026 Code Craft AI LLC. The Loup skill in
[`skills/loup-programmer/`](skills/loup-programmer/) is copied from the Loup
project and is not covered by this license; it keeps the Loup project's terms.
