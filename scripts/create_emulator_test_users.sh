#!/bin/bash
# Create test users in the Firebase Auth Emulator.
# Requires the Auth Emulator to be running on localhost:9099.
#
# Usage:
#   firebase emulators:start --only auth,firestore &
#   bash scripts/create_emulator_test_users.sh

set -euo pipefail

AUTH_URL="http://localhost:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake"
PASSWORD="testpassword123"

USER_A_EMAIL="${TEST_USER_A_EMAIL:?Set TEST_USER_A_EMAIL env var}"
USER_B_EMAIL="${TEST_USER_B_EMAIL:?Set TEST_USER_B_EMAIL env var}"

echo "Creating User A ($USER_A_EMAIL)..."
curl -sf -X POST "$AUTH_URL" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"$USER_A_EMAIL\",\"password\":\"$PASSWORD\",\"returnSecureToken\":true}"
echo

echo "Creating User B ($USER_B_EMAIL)..."
curl -sf -X POST "$AUTH_URL" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"$USER_B_EMAIL\",\"password\":\"$PASSWORD\",\"returnSecureToken\":true}"
echo

echo "Done. Both test users created in the Auth Emulator."
