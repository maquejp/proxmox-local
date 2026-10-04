#!/usr/bin/env bash

# ==============================================================================
# MariaDB Installation & Setup for Rocky Linux / EL 10
# ==============================================================================

install_mariadb() {
    local version="$1"

    if run_remote command -v mariadb >/dev/null 2>&1; then
        echo "MariaDB is already installed."
        return
    fi

    echo "Installing MariaDB ${version}..."

    # Configure the official MariaDB repository and install
    run_remote bash -s -- "$version" <<'REMOTE'
set -euo pipefail
VERSION="$1"

# Create MariaDB .repo file
# Using the MariaDB foundation repository generator structure
sudo tee /etc/yum.repos.d/mariadb.repo > /dev/null <<EOF
# MariaDB foundation repository
[mariadb]
name = MariaDB
baseurl = https://dlm.mariadb.com/repo/mariadb-server/${VERSION}/yum/rhel/10/x86_64
gpgkey = https://supplychain.mariadb.com/MariaDB-Server-GPG-KEY
gpgcheck = 1
enabled = 1
EOF

# Clean cache and install
sudo dnf clean all
sudo dnf install -y MariaDB-server MariaDB-client

# Start and enable MariaDB
sudo systemctl enable mariadb
sudo systemctl restart mariadb

REMOTE

    echo "Configuring MariaDB database and user for project '${PROJECT_NAME}'..."

    local db_name="${PROJECT_NAME//-/_}"
    local db_user="${PROJECT_NAME//-/_}_user"
    local db_pass="${PROJECT_NAME}_secret"

    run_remote bash -s -- "$db_name" "$db_user" "$db_pass" <<'REMOTE'
set -euo pipefail
DB_NAME="$2"
DB_USER="$3"
DB_PASS="$4"

# Create database if not exists and user
sudo mariadb -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;"
sudo mariadb -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
sudo mariadb -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';"
sudo mariadb -e "FLUSH PRIVILEGES;"

REMOTE

    echo "MariaDB setup complete:"
    echo "  Database: ${db_name}"
    echo "  User:     ${db_user}"
    echo "  Password: ${db_pass}"
}
