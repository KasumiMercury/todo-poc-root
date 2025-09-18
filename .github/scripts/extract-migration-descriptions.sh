#!/bin/bash

set -euo pipefail

usage() {
    echo "Usage: $0 [OPTIONS] <regex_pattern> <file1> [file2 ...]"
    echo ""
    echo "Extract description parts from migration file names using a regex pattern and output as JSON array."
    echo ""
    echo "Arguments:"
    echo "  regex_pattern    Regular expression pattern with one capture group for the description"
    echo "  files           Migration files to process"
    echo ""
    echo "Options:"
    echo "  -h, --help      Show this help message"
    echo ""
    echo "Examples:"
    echo "  # With find command"
    echo "  find migrations -name '*.sql' | xargs $0 '^V[0-9]+__(.+)\\.sql$'"
}

main() {
    local regex_pattern=""
    local files=()
    local descriptions=()
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -*)
                echo "Unknown option: $1" >&2
                usage >&2
                exit 1
                ;;
            *)
                if [[ -z "$regex_pattern" ]]; then
                    regex_pattern="$1"
                else
                    files+=("$1")
                fi
                ;;
        esac
        shift
    done
    
    if [[ -z "$regex_pattern" ]]; then
        echo "Error: Regex pattern is required" >&2
        usage >&2
        exit 1
    fi
    
    if [[ ${#files[@]} -eq 0 ]]; then
        echo "Error: No files specified" >&2
        usage >&2
        exit 1
    fi
    
    for file in "${files[@]}"; do
        local basename_file
        basename_file=$(basename "$file")
        
        if [[ $basename_file =~ $regex_pattern ]]; then
            if [[ ${#BASH_REMATCH[@]} -gt 1 ]]; then
                descriptions+=("${BASH_REMATCH[1]}")
            else
                echo "Warning: Regex pattern '$regex_pattern' does not contain a capture group for file '$file'" >&2
            fi
        else
            echo "Warning: File '$file' does not match pattern '$regex_pattern'" >&2
        fi
    done
    
    if [[ ${#descriptions[@]} -gt 0 ]]; then
        printf '['
        for i in "${!descriptions[@]}"; do
            if [[ $i -gt 0 ]]; then
                printf ','
            fi
            printf '"%s"' "${descriptions[$i]}"
        done
        printf ']\n'
    else
        printf '[]\n'
    fi
}

main "$@"