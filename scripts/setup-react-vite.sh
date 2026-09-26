#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"

VMID="${1:-}"
PROJECT_NAME="${2:-}"
VM_IP="${3:-}"

usage() {
    echo "Usage: $0 <vmid> <project-name> <vm-ip>"
    echo "Example: $0 153 mon-projet 192.168.1.153"
    exit 1
}

[[ -n "$VMID" && -n "$PROJECT_NAME" && -n "$VM_IP" ]] || usage

validate_vmid "$VMID"
validate_ip "$VM_IP"
ensure_vm_exists "$VMID"
ensure_vm_running "$VMID"
ensure_admin_key_exists

PROJECT_DIR="${PROJECTS_DIR}/${PROJECT_NAME}"

echo "Checking Node.js and npm on ${VM_USER}@${VM_IP}..."
if ! ssh_vm "$VM_IP" "command -v node >/dev/null && command -v npm >/dev/null"; then
    echo "Error: Node.js and npm must be installed on the target VM." >&2
    exit 1
fi

echo "Checking project directory (${PROJECT_DIR})..."
if ! ssh_vm "$VM_IP" "test -d '$PROJECT_DIR'"; then
    echo "Error: Project directory '$PROJECT_DIR' not found." >&2
    echo "Run setup-dev-project.sh first." >&2
    exit 1
fi

HAS_PACKAGE_JSON="$(ssh_vm "$VM_IP" "test -f '$PROJECT_DIR/package.json' && echo yes || echo no")"

if [[ "$HAS_PACKAGE_JSON" == "no" ]]; then
    echo "No package.json found in $PROJECT_DIR."
    echo "Scaffolding a new React + Vite (TypeScript) project..."
    ssh_vm "$VM_IP" "cd '$PROJECT_DIR' && npx --yes create-vite@latest . --template react-ts"
fi

echo "Verifying React and Vite dependencies..."
ssh_vm "$VM_IP" "cd '$PROJECT_DIR' && node -e '
    const packageJson = require(\"./package.json\");
    const packages = { ...(packageJson.dependencies || {}), ...(packageJson.devDependencies || {}) };
    const required = [\"react\", \"vite\"];
    const missing = required.filter((name) => !packages[name]);
    if (missing.length > 0) {
        console.error(\`Error: missing required packages in package.json: \${missing.join(\", \")}\`);
        process.exit(1);
    }
'"

VITE_CONFIG="$(
    ssh_vm "$VM_IP" "find '$PROJECT_DIR' -maxdepth 1 -type f \
        \\( -name 'vite.config.ts' -o -name 'vite.config.js' -o -name 'vite.config.mts' -o -name 'vite.config.mjs' \\) \
        -print -quit"
)"

if [[ -z "$VITE_CONFIG" ]]; then
    echo "Creating default vite.config.ts with host listening on 0.0.0.0..."
    VITE_CONFIG="$PROJECT_DIR/vite.config.ts"
    ssh_vm "$VM_IP" "cat > '$VITE_CONFIG' << 'EOF'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    host: '0.0.0.0',
    port: 5173,
  },
})
EOF"
else
    echo "Checking Vite host configuration in $VITE_CONFIG..."
    if ! ssh_vm "$VM_IP" "grep -Eq \"host:[[:space:]]*(['\\\"]0\\.0\\.0\\.0['\\\"]|true)\" '$VITE_CONFIG'"; then
        echo "Configuring server.host = '0.0.0.0' in $VITE_CONFIG..."
        ssh_vm "$VM_IP" "node -e '
            const fs = require(\"fs\");
            let content = fs.readFileSync(\"$VITE_CONFIG\", \"utf8\");
            if (content.includes(\"server:\")) {
                content = content.replace(/server:\\s*{/, \"server: {\\n    host: \\\"0.0.0.0\\\",\");
            } else {
                content = content.replace(/defineConfig\\s*\\({/, \"defineConfig({\\n  server: { host: \\\"0.0.0.0\\\" },\");
            }
            fs.writeFileSync(\"$VITE_CONFIG\", content);
        '"
    fi
fi

HAS_LOCKFILE="$(ssh_vm "$VM_IP" "test -f '$PROJECT_DIR/package-lock.json' && echo yes || echo no")"

if [[ "$HAS_LOCKFILE" == "yes" ]]; then
    echo "Installing locked dependencies (npm ci)..."
    ssh_vm "$VM_IP" "cd '$PROJECT_DIR' && npm ci"
else
    echo "Installing dependencies (npm install)..."
    ssh_vm "$VM_IP" "cd '$PROJECT_DIR' && npm install"
fi

echo "Building project..."
ssh_vm "$VM_IP" "cd '$PROJECT_DIR' && npm run build"

open_vm_port "$VM_IP" 5173 "tcp"

echo
echo "React/Vite setup complete:"
echo "  VM:        $VMID"
echo "  IP:        $VM_IP"
echo "  Project:   $PROJECT_NAME"
echo "  Directory: $PROJECT_DIR"
echo "  Vite URL:  http://${VM_IP}:5173"
