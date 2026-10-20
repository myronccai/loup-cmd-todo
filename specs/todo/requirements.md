# Requirements: todo

## Introduction

`todo` is a command-line task manager that keeps its tasks in a JSON file.
Tasks have a text, an optional priority, tags and an optional due date, and
can be listed with filters. It is the dual-mode project of the loup-cmd
series closest to the template: a real subcommand dispatcher, developed
interpreted with `make run` and shipped as the native binary `build/todo`.

## Requirements

### Requirement 1: The todo file

**User Story:** As a user, I want my tasks kept in a plain JSON file that I
can choose, read and back up.

#### Acceptance Criteria

1. THE program SHALL use the file given with `-f`/`--file`, else
   `$TODO_FILE` when it is set and not empty, else `./todo.json`.
2. WHEN the file does not exist, THE program SHALL behave as if it held no
   tasks, and SHALL create it on the first change.
3. THE program SHALL write the file as pretty-printed JSON with `version`,
   `next_id` and `tasks`; each task SHALL have `id`, `uuid`, `title`,
   `done`, `priority`, `tags`, `due`, `created` and `completed`.
4. THE program SHALL save atomically: write `FILE.tmp` in the same
   directory, then rename it over `FILE`.
5. WHEN the file is not valid JSON or not a todo file, THE program SHALL
   report `todo: FILE: REASON`, leave the file untouched and exit with
   status 1. A missing directory or a path that is a directory SHALL be
   reported the same way.
6. Task IDs SHALL be positive and SHALL never be reused, even after `rm`.
   Every task SHALL get a random version-4 UUID when it is added.

### Requirement 2: Adding tasks

**User Story:** As a user, I want to add a task with its details in one
command.

#### Acceptance Criteria

1. WHEN `add TEXT...` is run, THE program SHALL add an open task whose text
   is the words joined by spaces, record today as its creation date, and
   print `Added task ID: TEXT`.
2. `-p`/`--priority` SHALL accept `high`, `medium`, `low` (or `h`, `m`/`med`,
   `l`) in any case, and `none`.
3. `-t`/`--tag` SHALL add a tag (letters, digits, `-`, `_`, `.`); it may be
   repeated; duplicates SHALL be dropped.
4. `-d`/`--due` SHALL accept `YYYY-MM-DD` (a real date), `today`,
   `tomorrow`, `+N` or `+Nd` (days), `+Nw` (weeks), a weekday name of at
   least three letters (the next such day after today) and `none`.
5. WHEN the text is empty or a value is invalid, THE program SHALL report a
   usage error and add nothing.

### Requirement 3: Listing tasks

**User Story:** As a user, I want to see my tasks in a useful order and
narrow them down.

#### Acceptance Criteria

1. WHEN `list` (or `ls`) is run, THE program SHALL print the open tasks, one
   per line: ID, `[ ]` or `[x]`, priority (`-` for none), due date (`-` for
   none), text and `#tag`s.
2. THE program SHALL order tasks: open before done, then by due date (none
   last), then priority (high first), then ID.
3. `-a`/`--all` SHALL include done tasks; `--done` SHALL show only done
   tasks; `-t TAG` (repeatable) SHALL keep tasks having every given tag;
   `-p P` tasks with that priority; `-s TEXT` tasks whose text contains TEXT
   in any case; `--overdue` open tasks whose due date has passed.
4. `-l`/`--long` SHALL add a line with the created and completed dates and
   the UUID.
5. WHEN nothing is shown, THE program SHALL print `No tasks.` (empty file)
   or `No matching tasks.`.

### Requirement 4: Changing tasks

**User Story:** As a user, I want to complete, reopen, change and remove
tasks by ID.

#### Acceptance Criteria

1. `done ID...` SHALL mark tasks done with today's completion date and print
   `Completed task ID: TEXT`; a task already done SHALL be reported with
   `Task ID is already done.`
2. `undo ID...` SHALL reopen tasks and clear the completion date, printing
   `Reopened task ID: TEXT` (or `Task ID is not done.`).
3. `rm ID...` SHALL remove tasks and print `Removed task ID: TEXT`.
4. `edit ID [TEXT...]` SHALL replace the text when one is given, and apply
   `-p`, `-t`, `--untag` and `-d` (where `none` clears the priority or the
   due date), printing `Updated task ID: TEXT`; with nothing to change it
   SHALL be a usage error.
5. WHEN an ID is not a positive number, THE program SHALL report a usage
   error before changing anything; WHEN no task has an ID, THE program SHALL
   report `todo: no task with ID N`, still process the other IDs, and exit
   with status 1.

### Requirement 5: Due tasks

**User Story:** As a user, I want to see what is due soon.

#### Acceptance Criteria

1. `due [DAYS]` SHALL list the open tasks whose due date is at most DAYS
   days away (default 7), overdue ones included, soonest first, each
   followed by `(N days overdue)`, `(due today)`, `(due tomorrow)` or
   `(due in N days)`.
2. `-t` and `-p` SHALL filter as for `list`; `-l` SHALL add the long line.
3. WHEN nothing is due, THE program SHALL say so (`Nothing due in the next N
   days.`).
4. `$TODO_TODAY` (YYYY-MM-DD), when set, SHALL replace the system date, so
   tests and demonstrations are reproducible.

### Requirement 6: Command line

**User Story:** As a shell user, I want predictable options, messages and
exit statuses.

#### Acceptance Criteria

1. Options SHALL be accepted anywhere before `--`, as `-x VALUE`,
   `--name VALUE` or `--name=VALUE`; arguments after `--` SHALL be text.
2. WHEN a command is given an option that does not apply to it, THE program
   SHALL report a usage error (`option '--all' does not apply to 'add'`).
3. `--help`/`-h` and `help` SHALL print the usage; `--version`/`-V` SHALL
   print `todo (loup-cmd-todo) 0.1.0`.
4. THE program SHALL exit with 0 on success, 1 when a task or the file could
   not be used, and 2 on a usage error, printing usage errors as
   `todo: MESSAGE` and `Try 'todo --help' for more information.`
