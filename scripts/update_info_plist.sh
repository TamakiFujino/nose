#!/bin/bash

# Script to update Info.plist with Google Client ID from Firebase config
CONFIGURATION=$1
FIREBASE_CONFIG_PATH="FirebaseConfig/GoogleService-Info-${CONFIGURATION}.plist"
INFO_PLIST_PATH="InfoPlist/Info.plist"

if [ ! -f "$FIREBASE_CONFIG_PATH" ]; then
    echo "Error: Firebase config file not found: $FIREBASE_CONFIG_PATH"
    exit 1
fi

# Extract REVERSED_CLIENT_ID from Firebase config
REVERSED_CLIENT_ID=$(/usr/libexec/PlistBuddy -c "Print :REVERSED_CLIENT_ID" "$FIREBASE_CONFIG_PATH")
CLIENT_ID=$(/usr/libexec/PlistBuddy -c "Print :CLIENT_ID" "$FIREBASE_CONFIG_PATH")

echo "Extracted REVERSED_CLIENT_ID: $REVERSED_CLIENT_ID"
echo "Extracted CLIENT_ID: $CLIENT_ID"

# Update Info.plist with the extracted values
/usr/libexec/PlistBuddy -c "Set :CFBundleURLTypes:0:CFBundleURLSchemes:0 $REVERSED_CLIENT_ID" "$INFO_PLIST_PATH"
/usr/libexec/PlistBuddy -c "Set :GoogleClientID $CLIENT_ID" "$INFO_PLIST_PATH"

echo "Updated Info.plist with Google Client IDs for $CONFIGURATION configuration" 