#!/bin/bash

set -euo pipefail

: "${FILE_DESCRIPTION_MAPPING:?FILE_DESCRIPTION_MAPPING env is required}"

SUMMARY_FILE=${SUMMARY_FILE:-migration_summary.txt}
ATLAS_DIR=${INTEGRATED_DIR:-db/integrated}

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

 migration_file=$(find "$ATLAS_DIR" -type f -name "*${desc}*.sql" | head -n 1)
  if [[ -z "$migration_file" ]]; then
    echo "::error::Unable to locate integrated migration for $desc" >&2
    exit 1
  fi

  migration_file=$(basename "$migration_file")
  echo "|$orig_file|$desc|$migration_file|" >> "$SUMMARY_FILE"
done

cat "$SUMMARY_FILE"
