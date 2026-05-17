#!/usr/bin/env bash
set -uo pipefail

if [ "$#" -lt 3 ]; then
  printf 'usage: %s <log-file> <description> <command> [args...]\n' "$0" >&2
  exit 2
fi

log_file="$1"
description="$2"
shift 2

mkdir -p "$(dirname "$log_file")"

{
  printf '## %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf 'description: %s\n' "$description"
  printf 'cwd: %s\n' "$(pwd)"
  printf 'command:'
  printf ' %q' "$@"
  printf '\n\n'
} >>"$log_file"

"$@" > >(tee -a "$log_file") 2> >(tee -a "$log_file" >&2)
status=$?

{
  printf '\nexit_code: %s\n\n' "$status"
} >>"$log_file"

exit "$status"
