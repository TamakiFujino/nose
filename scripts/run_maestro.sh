#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source .env if it exists
ENV_FILE="$PROJECT_ROOT/.env"
if [ -f "$ENV_FILE" ]; then
  set -a
  source "$ENV_FILE"
  set +a
else
  echo "Warning: $ENV_FILE not found. Env vars must be set externally." >&2
fi

# Java 17 required by Maestro
export JAVA_HOME=/opt/homebrew/opt/openjdk@17

# Auto-detect booted simulator
DEVICE_ID=$(xcrun simctl list devices booted -j | python3 -c "
import json, sys
data = json.load(sys.stdin)
for runtime, devices in data.get('devices', {}).items():
    for d in devices:
        if d.get('state') == 'Booted':
            print(d['udid'])
            sys.exit(0)
sys.exit(1)
" 2>/dev/null) || {
  echo "Error: No booted simulator found. Boot one with: xcrun simctl boot <device>" >&2
  exit 1
}

echo "Using simulator: $DEVICE_ID"

# Build --env flags for Maestro from sourced env vars
ENV_FLAGS=()
for var in USER_A_EMAIL USER_A_NAME USER_B_EMAIL USER_B_NAME; do
  if [ -n "${!var:-}" ]; then
    ENV_FLAGS+=(--env "${var}=${!var}")
  fi
done

# Output: maestro-report/ at project root (screenshots, JUnit, etc.)
REPORT_DIR="$PROJECT_ROOT/maestro-report"
mkdir -p "$REPORT_DIR"
echo "Report output directory: $REPORT_DIR"
echo "Running: maestro test --device $DEVICE_ID ${ENV_FLAGS[*]+"${ENV_FLAGS[*]}"} --output $REPORT_DIR $*"

~/.maestro/bin/maestro test --device "$DEVICE_ID" ${ENV_FLAGS[@]+"${ENV_FLAGS[@]}"} --output "$REPORT_DIR" "$@"

echo "Done. Check: $REPORT_DIR"
