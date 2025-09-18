#!/bin/bash

set -euo pipefail

: "${FILE_DESCRIPTION_MAPPING:?FILE_DESCRIPTION_MAPPING env is required}"

SUMMARY_FILE=${SUMMARY_FILE:-migration_summary.txt}
: "${INTEGRATED_JSON_PATH:?INTEGRATED_JSON_PATH env is required}"

mapfile -t entries < <(echo "$FILE_DESCRIPTION_MAPPING" | jq -c '.[]')

if [[ ${#entries[@]} -eq 0 ]]; then
  echo "::error::FILE_DESCRIPTION_MAPPING is empty" >&2
  exit 1
fi

echo "|Source|Desc|Integrated|" > "$SUMMARY_FILE"
echo "|---|---|---|" >> "$SUMMARY_FILE"

for entry in "${entries[@]}"; do
  orig_file=$(echo "$entry" | jq -r '.file')
  desc=$(echo "$entry" | jq -r '.description')

  integrated_path=$(jq -r --arg file "$orig_file" '.[$file].integrated_file // ""' "$INTEGRATED_JSON_PATH")
  if [[ -z "$integrated_path" ]]; then
    echo "::error::Unable to locate integrated migration record for $orig_file" >&2
    exit 1
  fi

  migration_file=$(basename "$integrated_path")
  echo "|$orig_file|$desc|$migration_file|" >> "$SUMMARY_FILE"
done

cat "$SUMMARY_FILE"
