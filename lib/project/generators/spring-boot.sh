#!/usr/bin/env bash

# ==============================================================================
# Spring Boot
# ==============================================================================

SPRING_BOOT_VERSION="4.1.1"

create_spring_boot_project() {

    echo
    echo "Creating Spring Boot project..."
    echo

    run_remote bash -s -- \
        "$PROJECT_NAME" \
        "$DEV_USER" \
        "$SPRING_BOOT_VERSION" <<'REMOTE'

set -euo pipefail

PROJECT_NAME="$1"
DEV_USER="$2"
SPRING_BOOT_VERSION="$3"

PROJECT_DIR="/home/${DEV_USER}/${PROJECT_NAME}"

curl -fsSL \
    -G \
    --data-urlencode "type=maven-project" \
    --data-urlencode "language=java" \
    --data-urlencode "bootVersion=${SPRING_BOOT_VERSION}" \
    --data-urlencode "baseDir=${PROJECT_NAME}" \
    --data-urlencode "groupId=com.example" \
    --data-urlencode "artifactId=${PROJECT_NAME}" \
    --data-urlencode "name=${PROJECT_NAME}" \
    --data-urlencode "description=Spring Boot application" \
    --data-urlencode "packageName=com.example.app" \
    --data-urlencode "packaging=jar" \
    --data-urlencode "javaVersion=25" \
    --data-urlencode "dependencies=web" \
    "https://start.spring.io/starter.zip" \
    -o "/tmp/${PROJECT_NAME}.zip"

mkdir -p "/home/${DEV_USER}"

unzip -q \
    "/tmp/${PROJECT_NAME}.zip" \
    -d "/home/${DEV_USER}"

rm -f "/tmp/${PROJECT_NAME}.zip"

cd "$PROJECT_DIR"

chmod +x mvnw

REMOTE
}