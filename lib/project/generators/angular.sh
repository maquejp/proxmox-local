#!/usr/bin/env bash

# ==============================================================================
# Angular
# ==============================================================================

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

cd "/home/${DEV_USER}/${PROJECT_NAME}"

python3 -c "
import json
with open('package.json', 'r+') as f:
    data = json.load(f)
    data.setdefault('scripts', {})['start'] = 'ng serve --host 0.0.0.0'
    f.seek(0)
    json.dump(data, f, indent=2)
    f.truncate()
    f.write('\n')
"

REMOTE
}
