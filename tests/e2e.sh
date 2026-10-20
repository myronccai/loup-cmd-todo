#!/usr/bin/env bash
# End-to-end tests: run the built binary and compare its standard output
# (byte for byte) and exit status with the expected ones.
#
# usage: tests/e2e.sh BINARY

set -u
BIN=$1
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0
fail=0

# check_file NAME STATUS EXPECTED_FILE [ARGS...]
# Runs BINARY ARGS... with standard input from the file named by $IN
# (default: /dev/null) and compares standard output with EXPECTED_FILE.
check_file() {
    local name=$1 want_status=$2 want_file=$3
    shift 3
    "$BIN" "$@" < "${IN:-/dev/null}" > "$TMP/out" 2> "$TMP/err"
    local status=$?
    if [ "$status" -eq "$want_status" ] && cmp -s "$want_file" "$TMP/out"; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        diff <(od -c "$want_file") <(od -c "$TMP/out") | sed 's/^/    /' | head -20
        sed 's/^/    stderr: /' "$TMP/err" | head -5
    fi
}

# check NAME STATUS EXPECTED_STDOUT [ARGS...]
# As check_file, with the expected output given as a string. Bash strings
# cannot hold NUL bytes; use check_file for output that contains them.
check() {
    local name=$1 want_status=$2
    printf '%s' "$3" > "$TMP/want"
    shift 3
    check_file "$name" "$want_status" "$TMP/want" "$@"
}

# check_err NAME STATUS EXPECTED_STDERR [ARGS...]
# Like check, but compares standard error (standard output must be empty).
check_err() {
    local name=$1 want_status=$2
    printf '%s' "$3" > "$TMP/want_err"
    shift 3
    "$BIN" "$@" < "${IN:-/dev/null}" > "$TMP/out" 2> "$TMP/err"
    local status=$?
    if [ "$status" -eq "$want_status" ] && [ ! -s "$TMP/out" ] && cmp -s "$TMP/want_err" "$TMP/err"; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        diff "$TMP/want_err" "$TMP/err" | sed 's/^/    /' | head -10
        sed 's/^/    stdout: /' "$TMP/out" | head -5
    fi
}

# check_true NAME COMMAND...: passes when the command succeeds.
check_true() {
    local name=$1
    shift
    if "$@"; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name"
    fi
}

# Every run uses a todo file under $TMP and a fixed "today" (a Tuesday).
export TODO_FILE="$TMP/todo.json"
export TODO_TODAY=2026-10-20
USAGE_HINT=$'Try \'todo --help\' for more information.\n'

# Empty file
check "list, no file"      0 $'No tasks.\n'                         list
check_true "no file created" test ! -e "$TODO_FILE"
check "due, no file"       0 $'Nothing due in the next 7 days.\n'  due

# add
check "add"                0 $'Added task 1: buy milk\n'            add buy milk -p high -t home -d tomorrow
check "add plain"          0 $'Added task 2: call bob\n'            add call bob
check "add overdue"        0 $'Added task 3: pay rent\n'            add pay rent --priority=m -t home -t money --due 2026-10-18
check "add weekday"        0 $'Added task 4: water plants\n'        add water plants -d fri -p low
check "add --"             0 $'Added task 5: -p is text\n'          add -- -p is text
check_true "file written"  test -s "$TODO_FILE"
check_true "no temp file"  test ! -e "$TODO_FILE.tmp"

