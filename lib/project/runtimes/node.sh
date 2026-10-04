#!/usr/bin/env bash

# ==============================================================================
# Node.js
# ==============================================================================

NODE_MAJOR_VERSION="24"

install_node() {

    if run_remote command -v node >/dev/null 2>&1; then
        echo "Node.js already installed:"
        run_remote node --version
        return
    fi

    echo "Installing Node.js ${NODE_MAJOR_VERSION}..."

    run_remote bash -s -- "$NODE_MAJOR_VERSION" <<'REMOTE'

set -euo pipefail

NODE_MAJOR_VERSION="$1"

curl -fsSL \
    "https://rpm.nodesource.com/setup_${NODE_MAJOR_VERSION}.x" \
    -o /tmp/nodesource_setup.sh

sudo bash /tmp/nodesource_setup.sh

rm -f /tmp/nodesource_setup.sh

sudo dnf install -y nodejs

REMOTE

    echo "Node.js installed:"
    run_remote node --version
    run_remote npm --version
}
