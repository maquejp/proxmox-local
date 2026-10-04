#!/usr/bin/env bash

# ==============================================================================
# New project setup
# ==============================================================================

NODE_MAJOR_VERSION="24"

# ==============================================================================
# Node.js
# ==============================================================================

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

# ==============================================================================
# Project generators
# ==============================================================================

create_vite_react_project() {

    echo
    echo "Creating Vite + React project..."
    echo

    run_remote bash -s -- "$PROJECT_NAME" "$DEV_USER" <<'REMOTE'

set -euo pipefail

PROJECT_NAME="$1"
DEV_USER="$2"

cd "/home/${DEV_USER}"

npm create vite@latest \
    "$PROJECT_NAME" \
    -- \
    --template react-ts

REMOTE
}

create_angular_project() {

    echo
    echo "Creating Angular project..."
    echo

    run_remote bash -s -- "$PROJECT_NAME" "$DEV_USER" <<'REMOTE'

set -euo pipefail

PROJECT_NAME="$1"
DEV_USER="$2"

cd "/home/${DEV_USER}"

npx @angular/cli@latest new \
    "$PROJECT_NAME" \
    --routing \
    --style css \
    --skip-git \
    --skip-install \
    --defaults

REMOTE
}

create_express_project() {

    echo
    echo "Creating Express project..."
    echo

    run_remote bash -s -- "$PROJECT_NAME" "$DEV_USER" <<'REMOTE'

set -euo pipefail

PROJECT_NAME="$1"
DEV_USER="$2"
PROJECT_DIR="/home/${DEV_USER}/${PROJECT_NAME}"

mkdir -p "${PROJECT_DIR}/src"

cd "$PROJECT_DIR"

npm init -y

npm install express
npm install --save-dev \
    @types/express \
    @types/node \
    tsx \
    typescript

cat > package.json.tmp <<'EOF'
EOF

node <<'NODE'
const fs = require("fs");

const packageJson = JSON.parse(fs.readFileSync("package.json", "utf8"));

packageJson.scripts = {
    dev: "tsx watch src/index.ts",
    build: "tsc",
    start: "node dist/index.js"
};

packageJson.type = "module";

fs.writeFileSync(
    "package.json",
    JSON.stringify(packageJson, null, 2) + "\n"
);
NODE

rm -f package.json.tmp

cat > tsconfig.json <<'EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "outDir": "dist",
    "rootDir": "src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true
  },
  "include": ["src"]
}
EOF

cat > src/index.ts <<'EOF'
import express from "express";

const app = express();
const port = Number(process.env.PORT) || 3000;

app.get("/", (_req, res) => {
  res.json({
    message: "Express API is running",
  });
});

app.listen(port, "0.0.0.0", () => {
  console.log(`API listening on port ${port}`);
});
EOF

REMOTE
}

# ==============================================================================
# Git
# ==============================================================================

initialize_git() {

    echo
    echo "Initializing Git..."

    run_remote bash -s -- \
        "$PROJECT_NAME" \
        "$DEV_USER" \
        "$GIT_USER_NAME" \
        "$GIT_USER_EMAIL" <<'REMOTE'

set -euo pipefail

PROJECT_NAME="$1"
DEV_USER="$2"
GIT_USER_NAME="$3"
GIT_USER_EMAIL="$4"

PROJECT_DIR="/home/${DEV_USER}/${PROJECT_NAME}"

cd "$PROJECT_DIR"

git init -b main

git config user.name "$GIT_USER_NAME"
git config user.email "$GIT_USER_EMAIL"

git add .
git commit -m "chore: initialize project"

git branch --show-current
git status --short

REMOTE
}

# ==============================================================================
# Project setup
# ==============================================================================

setup_vite_react_project() {

    install_node
    create_vite_react_project
    initialize_git
}

setup_angular_project() {

    install_node
    create_angular_project
    initialize_git
}

setup_express_project() {

    install_node
    create_express_project
    initialize_git
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
                *)
                    error "Backend '$BACKEND' is not implemented yet"
                    ;;
            esac
            ;;
        *)
            error "New project type '$PROJECT_TYPE' is not implemented yet"
            ;;
    esac

    echo
    echo "Project created successfully."
}