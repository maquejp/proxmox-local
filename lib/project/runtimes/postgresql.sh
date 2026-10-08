#!/usr/bin/env bash

# ==============================================================================
# PostgreSQL Installation & Setup for Rocky Linux / EL 10
# ==============================================================================

install_postgresql() {
    local version="$1"
    local psql_bin="/usr/pgsql-${version}/bin/psql"

    if ! run_remote test -x "$psql_bin" >/dev/null 2>&1; then
        echo "Installing PostgreSQL ${version}..."

        # Setup the PostgreSQL official repo and install
        run_remote bash -s -- "$version" <<'REMOTE'
set -euo pipefail
VERSION="$1"

# Disable default postgresql dnf module if enabled
sudo dnf -qy module disable postgresql || true

# Add PGDG Repository for EL 10 (CentOS / Rocky Linux 10)
# Note: PGDG repo URL has a standard format.
sudo dnf install -y "https://download.postgresql.org/pub/repos/yum/reporpms/EL-10-x86_64/pgdg-redhat-repo-latest.noarch.rpm"

# Install client & server packages
sudo dnf install -y \
    "postgresql${VERSION}-server" \
    "postgresql${VERSION}-contrib"

# Initialize database directory if not done already
if [ ! -f "/var/lib/pgsql/${VERSION}/data/PG_VERSION" ]; then
    echo "Initializing PostgreSQL ${VERSION} database..."
    sudo "/usr/pgsql-${VERSION}/bin/postgresql-${VERSION}-setup" initdb
fi

# Configure host-based authentication (pg_hba.conf) for local development
# This enables passwordless local login for development and simple standard passwords
PG_HBA="/var/lib/pgsql/${VERSION}/data/pg_hba.conf"
PG_CONF="/var/lib/pgsql/${VERSION}/data/postgresql.conf"

sudo sed -i '/^local\s\+all\s\+all\s\+peer/i local   all             postgres                                peer' "$PG_HBA"
sudo sed -i 's/^local\s\+all\s\+all\s\+peer/local   all             all                                     md5/' "$PG_HBA"
sudo sed -i 's/^host\s\+all\s\+all\s\+127.0.0.1\/32\s\+ident/host    all             all             127.0.0.1\/32            md5/' "$PG_HBA"
sudo sed -i 's/^host\s\+all\s\+all\s\+::1\/128\s\+ident/host    all             all             ::1\/128                 md5/' "$PG_HBA"

# Allow connections from any IP
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" "$PG_CONF"
echo "host    all             all             0.0.0.0/0               md5" | sudo tee -a "$PG_HBA" >/dev/null

# Open firewall port if firewalld is active
if sudo systemctl is-active --quiet firewalld; then
    sudo firewall-cmd --add-port=5432/tcp --permanent >/dev/null 2>&1 || true
    sudo firewall-cmd --reload >/dev/null 2>&1 || true
fi

# Start and enable PostgreSQL service
sudo systemctl daemon-reload
sudo systemctl enable "postgresql-${VERSION}"
sudo systemctl restart "postgresql-${VERSION}"

REMOTE
    else
        echo "PostgreSQL ${version} is already installed."
        # Automatically repair pg_hba.conf if it was left in a broken state from a prior run
        run_remote bash -s -- "$version" <<'REMOTE'
set -euo pipefail
VERSION="$1"
PG_HBA="/var/lib/pgsql/${VERSION}/data/pg_hba.conf"
if ! sudo grep -q "local.*postgres.*peer" "$PG_HBA"; then
    sudo sed -i '/^local\s\+all\s\+all\s\+peer/i local   all             postgres                                peer' "$PG_HBA"
    sudo sed -i 's/^local\s\+all\s\+all\s\+peer/local   all             all                                     md5/' "$PG_HBA"
    sudo systemctl restart "postgresql-${VERSION}"
fi
REMOTE
    fi

    echo "Configuring PostgreSQL database and user for project '${PROJECT_NAME}'..."

    # Generate a safe db user name and password based on project name
    local db_name="${PROJECT_NAME//-/_}"
    local db_user="${PROJECT_NAME//-/_}_user"
    local db_pass="${PROJECT_NAME}_secret"

    run_remote bash -s -- "$version" "$db_name" "$db_user" "$db_pass" <<'REMOTE'
set -euo pipefail
VERSION="$1"
DB_NAME="$2"
DB_USER="$3"
DB_PASS="$4"

# We must run creation commands as the postgres system user.
# Using peer authentication locally for postgres system user is standard.
sudo -u postgres "/usr/pgsql-${VERSION}/bin/psql" -tAc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'" | grep -q 1 || \
sudo -u postgres "/usr/pgsql-${VERSION}/bin/psql" -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS' CREATEDB;"

sudo -u postgres "/usr/pgsql-${VERSION}/bin/psql" -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME" || \
sudo -u postgres "/usr/pgsql-${VERSION}/bin/psql" -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;"

REMOTE

    echo "PostgreSQL setup complete:"
    echo "  Database: ${db_name}"
    echo "  User:     ${db_user}"
    echo "  Password: ${db_pass}"
}
