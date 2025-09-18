#!/bin/bash

set -euo pipefail

usage() {
    echo "Usage: $0 <migration_targets_json> <file1> [file2 ...]"
    echo ""
    echo "Detect which migration targets are affected by changed files."
    echo ""
    echo "Arguments:"
    echo "  migration_targets_json    JSON string containing migration target configurations"
    echo "  files                   List of changed files to analyze"
    echo ""
    echo "Output:"
    echo "  JSON array of affected target names (e.g., [\"flyway\",\"atlas\"])"
    echo ""
    echo "Examples:"
    echo "  $0 '{\"flyway\":{\"directory\":\"flyway_test\"}}' flyway_test/V1__create.sql"
    echo "  Output: [\"flyway\"]"
}

main() {
    local migration_targets_json=""
    local files=()
    declare -A affected_targets_map=()

    if [[ $# -lt 2 ]]; then
        echo "Error: At least 2 arguments required" >&2
        usage >&2
        exit 1
    fi

    migration_targets_json="$1"
    shift

    files=("$@")

    if ! echo "$migration_targets_json" | jq empty 2>/dev/null; then
        echo "Error: Invalid JSON in migration_targets_json parameter" >&2
        exit 1
    fi

    for file in "${files[@]}"; do
        [[ -z "$file" ]] && continue

        local matched_target=""
        matched_target=$(echo "$migration_targets_json" | jq -r --arg file "$file" '
            to_entries[] |
            (.value.directory + "/") as $dir |
            select($file | startswith($dir)) |
            .key' | head -n1)

        if [[ -n "$matched_target" ]]; then
            affected_targets_map["$matched_target"]=1
        fi
    done

    if [[ ${#affected_targets_map[@]} -eq 0 ]]; then
        jq -n '[]'
        return 0
    fi

    local sorted_targets=()
    readarray -t sorted_targets < <(printf '%s\n' "${!affected_targets_map[@]}" | sort)

    printf '%s\n' "${sorted_targets[@]}" | jq -R '.' | jq -s '.'
}

# Handle help option
if [[ $# -gt 0 && ("$1" == "-h" || "$1" == "--help") ]]; then
    usage
    exit 0
fi

main "$@"
