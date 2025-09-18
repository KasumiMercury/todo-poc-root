#!/bin/bash

set -euo pipefail

: "${MIGRATION_TARGETS:?MIGRATION_TARGETS env is required}"
: "${BASE_SHA:?BASE_SHA env is required}"
: "${HEAD_SHA:?HEAD_SHA env is required}"
: "${GITHUB_OUTPUT:?GITHUB_OUTPUT env is required}"

INTEGRATED_JSON_PATH=${INTEGRATED_JSON_PATH:-db/integrated.json}

log() {
  printf '%s\n' "$1"
}

log "Detecting all added SQL files..."

mapfile -t all_added_sql_files < <(
  git diff --name-only --diff-filter=A "${BASE_SHA}..${HEAD_SHA}" \
    | grep '\\.sql$' || true
)

if [[ ${#all_added_sql_files[@]} -eq 0 ]]; then
  log "No SQL files were added in this pull request."
  {
    echo 'changed_targets_count=0'
    echo 'changed_targets_config={}'
  } >> "$GITHUB_OUTPUT"
  exit 0
fi

log "Found SQL files:"
printf '%s\n' "${all_added_sql_files[@]}"

# Remove files that are already tracked in the integrated manifest.
declare -A integrated_map=()
if [[ -f "$INTEGRATED_JSON_PATH" ]]; then
  while IFS= read -r integrated_file; do
    integrated_map["$integrated_file"]=1
  done < <(jq -r 'keys[]' "$INTEGRATED_JSON_PATH")
fi

filtered_sql_files=()
for file in "${all_added_sql_files[@]}"; do
  if [[ -n "${integrated_map[$file]:-}" ]]; then
    continue
  fi
  filtered_sql_files+=("$file")
done

if [[ ${#filtered_sql_files[@]} -eq 0 ]]; then
  log "All detected SQL files are already integrated."
  {
    echo 'changed_targets_count=0'
    echo 'changed_targets_config={}'
  } >> "$GITHUB_OUTPUT"
  exit 0
fi

chmod +x .github/scripts/detect-migration-targets.sh

affected_targets_json=$(.github/scripts/detect-migration-targets.sh "$MIGRATION_TARGETS" "${filtered_sql_files[@]}")
affected_targets_json=$(echo "$affected_targets_json" | jq -c '.')

log "Affected targets: $affected_targets_json"

mapfile -t target_keys < <(echo "$affected_targets_json" | jq -r '.[]')

changed_targets_json='{}'
for target_key in "${target_keys[@]}"; do
  target_config=$(echo "$MIGRATION_TARGETS" | jq -c --arg key "$target_key" '.[$key]')
  target_dir=$(echo "$target_config" | jq -r '.directory')

  target_files=()
  for file in "${filtered_sql_files[@]}"; do
    if [[ $file == "$target_dir/"* ]]; then
      target_files+=("$file")
    fi
  done

  [[ ${#target_files[@]} -eq 0 ]] && continue

  target_files_json=$(printf '%s\n' "${target_files[@]}" | jq -R '.' | jq -s -c '.')

  changed_targets_json=$(jq -n \
    --argjson existing "$changed_targets_json" \
    --arg key "$target_key" \
    --argjson cfg "$target_config" \
    --argjson files "$target_files_json" \
    '$existing + {($key): ($cfg + {files: $files})}')
done

changed_targets_json=$(echo "$changed_targets_json" | jq -c '.')
changed_count=$(echo "$changed_targets_json" | jq 'keys | length')

{
  echo "changed_targets_count=$changed_count"
  echo "changed_targets_config=$changed_targets_json"
} >> "$GITHUB_OUTPUT"
