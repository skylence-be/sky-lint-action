#!/bin/sh
# Reads a sky lint JSON output file and emits GitHub Actions workflow annotations.
# Usage: annotate.sh <lint.json>
# Each diagnostic becomes an annotation whose level mirrors its severity:
# diagnostics with severity "warning" emit ::warning (non-blocking, e.g.
# SKY-WF-101 shellcheck/syntax notes); everything else emits ::error.
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
  (if .severity == "warning" then "warning" else "error" end) as $level |
  if .line > 0 then
    "::\($level) file=\($d.file),line=\($d.line),title=\($title)::\($d.message)"
  else
    "::\($level) file=\($d.file),title=\($title)::\($d.message)"
  end
' "$lint_json"
