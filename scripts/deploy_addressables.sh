#!/bin/bash

# Script to deploy Unity Addressables to Firebase Hosting
# Only copies the catalog + referenced bundles (skips stale bundles from previous builds)

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
UNITY_SERVER_DATA="$PROJECT_ROOT/nose-unity/ServerData/iOS"
HOSTING_DEV="$PROJECT_ROOT/hosting/dev/addressables/iOS"
HOSTING_STAGING="$PROJECT_ROOT/hosting/staging/addressables/iOS"
FIREBASE_CONFIG_DIR="$PROJECT_ROOT"

# Function to print colored messages
print_info() {
    echo -e "${GREEN}ℹ${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check if Unity build directory exists
if [ ! -d "$UNITY_SERVER_DATA" ]; then
    print_error "Unity ServerData directory not found: $UNITY_SERVER_DATA"
    echo ""
    echo "Please build addressables in Unity first:"
    echo "  1. Open Unity project"
    echo "  2. Window → Asset Management → Addressables → Groups"
    echo "  3. Build → New Build → Default Build Script"
    exit 1
fi

# Find the catalog file
CATALOG=$(find "$UNITY_SERVER_DATA" -name "catalog_*.json" -maxdepth 1 | head -1)
if [ -z "$CATALOG" ]; then
    print_error "No catalog JSON found in $UNITY_SERVER_DATA"
    exit 1
fi

CATALOG_NAME=$(basename "$CATALOG")
CATALOG_HASH="${CATALOG_NAME%.json}.hash"

# Extract only the bundle filenames referenced by the catalog
REFERENCED_BUNDLES=$(grep -oE '[a-zA-Z0-9_]+\.bundle' "$CATALOG" | sort -u)

if [ -z "$REFERENCED_BUNDLES" ]; then
    print_error "No bundles referenced in catalog"
    exit 1
fi

# Build the list of files to copy
FILES_TO_COPY=("$CATALOG_NAME")
if [ -f "$UNITY_SERVER_DATA/$CATALOG_HASH" ]; then
    FILES_TO_COPY+=("$CATALOG_HASH")
fi
while IFS= read -r bundle; do
    if [ -f "$UNITY_SERVER_DATA/$bundle" ]; then
        FILES_TO_COPY+=("$bundle")
    else
        print_warning "Referenced bundle not found locally: $bundle"
    fi
done <<< "$REFERENCED_BUNDLES"

# Show what will be deployed
print_info "Catalog: $CATALOG_NAME"
print_info "Referenced bundles: $(echo "$REFERENCED_BUNDLES" | wc -l | tr -d ' ')"
echo ""
echo "Files to deploy:"
for f in "${FILES_TO_COPY[@]}"; do
    ls -lh "$UNITY_SERVER_DATA/$f" 2>/dev/null | awk '{print "  " $5 "\t" $NF}'
done

TOTAL_BUNDLES=$(ls "$UNITY_SERVER_DATA"/*.bundle 2>/dev/null | wc -l | tr -d ' ')
NEEDED_BUNDLES=$(echo "$REFERENCED_BUNDLES" | wc -l | tr -d ' ')
STALE=$((TOTAL_BUNDLES - NEEDED_BUNDLES))
if [ "$STALE" -gt 0 ]; then
    echo ""
    print_warning "Skipping $STALE stale bundle(s) from previous builds"
fi

# Ask which environment to deploy to
echo ""
echo "Which environment(s) do you want to deploy to?"
echo "  1) dev only"
echo "  2) staging only"
echo "  3) both dev and staging"
read -p "Enter choice [1-3]: " choice

case $choice in
    1)
        TARGETS=("dev")
        ;;
    2)
        TARGETS=("staging")
        ;;
    3)
        TARGETS=("dev" "staging")
        ;;
    *)
        print_error "Invalid choice. Exiting."
        exit 1
        ;;
esac

# Copy files to hosting directories
for target in "${TARGETS[@]}"; do
    if [ "$target" == "dev" ]; then
        HOSTING_DIR="$HOSTING_DEV"
    else
        HOSTING_DIR="$HOSTING_STAGING"
    fi

    print_info "Copying to $target environment..."

    # Clean old addressables, then copy only what's needed
    mkdir -p "$HOSTING_DIR"
    rm -f "$HOSTING_DIR"/*.bundle "$HOSTING_DIR"/catalog_*.json "$HOSTING_DIR"/catalog_*.hash

    for f in "${FILES_TO_COPY[@]}"; do
        cp -v "$UNITY_SERVER_DATA/$f" "$HOSTING_DIR/"
    done

    print_info "Copied ${#FILES_TO_COPY[@]} files to: $HOSTING_DIR"
done

echo ""
print_info "Files copied successfully!"
echo ""

# Ask if user wants to deploy to Firebase
read -p "Do you want to deploy to Firebase now? [y/N]: " deploy_choice

if [[ "$deploy_choice" =~ ^[Yy]$ ]]; then
    print_info "Deploying to Firebase..."

    cd "$FIREBASE_CONFIG_DIR"

    for target in "${TARGETS[@]}"; do
        # Switch to the correct Firebase project for this target
        if [ "$target" == "dev" ]; then
            print_info "Switching to Firebase project: nose-a2309"
            firebase use nose-a2309
        else
            print_info "Switching to Firebase project: nose-staging"
            firebase use nose-staging
        fi

        print_info "Deploying to Firebase target: $target"
        firebase deploy --only hosting:"$target"
    done

    print_info "Deployment complete!"
    echo ""
    echo "Addressables are now available at:"
    for target in "${TARGETS[@]}"; do
        if [ "$target" == "dev" ]; then
            echo "  Dev: https://nose-a2309.web.app/addressables/iOS/"
        else
            echo "  Staging: https://nose-staging.web.app/addressables/iOS/"
        fi
    done
else
    echo ""
    print_info "Files are ready in hosting directories."
    echo "To deploy manually, run:"
    echo "  cd $FIREBASE_CONFIG_DIR"
    for target in "${TARGETS[@]}"; do
        if [ "$target" == "dev" ]; then
            echo "  firebase use nose-a2309"
            echo "  firebase deploy --only hosting:$target"
        else
            echo "  firebase use nose-staging"
            echo "  firebase deploy --only hosting:$target"
        fi
    done
fi

echo ""
print_info "Done!"
