#!/usr/bin/env bash

# ==============================================================================
# PHP / Composer
# ==============================================================================

PHP_VERSION="8.4"

install_php() {

    if run_remote php -r 'exit(version_compare(PHP_VERSION, "8.4", ">=") ? 0 : 1)' \
        >/dev/null 2>&1; then

        echo "PHP already installed:"
        run_remote php --version | head -n 1
        return
    fi

    echo "Installing PHP ${PHP_VERSION}..."

    run_remote bash -s -- "$PHP_VERSION" <<'REMOTE'

set -euo pipefail

PHP_VERSION="$1"

sudo dnf install -y \
    https://rpms.remirepo.net/enterprise/remi-release-10.rpm

sudo dnf module reset -y php
sudo dnf module enable -y "php:remi-${PHP_VERSION}"

sudo dnf install -y \
    php \
    php-cli \
    php-common \
    php-mbstring \
    php-xml \
    php-curl \
    php-zip \
    php-bcmath \
    php-pdo \
    php-opcache \
    php-mysqlnd \
    php-pgsql \
    unzip

REMOTE

    echo "PHP installed:"
    run_remote php --version | head -n 1
}

install_composer() {

    if run_remote command -v composer >/dev/null 2>&1; then
        echo "Composer already installed:"
        run_remote composer --version
        return
    fi

    echo "Installing Composer..."

    run_remote bash -s <<'REMOTE'

set -euo pipefail

EXPECTED_CHECKSUM="$(curl -s https://composer.github.io/installer.sig)"

php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"

ACTUAL_CHECKSUM="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"

if [[ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]]; then
    rm -f composer-setup.php
    echo "Invalid Composer installer checksum" >&2
    exit 1
fi

sudo php composer-setup.php \
    --install-dir=/usr/local/bin \
    --filename=composer

rm -f composer-setup.php

REMOTE

    echo "Composer installed:"
    run_remote composer --version
}

