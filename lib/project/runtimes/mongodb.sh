#!/usr/bin/env bash

# ==============================================================================
# MongoDB Installation & Setup for Rocky Linux / EL 10
# ==============================================================================

install_mongodb() {
    local version="$1"

    if run_remote command -v mongod >/dev/null 2>&1; then
        echo "MongoDB is already installed."
        return
    fi

    echo "Installing MongoDB ${version}..."

    run_remote bash -s -- "$version" <<'REMOTE'
set -euo pipefail
VERSION="$1"

# Create MongoDB .repo file for Enterprise/Community matching version
# Rocky 10 corresponds to RHEL 10, but MongoDB sometimes lags on RHEL 10 support.
# In case 10 is not yet fully mirrored by Mongo, EL 9 is completely compatible,
# but we will first try the standard EL/10 location or fallback.
sudo tee /etc/yum.repos.d/mongodb-org.repo > /dev/null <<EOF
[mongodb-org]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/9/mongodb-org/${VERSION}/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://pgp.mongodb.com/server-${VERSION}.asc
EOF

sudo dnf clean all
sudo dnf install -y mongodb-org

# Start and enable mongod service
sudo systemctl enable mongod
sudo systemctl restart mongod

REMOTE

    echo "Configuring MongoDB database and user for project '${PROJECT_NAME}'..."

    local db_name="${PROJECT_NAME//-/_}"
    local db_user="${PROJECT_NAME//-/_}_user"
    local db_pass="${PROJECT_NAME}_secret"

    # Use mongosh (or legacy mongo shell if not present) to create DB user
    run_remote bash -s -- "$db_name" "$db_user" "$db_pass" <<'REMOTE'
set -euo pipefail
DB_NAME="$1"
DB_USER="$2"
DB_PASS="$3"

# Ensure MongoDB binds to all interfaces to allow external GUI access
if [ -f /etc/mongod.conf ]; then
    sudo sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/' /etc/mongod.conf
    sudo systemctl restart mongod
fi

if command -v mongosh >/dev/null 2>&1; then
    mongosh "$DB_NAME" --eval "
        db.createUser({
            user: '$DB_USER',
            pwd: '$DB_PASS',
            roles: [{ role: 'dbOwner', db: '$DB_NAME' }]
        })
    " || echo "User might already exist or auth not configured."
else
    mongo "$DB_NAME" --eval "
        db.createUser({
            user: '$DB_USER',
            pwd: '$DB_PASS',
            roles: [{ role: 'dbOwner', db: '$DB_NAME' }]
        })
    " || echo "User might already exist or auth not configured."
fi

# Open firewall port if firewalld is active
if sudo systemctl is-active --quiet firewalld; then
    sudo firewall-cmd --add-port=27017/tcp --permanent >/dev/null 2>&1 || true
    sudo firewall-cmd --reload >/dev/null 2>&1 || true
fi

REMOTE

    echo "MongoDB setup complete:"
    echo "  Database: ${db_name}"
    echo "  User:     ${db_user}"
    echo "  Password: ${db_pass}"
}
