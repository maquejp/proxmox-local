#!/usr/bin/env bash

# ==============================================================================
# Project prompts and configuration
# ==============================================================================

prompt_choice() {

    local prompt="$1"
    local max="$2"
    local choice

    while true; do
        read -r -p "$prompt" choice

        if [[ "$choice" =~ ^[1-9][0-9]*$ ]] &&
           (( choice <= max )); then

            printf '%s\n' "$choice"
            return
        fi

        echo "Invalid choice. Please enter a number between 1 and $max." >&2
    done
}

prompt_project_name() {

    read -r -p "Project name: " PROJECT_NAME

    if [[ -z "$PROJECT_NAME" ]]; then
        error "Project name cannot be empty"
    fi
}

prompt_project_source() {

    echo
    echo "Project source:"
    echo "  1) New project"
    echo "  2) Existing repository"

    local choice
    choice=$(prompt_choice "Choice: " 2)

    case "$choice" in
        1)
            PROJECT_SOURCE="new"
            ;;
        2)
            PROJECT_SOURCE="existing"
            ;;
    esac
}

prompt_repository_url() {

    echo
    read -r -p "Repository URL: " REPOSITORY_URL

    if [[ -z "$REPOSITORY_URL" ]]; then
        error "Repository URL cannot be empty"
    fi
}

prompt_project_type() {

    echo
    echo "Project type:"
    echo "  1) Frontend"
    echo "  2) Backend / API"
    echo "  3) Full-stack"
    echo "  4) Other"

    local choice
    choice=$(prompt_choice "Choice: " 4)

    case "$choice" in
        1)
            PROJECT_TYPE="frontend"
            ;;
        2)
            PROJECT_TYPE="backend"
            ;;
        3)
            PROJECT_TYPE="fullstack"
            ;;
        4)
            PROJECT_TYPE="other"
            ;;
    esac
}

prompt_frontend() {

    echo
    echo "Frontend:"
    echo "  1) Vite + React"
    echo "  2) Angular"

    local choice
    choice=$(prompt_choice "Choice: " 2)

    case "$choice" in
        1)
            FRONTEND="vite-react"
            ;;
        2)
            FRONTEND="angular"
            ;;
    esac
}

prompt_backend() {

    echo
    echo "Backend:"
    echo "  1) Express"
    echo "  2) Laravel"
    echo "  3) Spring Boot"

    local choice
    choice=$(prompt_choice "Choice: " 3)

    case "$choice" in
        1)
            BACKEND="express"
            ;;
        2)
            BACKEND="laravel"
            ;;
        3)
            BACKEND="spring-boot"
            ;;
    esac
}

prompt_database() {

    echo
    echo "Database:"
    echo "  1) None"
    echo "  2) Create database on this VM"
    echo "  3) Use an existing database VM"

    local choice
    choice=$(prompt_choice "Choice: " 3)

    case "$choice" in
        1)
            DATABASE_STRATEGY="none"
            ;;
        2)
            DATABASE_STRATEGY="local"
            ;;
        3)
            DATABASE_STRATEGY="existing-vm"
            ;;
    esac

    if [[ "$DATABASE_STRATEGY" == "local" ]]; then
        prompt_database_engine
    fi
}

prompt_database_engine() {

    echo
    echo "Database engine:"
    echo "  1) PostgreSQL"
    echo "  2) MariaDB"
    echo "  3) MongoDB"

    local choice
    choice=$(prompt_choice "Choice: " 3)

    case "$choice" in
        1)
            DATABASE_ENGINE="postgresql"
            ;;
        2)
            DATABASE_ENGINE="mariadb"
            ;;
        3)
            DATABASE_ENGINE="mongodb"
            ;;
    esac

    prompt_database_version
}

prompt_database_version() {

    echo
    echo "Database version for $DATABASE_ENGINE:"

    case "$DATABASE_ENGINE" in
        postgresql)
            echo "  1) PostgreSQL 17 (Latest)"
            echo "  2) PostgreSQL 16"
            echo "  3) PostgreSQL 15"
            local choice
            choice=$(prompt_choice "Choice: " 3)
            case "$choice" in
                1) DATABASE_VERSION="17" ;;
                2) DATABASE_VERSION="16" ;;
                3) DATABASE_VERSION="15" ;;
            esac
            ;;
        mariadb)
            echo "  1) MariaDB 11.4 (LTS)"
            echo "  2) MariaDB 10.11 (LTS)"
            local choice
            choice=$(prompt_choice "Choice: " 2)
            case "$choice" in
                1) DATABASE_VERSION="11.4" ;;
                2) DATABASE_VERSION="10.11" ;;
            esac
            ;;
        mongodb)
            echo "  1) MongoDB 8.0 (Latest)"
            echo "  2) MongoDB 7.0"
            local choice
            choice=$(prompt_choice "Choice: " 2)
            case "$choice" in
                1) DATABASE_VERSION="8.0" ;;
                2) DATABASE_VERSION="7.0" ;;
            esac
            ;;
    esac
}

prompt_git_identity() {

    echo
    echo "Git configuration:"

    local default_name="Developer"
    local default_email="dev@example.com"
    local git_name
    local git_email

    read -r -p "Git user name [$default_name]: " git_name
    read -r -p "Git user email [$default_email]: " git_email

    git_name="${git_name:-$default_name}"
    git_email="${git_email:-$default_email}"

    GIT_USER_NAME="$git_name"
    GIT_USER_EMAIL="$git_email"
}

configure_new_project() {

    prompt_project_type

    case "$PROJECT_TYPE" in
        frontend)
            prompt_frontend
            ;;
        backend)
            prompt_backend
            ;;
        fullstack)
            prompt_frontend
            prompt_backend
            ;;
        other)
            ;;
    esac

    if [[ -n "$BACKEND" ]]; then
        prompt_database
    fi

    prompt_git_identity
}