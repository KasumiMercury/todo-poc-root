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

declare -A file_status_map=()
changed_sql_files=()

while IFS=$'\t' read -r status path extra; do
  [[ -z "$status" || -z "$path" ]] && continue

  local_path=""
  case "$status" in
    R*)
      # Renames provide old and new paths.
      [[ -z "$extra" ]] && continue
      local_path="$extra"
      file_status_map["$extra"]="R"
      ;;
    *)
      local_path="$path"
      file_status_map["$path"]="$status"
      ;;
  esac

  [[ $local_path != *.sql ]] && continue

  changed_sql_files+=("$local_path")
done < <(git diff --name-status --diff-filter=AMR "${BASE_SHA}..${HEAD_SHA}")

if [[ ${#changed_sql_files[@]} -eq 0 ]]; then
  log "No SQL files were added or modified in this pull request."
  {
    echo 'changed_targets_count=0'
    echo 'changed_targets_config={}'
  } >> "$GITHUB_OUTPUT"
  exit 0
fi

log "Found SQL files:"
printf '%s\n' "${changed_sql_files[@]}"

# Remove files that are already tracked in the integrated manifest.
declare -A integrated_sha_map=()
if [[ -f "$INTEGRATED_JSON_PATH" ]]; then
  while IFS=$'\t' read -r source_file source_sha; do
    [[ -z "$source_file" ]] && continue
    integrated_sha_map["$source_file"]="$source_sha"
  done < <(jq -r 'to_entries[] | "\(.key)\t\(.value.source_sha // \"\")"' "$INTEGRATED_JSON_PATH")
fi

filtered_sql_files=()
invalid_updates=()
declare -A seen_filtered=()
for file in "${changed_sql_files[@]}"; do
  [[ -z "$file" ]] && continue
  if [[ ! -f "$file" ]]; then
    # File might have been deleted or renamed; skip.
    continue
  fi

  status=${file_status_map[$file]:-}
  # Renaming executed migrations is not allowed.
  if [[ $status == R* ]]; then
    invalid_updates+=("$file (rename)")
    continue
  fi

  stored_sha=${integrated_sha_map[$file]:-}
  if [[ -n "$stored_sha" && $status != A* ]]; then
    invalid_updates+=("$file")
    continue
  fi

  if [[ -n "$stored_sha" ]]; then
    current_sha=$(sha256sum "$file" | awk '{print $1}')
    if [[ "$stored_sha" == "$current_sha" ]]; then
      continue
    fi
  fi

  if [[ -z "${seen_filtered[$file]:-}" ]]; then
    filtered_sql_files+=("$file")
    seen_filtered["$file"]=1
  fi
done

if [[ ${#invalid_updates[@]} -gt 0 ]]; then
  echo "::error::Attempted to modify already executed migrations: ${invalid_updates[*]}" >&2
  exit 1
fi

if [[ ${#filtered_sql_files[@]} -eq 0 ]]; then
  log "No SQL file changes require integration."
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
