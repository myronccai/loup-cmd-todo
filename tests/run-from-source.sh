#!/usr/bin/env bash
# Runs todo from source with `loup run`, so that `make e2e-run` can put the
# interpreted lane through the same end-to-end tests as build/todo.
exec "${LOUP:-loup}" run "$(cd "$(dirname "$0")/.." && pwd)/source/main.loup" -- "$@"
