#!/bin/bash

# Script to deploy Unity Addressables to Firebase Hosting
# This copies built addressables from Unity to the hosting directory and optionally deploys

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

# Check if there are any files to copy
if [ -z "$(ls -A "$UNITY_SERVER_DATA" 2>/dev/null)" ]; then
    print_error "No files found in $UNITY_SERVER_DATA"
    echo "Please build addressables in Unity first."
    exit 1
fi

print_info "Found addressables in: $UNITY_SERVER_DATA"
echo "Files to copy:"
ls -lh "$UNITY_SERVER_DATA" | tail -n +2

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
    
    # Create directory if it doesn't exist
    mkdir -p "$HOSTING_DIR"
    
    # Copy all files
    cp -v "$UNITY_SERVER_DATA"/* "$HOSTING_DIR/"
    
    print_info "Copied files to: $HOSTING_DIR"
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
            echo "  Staging: https://nose-a2309.web.app/addressables/iOS/"
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

