#!/bin/bash

set -euo pipefail

: "${FILE_DESCRIPTION_MAPPING:?FILE_DESCRIPTION_MAPPING env is required}"
: "${GITHUB_OUTPUT:?GITHUB_OUTPUT env is required}"

ATLAS_DIR=${INTEGRATED_DIR:-db/integrated}
INTEGRATED_JSON_PATH=${INTEGRATED_JSON_PATH:-db/integrated.json}

latest_sql_file() {
  local dir=$1
  local latest=""
  local latest_mtime=0
  local file

  shopt -s nullglob
  for file in "$dir"/*.sql; do
    local mtime
    mtime=$(stat -c %Y "$file")
    if (( mtime > latest_mtime )); then
      latest_mtime=$mtime
      latest="$file"
    fi
  done
  shopt -u nullglob

  printf '%s' "$latest"
}

mapfile -t entries < <(echo "$FILE_DESCRIPTION_MAPPING" | jq -c '.[]')

if [[ ${#entries[@]} -eq 0 ]]; then
  echo "::error::FILE_DESCRIPTION_MAPPING is empty" >&2
  exit 1
fi

mkdir -p "$ATLAS_DIR"

declare -A existing_integrated_map=()
if [[ -f "$INTEGRATED_JSON_PATH" ]]; then
  while IFS=$'\t' read -r source_path integrated_path _; do
    [[ -z "$source_path" || -z "$integrated_path" || "$integrated_path" == "null" ]] && continue
    existing_integrated_map["$source_path"]="$integrated_path"
  done < <(jq -r 'to_entries[] | "\(.key)\t\(.value.integrated_file // \"\")\t\(.value.source_sha // \"\")"' "$INTEGRATED_JSON_PATH")
fi

for entry in "${entries[@]}"; do
  description=$(echo "$entry" | jq -r '.description')
  source_file=$(echo "$entry" | jq -r '.file')

  echo "Processing migration: $description from $source_file"

  if [[ ! -f "$source_file" ]]; then
    echo "::error::Source migration file $source_file not found" >&2
    exit 1
  fi

  source_sha=$(sha256sum "$source_file" | awk '{print $1}')

  target_file=${existing_integrated_map[$source_file]:-}
  if [[ -n "$target_file" ]]; then
    target_file=${target_file#./}
  fi
  if [[ -n "$target_file" && -f "$target_file" ]]; then
    echo "Reusing existing integrated file $target_file"
  else
    atlas migrate new "$description" --dir "file://$ATLAS_DIR"
    target_file=$(latest_sql_file "$ATLAS_DIR")
    if [[ -z "$target_file" ]]; then
      echo "::error::Atlas did not create a migration file for $description" >&2
      exit 1
    fi
    # Ensure path is stored relative to repository root.
    target_file=${target_file#./}
    existing_integrated_map["$source_file"]="$target_file"
  fi

  cat "$source_file" > "$target_file"

  echo "Processed: $description -> $target_file"

  if [[ ! -f "$INTEGRATED_JSON_PATH" ]]; then
    echo '{}' > "$INTEGRATED_JSON_PATH"
  fi

  tmp_file=$(mktemp)
  jq --arg file "$source_file" \
     --arg desc "$description" \
     --arg integrated "$target_file" \
     --arg sha "$source_sha" \
     '. + {($file): {"description": $desc, "integrated_file": $integrated, "source_sha": $sha}}' \
     "$INTEGRATED_JSON_PATH" > "$tmp_file"
  mv "$tmp_file" "$INTEGRATED_JSON_PATH"
done

atlas migrate hash --dir "file://$ATLAS_DIR"

descriptions=$(echo "$FILE_DESCRIPTION_MAPPING" | jq -r 'map(.description) | join(", ")')

echo "descriptions=$descriptions" >> "$GITHUB_OUTPUT"
