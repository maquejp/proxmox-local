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

if [[ "$project_source" == "existing" ]]; then
    echo
    read -r -p "Repository URL: " repository_url

    if [[ -z "$repository_url" ]]; then
        echo "Repository URL cannot be empty." >&2
        exit 1
    fi
fi

if [[ "$project_source" == "new" ]]; then
    case "$project_type" in
        frontend)
            echo
            echo "Frontend:"
            echo "  1) Vite + React"
            echo "  2) Angular"

            frontend_choice=$(prompt_choice "Choice: " 2)

            case "$frontend_choice" in
                1)
                    frontend="vite-react"
                    ;;
                2)
                    frontend="angular"
                    ;;
            esac
            ;;

        backend)
            echo
            echo "Backend:"
            echo "  1) Express"
            echo "  2) Laravel"
            echo "  3) Spring Boot"

            backend_choice=$(prompt_choice "Choice: " 3)

            case "$backend_choice" in
                1)
                    backend="express"
                    ;;
                2)
                    backend="laravel"
                    ;;
                3)
                    backend="spring-boot"
                    ;;
            esac
            ;;

        fullstack)
            echo
            echo "Frontend:"
            echo "  1) Vite + React"
            echo "  2) Angular"

            frontend_choice=$(prompt_choice "Choice: " 2)

            case "$frontend_choice" in
                1)
                    frontend="vite-react"
                    ;;
                2)
                    frontend="angular"
                    ;;
            esac

            echo
            echo "Backend:"
            echo "  1) Express"
            echo "  2) Laravel"
            echo "  3) Spring Boot"

            backend_choice=$(prompt_choice "Choice: " 3)

            case "$backend_choice" in
                1)
                    backend="express"
                    ;;
                2)
                    backend="laravel"
                    ;;
                3)
                    backend="spring-boot"
                    ;;
            esac
            ;;
    esac
fi

if [[ "$project_source" == "new" && -n "${backend:-}" ]]; then
    echo
    echo "Database:"
    echo "  1) None"
    echo "  2) Create database on this VM"
    echo "  3) Use an existing database VM"

    database_choice=$(prompt_choice "Choice: " 3)

    case "$database_choice" in
        1)
            database_strategy="none"
            ;;
        2)
            database_strategy="local"
            ;;
        3)
            database_strategy="existing-vm"
            ;;
    esac

    if [[ "$database_strategy" == "local" ]]; then
        echo
        echo "Database engine:"
        echo "  1) PostgreSQL"
        echo "  2) MariaDB"
        echo "  3) MongoDB"

        database_engine_choice=$(prompt_choice "Choice: " 3)

        case "$database_engine_choice" in
            1)
                database_engine="postgresql"
                ;;
            2)
                database_engine="mariadb"
                ;;
            3)
                database_engine="mongodb"
                ;;
        esac
    fi
fi

echo
echo "Project configuration:"
echo
printf '  Name     : %s\n' "$project_name"
printf '  Source   : %s\n' "$project_source"
printf '  Type     : %s\n' "$project_type"

if [[ "$project_source" == "existing" ]]; then
    printf '  Repo     : %s\n' "$repository_url"
fi

if [[ -n "${frontend:-}" ]]; then
    printf '  Frontend : %s\n' "$frontend"
fi

if [[ -n "${backend:-}" ]]; then
    printf '  Backend  : %s\n' "$backend"
fi

if [[ -n "${database_strategy:-}" ]]; then
    printf '  Database : %s\n' "$database_strategy"
fi

if [[ -n "${database_engine:-}" ]]; then
    printf '  Engine   : %s\n' "$database_engine"
fi

echo
echo "Project setup is not implemented yet."