#!/usr/bin/env bash
# patch_project_exclude_unity.sh
#
# Removes UnityFramework link/embed and unity Data resource references
# from the Xcode project so the app can build for the iOS Simulator
# without the (device-only) UnityFramework.framework binary.
#
# This is meant to run in CI on a clean checkout — it does NOT commit
# anything, so the working tree stays dirty only for the duration of
# the CI job.

set -euo pipefail

PBXPROJ="nose.xcodeproj/project.pbxproj"

if [ ! -f "$PBXPROJ" ]; then
  echo "::error::$PBXPROJ not found"
  exit 1
fi

echo "Patching $PBXPROJ to exclude Unity references..."

sed -i '' \
  -e '/UnityFramework\.framework in Frameworks/d' \
  -e '/UnityFramework\.framework in Embed Frameworks/d' \
  -e '/Data in Resources/d' \
  "$PBXPROJ"

echo "Done. Removed UnityFramework link, embed, and Data resource entries."
