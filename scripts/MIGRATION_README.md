# Collection Icons Migration Script

This script migrates collection icons from Firebase Storage to Firestore for faster querying.

## What it does

1. Lists all files from Storage folders (`collection_icons/{category}/`)
2. Gets the download URL for each file
3. Creates Firestore documents with `name`, `url`, and `category` fields

## Prerequisites

1. **Node.js** (v14 or higher)
2. **Firebase Admin SDK** credentials

### Setting up Firebase Admin SDK

You have two options:

#### Option 1: Application Default Credentials (Recommended for local development)

```bash
# Install Firebase CLI if you haven't already
npm install -g firebase-tools

# Login to Firebase
firebase login

# Set application default credentials
firebase use <project-id>  # e.g., nose-a2309 for dev
gcloud auth application-default login  # If using GCP
```

#### Option 2: Service Account Key (Recommended for CI/CD)

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project (e.g., `nose-a2309` for dev, `nose-staging` for staging, `nose-production` for production)
3. Go to Project Settings → Service Accounts
4. Click "Generate New Private Key"
5. Save the JSON file in the project root (NOT in scripts folder) with one of these names:
   - **Recommended**: `serviceAccountKey-{environment}.json` (e.g., `serviceAccountKey-dev.json`, `serviceAccountKey-staging.json`, `serviceAccountKey-production.json`)
   - **Alternative**: `serviceAccountKey.json` (will be used for all environments if environment-specific key doesn't exist)
6. **Important**: All `serviceAccountKey*.json` files are already in `.gitignore` to avoid committing secrets

## Installation

```bash
cd scripts
npm install
```

## Usage

### Basic usage (uses dev environment by default)

```bash
npm run migrate-icons
# or
node migrate_collection_icons.js
```

### Specify environment

```bash
# Development
npm run migrate-icons:dev
node migrate_collection_icons.js dev

# Staging
npm run migrate-icons:staging
node migrate_collection_icons.js staging

# Production
npm run migrate-icons:production
node migrate_collection_icons.js production
```

## What gets migrated

The script processes icons from these categories:
- `hobby`
- `place`
- `food`
- `sports`
- `symbol`

## Firestore Structure

Each icon becomes a document in the `collection_icons` collection:

```json
{
  "name": "Icon Display Name",
  "url": "https://firebase...",
  "category": "hobby"
}
```

## Safety Features

- **Idempotent**: Running the script multiple times is safe
- **Duplicate detection**: Skips icons that already exist in Firestore
- **Batch processing**: Processes files in batches to avoid overwhelming the system
- **Error handling**: Continues processing even if individual files fail

## Troubleshooting

### "Error: Config file not found"
- Make sure you're running the script from the correct directory
- Check that the `GoogleService-Info-*.plist` files exist in `FirebaseConfig/`

### "Error initializing Firebase Admin"
- Make sure you have Firebase Admin SDK credentials set up (see Prerequisites)
- For service account: ensure `serviceAccountKey.json` is in the project root
- For Application Default Credentials: make sure you're logged in with `firebase login`

### "Permission denied" errors
- Ensure your Firebase Admin credentials have permissions to:
  - Read from Firebase Storage (`collection_icons/`)
  - Write to Firestore (`collection_icons` collection)

### Migration is slow
- This is normal for large numbers of icons (e.g., 250 flags in "place")
- The script processes files in batches of 10
- Progress is shown every 10 icons

## After Migration

1. Deploy the Firestore index:
   ```bash
   firebase deploy --only firestore:indexes
   ```
   
   Or wait for Firebase to auto-create it when you first query (Firebase will show a link in the console).

2. Test the migration:
   - The app should now load icons much faster using Firestore
   - If Firestore doesn't have data for a category, it will fall back to Storage method

3. Verify in Firebase Console:
   - Go to Firestore Database
   - Check the `collection_icons` collection
   - Filter by `category` to see icons grouped by category

