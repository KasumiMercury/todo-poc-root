#!/bin/bash

set -euo pipefail

: "${CHANGED_TARGETS_JSON:?CHANGED_TARGETS_JSON env is required}"
: "${GITHUB_OUTPUT:?GITHUB_OUTPUT env is required}"

chmod +x .github/scripts/extract-migration-descriptions.sh

# Ensure exactly one target is present.
target_count=$(echo "$CHANGED_TARGETS_JSON" | jq 'keys | length')
if [[ "$target_count" -ne 1 ]]; then
  echo "::error::Expected exactly one migration target, found $target_count" >&2
  exit 1
fi

target_key=$(echo "$CHANGED_TARGETS_JSON" | jq -r 'keys[0]')
target_config=$(echo "$CHANGED_TARGETS_JSON" | jq -c --arg key "$target_key" '.[$key]')

target_pattern=$(echo "$target_config" | jq -r '.pattern')
mapfile -t target_files < <(echo "$target_config" | jq -r '.files[]')

if [[ ${#target_files[@]} -eq 0 ]]; then
  echo "::error::No files recorded for target $target_key" >&2
  exit 1
fi

file_description_mapping='[]'
for file in "${target_files[@]}"; do
  description=$(.github/scripts/extract-migration-descriptions.sh "$target_pattern" "$file" | jq -r '.[0]')

  if [[ -z "$description" || "$description" == "null" ]]; then
    echo "::error::Failed to derive description for $file" >&2
    exit 1
  fi

  file_description_mapping=$(jq -n \
    --argjson existing "$file_description_mapping" \
    --arg file "$file" \
    --arg desc "$description" \
    '$existing + [{file: $file, description: $desc}]')
done

file_description_mapping=$(echo "$file_description_mapping" | jq -c '.')

echo "File-description mapping: $file_description_mapping"

echo "file_description_mapping=$file_description_mapping" >> "$GITHUB_OUTPUT"
