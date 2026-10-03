#!/usr/bin/env bash

# ==============================================================================
# GitHub SSH setup
# ==============================================================================

is_github_ssh_url() {

    [[ "$REPOSITORY_URL" == git@github.com:* ]]
}

configure_github_ssh() {

    run_remote mkdir -p "/home/${DEV_USER}/.ssh"
    run_remote chmod 700 "/home/${DEV_USER}/.ssh"

    local ssh_config

    ssh_config=$(cat <<EOF
Host github.com
    HostName github.com
    User git
    IdentityFile ${GITHUB_SSH_PRIVATE_KEY}
    IdentitiesOnly yes
EOF
)

    run_remote \
        "printf '%s\n' '$ssh_config' > /home/${DEV_USER}/.ssh/config"

    run_remote chmod 600 "/home/${DEV_USER}/.ssh/config"
}

add_github_host_key() {

    echo "Adding GitHub host key..."

    local github_host_key

    github_host_key=$(ssh-keyscan github.com 2>/dev/null)

    if [[ -z "$github_host_key" ]]; then
        error "Failed to retrieve GitHub host key"
    fi

    run_remote \
        "printf '%s\n' '$github_host_key' >> /home/${DEV_USER}/.ssh/known_hosts"

    run_remote chmod 644 "/home/${DEV_USER}/.ssh/known_hosts"
}

setup_github_ssh() {

    echo
    echo "Checking GitHub SSH authentication..."

    run_remote mkdir -p "/home/${DEV_USER}/.ssh"
    run_remote chmod 700 "/home/${DEV_USER}/.ssh"

    if ! run_remote test -f "$GITHUB_SSH_PRIVATE_KEY" ||
       ! run_remote test -f "$GITHUB_SSH_PUBLIC_KEY"; then

        echo
        echo "No GitHub SSH key found on the VM."
        echo "Generating a dedicated GitHub SSH key..."

        run_remote ssh-keygen \
            -t ed25519 \
            -C "dev@${VMID}" \
            -f "$GITHUB_SSH_PRIVATE_KEY" \
            -N '""'

        run_remote chmod 600 "$GITHUB_SSH_PRIVATE_KEY"
        run_remote chmod 644 "$GITHUB_SSH_PUBLIC_KEY"
    fi

    run_remote touch "/home/${DEV_USER}/.ssh/known_hosts"

    if ! run_remote grep -q "github.com" "/home/${DEV_USER}/.ssh/known_hosts"; then
        add_github_host_key
    fi

    configure_github_ssh

    local public_key

    public_key=$(run_remote cat "$GITHUB_SSH_PUBLIC_KEY")

    echo
    echo "GitHub SSH public key:"
    echo
    echo "$public_key"
    echo
    echo "Add this key to your GitHub account:"
    echo "GitHub → Settings → SSH and GPG keys"
    echo

    read -r -p "Press Enter once the key has been added to GitHub..."

    echo
    echo "Testing GitHub SSH authentication..."

    local github_result

    github_result=$(
        run_remote ssh \
            -i "$GITHUB_SSH_PRIVATE_KEY" \
            -o BatchMode=yes \
            -o IdentitiesOnly=yes \
            -o StrictHostKeyChecking=yes \
            -o ConnectTimeout=5 \
            -T git@github.com 2>&1 || true
    )

    if [[ "$github_result" != *"successfully authenticated"* ]]; then

        echo "$github_result" >&2

        error "GitHub SSH authentication failed"
    fi

    echo "GitHub SSH authentication OK."
}