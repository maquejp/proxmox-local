#!/usr/bin/env bash

# ==============================================================================
# Java
# ==============================================================================

JAVA_MAJOR_VERSION="25"

install_java() {

    if run_remote javac -version >/dev/null 2>&1; then
        echo "Java already installed:"
        run_remote java -version 2>&1 | head -n 1
        return
    fi

    echo "Installing Java ${JAVA_MAJOR_VERSION}..."

    run_remote bash -s -- "$JAVA_MAJOR_VERSION" <<'REMOTE'

set -euo pipefail

JAVA_MAJOR_VERSION="$1"

sudo dnf install -y \
    "java-${JAVA_MAJOR_VERSION}-openjdk-devel" \
    unzip

REMOTE

    echo "Java installed:"
    run_remote java -version 2>&1 | head -n 1
}
