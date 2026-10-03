#!/usr/bin/env bash

set -euo pipefail

prompt_choice() {
    local prompt="$1"
    local max="$2"
    local choice

    while true; do
        read -r -p "$prompt" choice

        if [[ "$choice" =~ ^[1-9][0-9]*$ ]] && (( choice <= max )); then
            printf '%s\n' "$choice"
            return
        fi

        echo "Invalid choice. Please enter a number between 1 and $max." >&2
    done
}

echo "=== Project Setup ==="
echo

read -r -p "Project name: " project_name

if [[ -z "$project_name" ]]; then
    echo "Project name cannot be empty." >&2
    exit 1
fi

echo
echo "Project source:"
echo "  1) New project"
echo "  2) Existing repository"

source_choice=$(prompt_choice "Choice: " 2)

case "$source_choice" in
    1)
        project_source="new"
        ;;
    2)
        project_source="existing"
        ;;
esac

echo
echo "Project type:"
echo "  1) Frontend"
echo "  2) Backend / API"
echo "  3) Full-stack"
echo "  4) Other"

type_choice=$(prompt_choice "Choice: " 4)

case "$type_choice" in
    1)
        project_type="frontend"
        ;;
    2)
        project_type="backend"
        ;;
    3)
        project_type="fullstack"
        ;;
    4)
        project_type="other"
        ;;
esac

echo
echo "Project configuration:"
echo
printf '  Name   : %s\n' "$project_name"
printf '  Source : %s\n' "$project_source"
printf '  Type   : %s\n' "$project_type"
echo
echo "Project setup is not implemented yet."