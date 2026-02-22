# Staging Collection Icons - Status Update

## ✅ Completed

**Storage Rules Deployed to Staging**
- Storage rules have been successfully deployed to the `nose-staging` Firebase project
- The rules allow authenticated users to read from `collection_icons/` folder
- Rules are now live and active

## ⚠️ Next Step Required

**Check if Icons Exist in Staging Storage**

The storage rules are in place, but we need to verify if the `collection_icons/` folder exists in staging Firebase Storage and contains icon files.

### Option 1: Check via Firebase Console (Easiest)

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select **nose-staging** project
3. Navigate to **Storage** section
4. Look for `collection_icons/` folder
5. Check if it contains icon files (.jpg, .png, etc.)

**If icons are missing**, you'll need to copy them from dev/production (see Option 2).

### Option 2: Copy Icons Using Python Script

If icons are missing, you can copy them using the existing Python script:

```bash
# Install dependencies (if not already installed)
# From repo root:
cd scripts
source venv/bin/activate
pip install firebase-admin google-cloud-storage

# Copy icons from dev to staging
python3 copy_collection_icons_to_production.py --source dev --target staging

# Or copy from production to staging
python3 copy_collection_icons_to_production.py --source production --target staging
```

**Note:** You may need to set up authentication:
- Set `GOOGLE_APPLICATION_CREDENTIALS` environment variable to a service account JSON file
- Or use `--service-account` flag with the script

### Option 3: Manual Copy via Firebase Console

1. Go to dev project (`nose-a2309`) in Firebase Console
2. Navigate to **Storage** → `collection_icons/`
3. Download all icon files
4. Switch to staging project (`nose-staging`)
5. Navigate to **Storage**
6. Create `collection_icons/` folder if it doesn't exist
7. Upload all icon files

## 🔍 Verify in App

After copying icons (if needed):

1. Build staging app
2. Make sure you're logged in (authentication required)
3. Open ImagePickerViewController (when creating/editing a collection)
4. Verify icons are displayed

## Summary

- ✅ Storage rules: **DEPLOYED**
- ⏳ Icons: **Need to verify/copy** (check via Firebase Console first)

Once icons are in place, they should work immediately since the storage rules are already deployed.

