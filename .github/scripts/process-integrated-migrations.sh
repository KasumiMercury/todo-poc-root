#!/bin/bash

set -euo pipefail

: "${FILE_DESCRIPTION_MAPPING:?FILE_DESCRIPTION_MAPPING env is required}"
: "${GITHUB_OUTPUT:?GITHUB_OUTPUT env is required}"

ATLAS_DIR=${INTEGRATED_DIR:-db/integrated}
INTEGRATED_JSON_PATH=${INTEGRATED_JSON_PATH:-db/integrated.json}

mapfile -t entries < <(echo "$FILE_DESCRIPTION_MAPPING" | jq -c '.[]')

if [[ ${#entries[@]} -eq 0 ]]; then
  echo "::error::FILE_DESCRIPTION_MAPPING is empty" >&2
  exit 1
fi

mkdir -p "$ATLAS_DIR"

for entry in "${entries[@]}"; do
  description=$(echo "$entry" | jq -r '.description')
  source_file=$(echo "$entry" | jq -r '.file')

  echo "Processing migration: $description from $source_file"

  if [[ ! -f "$source_file" ]]; then
    echo "::error::Source migration file $source_file not found" >&2
    exit 1
  fi

 atlas migrate new "$description" --dir "file://$ATLAS_DIR"

 found_file=$(find "$ATLAS_DIR" -type f -name "*${description}*.sql" | head -n 1)
  if [[ -z "$found_file" ]]; then
    echo "::error::Migration file not found for $description" >&2
    exit 1
  fi

  cat "$source_file" > "$found_file"

 atlas migrate hash --dir "file://$ATLAS_DIR"

  echo "Processed: $description -> $found_file"

  if [[ ! -f "$INTEGRATED_JSON_PATH" ]]; then
    echo '{}' > "$INTEGRATED_JSON_PATH"
  fi

  tmp_file=$(mktemp)
  jq --arg file "$source_file" --arg desc "$description" --arg integrated "$found_file" \
    '. + {($file): {"description": $desc, "integrated_file": $integrated}}' \
    "$INTEGRATED_JSON_PATH" > "$tmp_file"
  mv "$tmp_file" "$INTEGRATED_JSON_PATH"
done

descriptions=$(echo "$FILE_DESCRIPTION_MAPPING" | jq -r 'map(.description) | join(", ")')

echo "descriptions=$descriptions" >> "$GITHUB_OUTPUT"
