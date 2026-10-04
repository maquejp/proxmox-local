#!/usr/bin/env bash

# ==============================================================================
# New project setup
# ==============================================================================

source "${LIB_DIR}/project/git.sh"

source "${LIB_DIR}/project/runtimes/node.sh"
source "${LIB_DIR}/project/runtimes/php.sh"
source "${LIB_DIR}/project/runtimes/java.sh"

source "${LIB_DIR}/project/generators/vite-react.sh"
source "${LIB_DIR}/project/generators/angular.sh"
source "${LIB_DIR}/project/generators/express.sh"
source "${LIB_DIR}/project/generators/laravel.sh"
source "${LIB_DIR}/project/generators/spring-boot.sh"

# ==============================================================================
# Project setup
# ==============================================================================

setup_vite_react_project() {
    install_node
    create_vite_react_project
}

setup_angular_project() {
    install_node
    create_angular_project
}

setup_express_project() {
    install_node
    create_express_project
}

setup_laravel_project() {
    install_php
    install_composer
    create_laravel_project
}

setup_spring_boot_project() {
    install_java
    create_spring_boot_project
}

setup_new_project() {

    local project_dir="/home/${DEV_USER}/${PROJECT_NAME}"

    if run_remote test -e "$project_dir"; then
        error "Project directory already exists: $project_dir"
    fi

    case "$PROJECT_TYPE" in
        frontend)
            case "$FRONTEND" in
                vite-react)
                    setup_vite_react_project
                    ;;
                angular)
                    setup_angular_project
                    ;;
                *)
                    error "Frontend '$FRONTEND' is not implemented yet"
                    ;;
            esac
            ;;
        backend)
            case "$BACKEND" in
                express)
                    setup_express_project
                    ;;
                laravel)
                    setup_laravel_project
                    ;;
                spring-boot)
                    setup_spring_boot_project
                    ;;
                *)
                    error "Backend '$BACKEND' is not implemented yet"
                    ;;
            esac
            ;;
        *)
            error "New project type '$PROJECT_TYPE' is not implemented yet"
            ;;
    esac

    initialize_git

    echo
    echo "Project created successfully."
}
