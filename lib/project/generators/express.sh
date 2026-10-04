#!/usr/bin/env bash

# ==============================================================================
# Express
# ==============================================================================

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

cat > tsconfig.json <<'EOF2'
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
EOF2

cat > src/index.ts <<'EOF2'
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
EOF2

REMOTE
}