# The file: pretty-printed JSON (UUIDs are random, so they are masked)
cat > "$TMP/want.json" <<'JSON'
{
  "version": 1,
  "next_id": 6,
  "tasks": [
    {
      "id": 1,
      "uuid": "UUID",
      "title": "buy milk",
      "done": false,
      "priority": "high",
      "tags": ["home"],
      "due": "2026-10-21",
      "created": "2026-10-20",
      "completed": null
    },
JSON
sed -E 's/"uuid": "[0-9a-f-]{36}"/"uuid": "UUID"/' "$TODO_FILE" | head -15 > "$TMP/got.json"
check_true "file format" cmp -s "$TMP/want.json" "$TMP/got.json"
check_true "uuids are v4" test "$(grep -cE '"uuid": "[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}"' "$TODO_FILE")" -eq 5

# list
check "list" 0 \
' 3 [ ] medium 2026-10-18  pay rent #home #money
 1 [ ] high   2026-10-21  buy milk #home
 4 [ ] low    2026-10-23  water plants
 2 [ ] -      -           call bob
 5 [ ] -      -           -p is text
' list
check "list ls alias"      0 $' 3 [ ] medium 2026-10-18  pay rent #home #money\n 1 [ ] high   2026-10-21  buy milk #home\n' ls -t home
check "list tag+priority"  0 $' 1 [ ] high   2026-10-21  buy milk #home\n' list -t home -p h
check "list search"        0 $' 2 [ ] -      -           call bob\n'    list -s BOB
check "list overdue"       0 $' 3 [ ] medium 2026-10-18  pay rent #home #money\n' list --overdue
check "list no match"      0 $'No matching tasks.\n'                   list -t nothing

# done / undo
check "done"               0 $'Completed task 1: buy milk\nCompleted task 5: -p is text\n' done 1 5
check "done again"         0 $'Task 1 is already done.\n'            done 1
check "list hides done"    0 $' 3 [ ] medium 2026-10-18  pay rent #home #money\n 4 [ ] low    2026-10-23  water plants\n 2 [ ] -      -           call bob\n' list
check "list --done"        0 $' 1 [x] high   2026-10-21  buy milk #home\n 5 [x] -      -           -p is text\n' list --done
check "list -a"            0 $' 3 [ ] medium 2026-10-18  pay rent #home #money\n 4 [ ] low    2026-10-23  water plants\n 2 [ ] -      -           call bob\n 1 [x] high   2026-10-21  buy milk #home\n 5 [x] -      -           -p is text\n' list -a
check_true "completed date" grep -q '"completed": "2026-10-20"' "$TODO_FILE"
check "undo"               0 $'Reopened task 5: -p is text\n'        undo 5
check "undo open task"     0 $'Task 5 is not done.\n'                undo 5

# due
check "due" 0 \
' 3 [ ] medium 2026-10-18  pay rent #home #money  (2 days overdue)
 4 [ ] low    2026-10-23  water plants  (due in 3 days)
' due
check "due 0"              0 $' 3 [ ] medium 2026-10-18  pay rent #home #money  (2 days overdue)\n' due 0
check "due tag"            0 $' 4 [ ] low    2026-10-23  water plants  (due in 3 days)\n' due 10 -p low

# edit
check "edit"               0 $'Updated task 2: call bob again\n'     edit 2 call bob again -d +2 -t phone
check "edit tags"          0 $'Updated task 3: pay rent\n'           edit 3 --untag money -t bills -p none
check "after edit"         0 $' 3 [ ] -      2026-10-18  pay rent #home #bills\n' list -t home -t bills -s rent --overdue --file "$TODO_FILE"
check "edited due"         0 $' 2 [ ] -      2026-10-22  call bob again #phone\n' list -t phone
check "edit clear due"     0 $'Updated task 2: call bob again\n'     edit 2 -d none
check "edit cleared due"   0 $' 2 [ ] -      -           call bob again #phone\n' list -s again
"$BIN" list -l -s again > "$TMP/long"
check_true "long format" grep -qE '^       created 2026-10-20, uuid [0-9a-f-]{36}$' "$TMP/long"

# rm
check "rm"                 0 $'Removed task 4: water plants\n'       rm 4
check "add after rm"       0 $'Added task 6: new\n'                  add new

# Errors: status 1
check_err "unknown ID"         1 $'todo: no task with ID 9\n'        done 9
check_err "unknown ID rm"      1 $'todo: no task with ID 4\n'        rm 4
check_err "unknown ID edit"    1 $'todo: no task with ID 4\n'        edit 4 x
check "partial failure"        1 $'Completed task 6: new\n'          done 6 99
mkdir "$TMP/dir.json"
check_err "file is a directory" 1 "todo: $TMP/dir.json: not a regular file"$'\n' list --file "$TMP/dir.json"
check_err "missing directory"   1 "todo: $TMP/nodir/todo.json: directory '$TMP/nodir' does not exist"$'\n' add x --file "$TMP/nodir/todo.json"
printf '{"tasks": [' > "$TMP/bad.json"
check_err "invalid JSON"        1 "todo: $TMP/bad.json: invalid JSON: unexpected end of input at character 12"$'\n' list --file "$TMP/bad.json"
printf '{"tasks": [{"id": 1}]}' > "$TMP/bad2.json"
check_err "invalid task"        1 "todo: $TMP/bad2.json: task 1: 'id' and 'title' are required"$'\n' list -f "$TMP/bad2.json"
check_true "bad file untouched" grep -qx '{"tasks": \[{"id": 1}\]}' "$TMP/bad2.json"

# Usage errors: status 2
check_err "no command"         2 "todo: no command given"$'\n'"$USAGE_HINT"
check_err "unknown command"    2 "todo: unknown command 'bogus'"$'\n'"$USAGE_HINT" bogus
check_err "unknown option"     2 "todo: unknown option '-x'"$'\n'"$USAGE_HINT" list -x
check_err "missing value"      2 "todo: option '--tag' requires a value"$'\n'"$USAGE_HINT" add x --tag
check_err "wrong command opt"  2 "todo: option '--all' does not apply to 'add'"$'\n'"$USAGE_HINT" add x -a
check_err "missing text"       2 "todo: add: missing task text"$'\n'"$USAGE_HINT" add
check_err "missing ID"         2 "todo: done: missing task ID"$'\n'"$USAGE_HINT" done
check_err "bad ID"             2 "todo: invalid task ID 'x'"$'\n'"$USAGE_HINT" rm 2 x
check_err "bad priority"       2 "todo: invalid priority 'urgent' (use high, medium, low or none)"$'\n'"$USAGE_HINT" add x -p urgent
check_err "bad date"           2 "todo: invalid date '2026-02-30' (use YYYY-MM-DD, today, tomorrow, +N, +Nw, a weekday or none)"$'\n'"$USAGE_HINT" add x -d 2026-02-30
check_err "bad tag"            2 "todo: invalid tag 'a b' (use letters, digits, '-', '_' and '.')"$'\n'"$USAGE_HINT" add x -t 'a b'
check_err "nothing to edit"    2 "todo: edit: nothing to change (give new text or an option)"$'\n'"$USAGE_HINT" edit 2
check_err "bad days"           2 "todo: due: invalid number of days 'soon'"$'\n'"$USAGE_HINT" due soon
check_err "list argument"      2 "todo: list: unexpected argument 'x'"$'\n'"$USAGE_HINT" list x

# Default file: ./todo.json in the current directory
ABS_BIN="$(cd "$(dirname "$BIN")" && pwd)/$(basename "$BIN")"
(mkdir -p "$TMP/cwd" && cd "$TMP/cwd" && env -u TODO_FILE "$ABS_BIN" add here > /dev/null)
check_true "default ./todo.json" grep -q '"title": "here"' "$TMP/cwd/todo.json"

# help and version
check "version"            0 $'todo (loup-cmd-todo) 0.1.0\n'  --version
"$BIN" --help > "$TMP/help" 2>&1
check_true "--help" grep -q '^usage: todo \[OPTION\]... COMMAND \[ARG\]...$' "$TMP/help"
"$BIN" help > "$TMP/help2" 2>&1
check_true "help command" cmp -s "$TMP/help" "$TMP/help2"

echo "e2e: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
