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

MAESTRO_ARGS=(--device "$DEVICE_ID" --config "$PROJECT_ROOT/.maestro/config.yaml" ${ENV_FLAGS[@]+"${ENV_FLAGS[@]}"} --output "$REPORT_DIR")

# When given a directory (and optional start-from flow), run each test flow one-by-one so terminal shows check marks per flow
if [ $# -ge 1 ] && [ -d "$1" ]; then
  MAESTRO_DIR="$(cd "$1" && pwd)"
  FLOWS=()
  while IFS= read -r -d '' f; do FLOWS+=("$f"); done < <(find "$MAESTRO_DIR" -maxdepth 1 -name '*.yaml' ! -path "$MAESTRO_DIR/config.yaml" -print0 | sort -z)

  # Optional: start from a specific flow (second arg). E.g. run_maestro.sh .maestro/ 03_collection_management_01_create_from_modal.yaml
  if [ $# -ge 2 ]; then
    START_FROM="$(basename "$2" .yaml)"
    FOUND=
    for i in "${!FLOWS[@]}"; do
      if [ "$(basename "${FLOWS[i]}" .yaml)" = "$START_FROM" ]; then
        FLOWS=( "${FLOWS[@]:i}" )
        FOUND=1
        break
      fi
    done
    if [ -z "${FOUND:-}" ]; then
      echo "Error: No flow matching '$2' in $MAESTRO_DIR" >&2
      exit 1
    fi
    echo "Starting from: $(basename "${FLOWS[0]}")"
  fi

  TOTAL=${#FLOWS[@]}
  CURRENT=0
  for flow in "${FLOWS[@]}"; do
    CURRENT=$((CURRENT + 1))
    echo ""
    echo "========== [$CURRENT/$TOTAL] $(basename "$flow") =========="
    if ! ~/.maestro/bin/maestro test "${MAESTRO_ARGS[@]}" "$flow"; then
      echo "Failed: $flow" >&2
      exit 1
    fi
  done
  echo ""
  echo "Done. $TOTAL flow(s) passed. Check: $REPORT_DIR"
else
  echo "Running: maestro test ${MAESTRO_ARGS[*]} $*"
  ~/.maestro/bin/maestro test "${MAESTRO_ARGS[@]}" "$@"
  echo "Done. Check: $REPORT_DIR"
fi
