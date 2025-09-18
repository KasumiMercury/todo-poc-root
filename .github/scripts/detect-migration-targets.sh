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
    local affected_targets=()
    
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
        if [[ -n "$file" ]]; then
            matched_target=$(echo "$migration_targets_json" | jq -r --arg file "$file" '
                to_entries[] | 
                (.value.directory + "/") as $dir | 
                select($file | startswith($dir)) | 
                .key' | head -n1)
            
            if [[ -n "$matched_target" ]]; then
                local already_added=false
                for existing_target in "${affected_targets[@]}"; do
                    if [[ "$existing_target" == "$matched_target" ]]; then
                        already_added=true
                        break
                    fi
                done
                if [[ "$already_added" == "false" ]]; then
                    affected_targets+=("$matched_target")
                fi
            fi
        fi
    done
    
    if [[ ${#affected_targets[@]} -gt 0 ]]; then
        readarray -t sorted_targets < <(printf '%s\n' "${affected_targets[@]}" | sort)
        affected_targets=("${sorted_targets[@]}")
    fi
    
    printf '['
    for i in "${!affected_targets[@]}"; do
        if [[ $i -gt 0 ]]; then
            printf ','
        fi
        printf '"%s"' "${affected_targets[$i]}"
    done
    printf ']\n'
}

# Handle help option
if [[ $# -gt 0 && ("$1" == "-h" || "$1" == "--help") ]]; then
    usage
    exit 0
fi

main "$@"