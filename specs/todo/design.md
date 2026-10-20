# Design: todo

## Overview

`main()` passes `runtime.args()` to `cli.app.run`, which parses the options
(`cli.args`), handles `--help` and `--version`, checks the command and that
every option given applies to it, and calls `commands.runner.run_command`.
That loads the store from the todo file, runs the command as a pure
function from a `Store` to an `Outcome`, saves the store if the outcome says
it changed, and only then prints the outcome.

```text
argv -> Options -> load(FILE) -> Store --cmd_*--> Outcome{lines, errors, status, changed}
                                   |                         |
                                   +----- save(FILE) <-------+ (if changed)
```

Every command is testable without files: `cmd_add(edits store, opts, today,
uuid)` and friends take today's date and the new UUID as arguments.

## Modules

| Module | Contents |
|---|---|
| `source/main.loup` | entry point: `run(runtime.args())` |
| `source/appinfo.loup` | name, version, summary, exit statuses |
| `source/cli/args.loup` | `Options`, `parse_args`, `disallowed` |
| `source/cli/usage.loup` | `usage()`, `version_line()` |
| `source/cli/app.loup` | `run()`, `dispatch()`: command and option checks |
| `source/commands/runner.loup` | `allowed_options`, `execute`, `run_command` (load, run, save, print) |
| `source/commands/common.loup` | `Outcome`, ID parsing, value checks, sort order, filters, `task_line` |
| `source/commands/add.loup`, `list.loup`, `done.loup` (`done`, `undo`, `rm`), `edit.loup`, `due.loup` | one pure `cmd_*` per command |
| `source/model/task.loup` | `Task`, `Store`, `new_task`, `add_task`, `find_index`, `remove_at`, priorities, tags |
| `source/model/dates.loup` | `valid_iso`, `parse_due`, `days_between`, `relative_day`, `today()` (`$TODO_TODAY`) |
| `source/model/ids.loup` | `new_uuid` (core.random, checked with core.uuid) |
| `source/storage/json.loup` | `Json` enum, `parse_json`, `write_json`, `quote`, `field` |
| `source/storage/file.loup` | `store_path`, Store ⇄ JSON, `load_store`, `save_store` (atomic) |

## Storage

The file is read whole, parsed into a `Json` tree and converted to a
`Store`, checking every field (types, real dates, priorities, tags, UUIDs,
unique IDs). `next_id` is kept at least one past the highest ID, so IDs are
never reused. Saving writes `FILE.tmp` next to the file and renames it over
the file with `runtime.fs().rename`, so readers see the old or the new file,
never a partial one.

JSON is handled by `storage/json.loup` rather than `system.json`, whose
`parse` and `stringify` are host builtins that native builds of Loup 1.26.0
cannot link. The tests check that both read each other's output.

## Dates and IDs

Dates are ISO strings; `core.datetime.Date` does the calendar arithmetic
(`addDays`, `daysUntil`, `weekday`, `today`). User input is validated with
`valid_iso` before a `Date` is built, because `Date.fromIsoformat` throws on
an impossible date. `$TODO_TODAY` replaces the system date.

`core.uuid`'s `Uuid.v4()` needs an entropy source that neither native builds
nor the self-hosted `loup run` provide, so `model/ids.loup` draws 16 bytes
from `core.random.Random` seeded with the clock (`system.time`), sets the
version and variant bits, and checks the result with `Uuid.isValid`.

## What this example shows

- A subcommand dispatcher with per-command option checks, kept from the
  template.
- Pure commands over value types (`Store`, `Task` are structs; `edits`
  parameters), so the unit tests need no files.
- An atomic save, a validating loader, and a hand-written JSON codec.
- The dual workflow: `make run` interprets the same sources that `make
  build` compiles, and `make e2e-run` runs the end-to-end suite against
  both.

## Deviations from the roadmap

- `system.json` is used only by the tests (as a cross-check), not by the
  program: it does not link natively.
- `core.uuid` only validates UUIDs; they are generated from `core.random`.

## Native-build constraints (Loup 1.26.0)

- A struct built both in its defining module and in another module is
  corrupted in native builds, so `Task` values are built only by
  `model.task.new_task`, `Store` only in `model.task`, `Outcome` only in
  `commands.common`.
- `match` arms that build strings return from each arm (statement form).
- `io.fs.rename` is shadowed by libc's `rename` natively; the runtime's
  `runtime.fs().rename` is used.
- `readText` of a missing file cannot be caught natively, so existence and
  type are checked first.

## Error handling

Usage errors (status 2) are detected before anything changes: unknown
commands and options, options for another command, missing text or IDs,
bad IDs, priorities, tags, dates and day counts. Unknown task IDs (status 1)
are reported per ID while the others are processed. File problems (status
1) are reported as `todo: FILE: REASON`; a failed save prints no success
message.

## Testing

- `tests/args_test.loup`: options anywhere, inline values, `--`, errors,
  `disallowed`.
- `tests/json_test.loup`: scalars, escapes and surrogate pairs, round trips,
  errors with positions, compatibility with `system.json`.
- `tests/dates_test.loup`: ISO validation, every due-date form, day
  arithmetic.
- `tests/task_test.loup`: IDs, removal, priorities, tags.
- `tests/file_test.loup`: the file format, round trips, `next_id`, defaults,
  every validation error.
- `tests/commands_test.loup`: each command on in-memory stores.
- `tests/app_test.loup`: exit statuses.
- `tests/e2e.sh`: the native binary against a file under `$TMP`
  (`make e2e`), and the same script through `loup run` (`make e2e-run`).
