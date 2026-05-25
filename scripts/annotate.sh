#!/bin/sh
# Reads a sky lint JSON output file and emits GitHub Actions workflow annotations.
# Usage: annotate.sh <lint.json>
# Each diagnostic becomes ::error with file, line, and title attributes.
set -e

lint_json="${1:?lint.json path required}"

if [ ! -f "$lint_json" ]; then
  echo "annotate.sh: $lint_json not found, skipping annotations" >&2
  exit 0
fi

count=$(jq 'length' "$lint_json")
if [ "$count" -eq 0 ]; then
  exit 0
fi

jq -r '
  .[] |
  . as $d |
  (if .rule != "" and .rule != null then .rule else "sky-lint" end) as $title |
  if .line > 0 then
    "::error file=\($d.file),line=\($d.line),title=\($title)::\($d.message)"
  else
    "::error file=\($d.file),title=\($title)::\($d.message)"
  end
' "$lint_json"
