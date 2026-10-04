show_project_summary() {

    echo
    echo "Project target:"
    echo
    printf '  VM ID    : %s\n' "$VMID"
    printf '  VM IP    : %s\n' "$VM_IP"
    printf '  User     : %s\n' "$DEV_USER"

    echo
    echo "Project configuration:"
    echo
    printf '  Name     : %s\n' "$PROJECT_NAME"
    printf '  Source   : %s\n' "$PROJECT_SOURCE"

    if [[ -n "$PROJECT_TYPE" ]]; then
        printf '  Type     : %s\n' "$PROJECT_TYPE"
    fi

    if [[ -n "$REPOSITORY_URL" ]]; then
        printf '  Repo     : %s\n' "$REPOSITORY_URL"
    fi

    if [[ -n "$FRONTEND" ]]; then
        printf '  Frontend : %s\n' "$FRONTEND"
    fi

    if [[ -n "$BACKEND" ]]; then
        printf '  Backend  : %s\n' "$BACKEND"
    fi

    if [[ -n "$DATABASE_STRATEGY" ]]; then
        printf '  Database : %s\n' "$DATABASE_STRATEGY"
    fi

    if [[ -n "$DATABASE_ENGINE" ]]; then
        printf '  Engine   : %s\n' "$DATABASE_ENGINE"
    fi

    if [[ -n "$DATABASE_VERSION" ]]; then
        printf '  Version  : %s\n' "$DATABASE_VERSION"
    fi
}