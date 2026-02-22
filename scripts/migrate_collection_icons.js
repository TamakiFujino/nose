#!/usr/bin/env node

/**
 * Migration Script: Populate Firestore with collection icons from Storage
 * 
 * This script:
 * 1. Lists all files from Storage folders (collection_icons/{category}/)
 * 2. Gets the download URL for each file
 * 3. Creates Firestore documents with name, url, and category
 * 
 * Usage:
 *   node scripts/migrate_collection_icons.js [environment]
 * 
 * Environment options: dev (default), staging, production
 */

require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

// Get environment from command line argument (default: dev)
const environment = process.argv[2] || 'dev';

// Project ID mapping
const projectIds = {
  dev: 'nose-a2309',
  staging: 'nose-staging',
  production: 'nose-production'
};

// Bucket name mapping (Firebase uses .firebasestorage.app format for new projects)
const bucketNames = {
  dev: 'nose-a2309.firebasestorage.app',
  staging: 'nose-staging.firebasestorage.app',  // Update if different
  production: 'nose-production.firebasestorage.app'  // Update if different
};

const projectId = projectIds[environment] || projectIds.dev;
const defaultBucketName = bucketNames[environment] || `${projectId}.firebasestorage.app`;

console.log(`🚀 Starting migration for environment: ${environment}`);
console.log(`   Project ID: ${projectId}`);
console.log(`   Bucket: ${defaultBucketName}`);

// Initialize Firebase Admin SDK
let storageBucket;
try {
  // Try to initialize with service account key first (recommended)
  // Check FIREBASE_SERVICE_ACCOUNT_PATH from .env, then environment-specific key, then generic key
  const repoRoot = path.join(__dirname, '..');
  const envPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH
    ? path.isAbsolute(process.env.FIREBASE_SERVICE_ACCOUNT_PATH)
      ? process.env.FIREBASE_SERVICE_ACCOUNT_PATH
      : path.join(repoRoot, process.env.FIREBASE_SERVICE_ACCOUNT_PATH)
    : null;
  const serviceAccountPathEnv = path.join(repoRoot, `serviceAccountKey-${environment}.json`);
  const serviceAccountPath = path.join(repoRoot, 'serviceAccountKey.json');

  let serviceAccountPathToUse = null;
  if (envPath && fs.existsSync(envPath)) {
    serviceAccountPathToUse = envPath;
  } else if (fs.existsSync(serviceAccountPathEnv)) {
    serviceAccountPathToUse = serviceAccountPathEnv;
  } else if (fs.existsSync(serviceAccountPath)) {
    serviceAccountPathToUse = serviceAccountPath;
  }
  
  if (serviceAccountPathToUse) {
    const serviceAccount = require(serviceAccountPathToUse);
    // Try to get bucket name from service account, or use default pattern
    // New Firebase projects use .firebasestorage.app, older ones use .appspot.com
    storageBucket = serviceAccount.storageBucket || bucketNames[environment] || `${serviceAccount.project_id}.firebasestorage.app`;
    
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      storageBucket: storageBucket
    });
    
    console.log('✅ Initialized Firebase Admin with service account key');
    console.log(`   Key file: ${path.basename(serviceAccountPathToUse)}`);
    console.log(`   Project: ${serviceAccount.project_id}`);
    console.log(`   Bucket: ${storageBucket}`);
  } else {
    // Fall back to Application Default Credentials with explicit bucket
    storageBucket = defaultBucketName;
    admin.initializeApp({
      storageBucket: storageBucket
    });
    console.log('✅ Initialized Firebase Admin with Application Default Credentials');
    console.log(`   Using bucket: ${storageBucket}`);
    console.log('💡 Tip: For better control, create a serviceAccountKey.json file in the project root');
    console.log('   See MIGRATION_README.md for instructions');
  }
} catch (error) {
  console.error('❌ Error initializing Firebase Admin:', error.message);
  console.error('');
  console.error('Setup instructions:');
  console.error('1. Option 1 (Recommended): Create service account key in project root');
  console.error('   - Go to Firebase Console → Project Settings → Service Accounts');
  console.error('   - Select project:', projectId);
  console.error('   - Click "Generate New Private Key"');
  console.error('   - Save as serviceAccountKey-' + environment + '.json or serviceAccountKey.json');
  console.error('     (Environment-specific names are recommended: serviceAccountKey-dev.json, etc.)');
  console.error('');
  console.error('2. Option 2: Use gcloud Application Default Credentials');
  console.error('   - Run: gcloud auth application-default login');
  console.error('   - Run: gcloud config set project', projectId);
  console.error('');
  console.error('See MIGRATION_README.md for detailed instructions');
  process.exit(1);
}

const db = admin.firestore();
const storage = admin.storage();
let bucket = storage.bucket(storageBucket);

// Categories to migrate
const categories = ['hobby', 'place', 'food', 'sports', 'symbol'];

/**
 * Extract name from filename (remove extension and convert underscores to spaces)
 */
function getNameFromFileName(fileName) {
  // Remove extension
  const nameWithoutExt = fileName.replace(/\.(jpg|jpeg|png|gif|svg)$/i, '');
  // Replace underscores with spaces and capitalize
  return nameWithoutExt
    .split('_')
    .map(word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
    .join(' ');
}

/**
 * Get download URL for a file reference
 */
async function getDownloadURL(fileRef) {
  try {
    const [url] = await fileRef.getSignedUrl({
      action: 'read',
      expires: '03-09-2491' // Far future date (max allowed)
    });
    return url;
  } catch (error) {
    // If signed URL fails, try public URL
    return `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(fileRef.name)}?alt=media`;
  }
}

/**
 * Migrate icons for a specific category
 */
async function migrateCategory(category) {
  console.log(`\n📦 Migrating category: ${category}`);
  
  try {
    const [files] = await bucket.getFiles({ prefix: `collection_icons/${category}/` });
    
    if (files.length === 0) {
      console.log(`   ⚠️  No files found in collection_icons/${category}/`);
      return { success: 0, skipped: 0, errors: 0 };
    }
    
    console.log(`   📁 Found ${files.length} files`);
    
    // Check existing documents in Firestore
    const existingDocs = await db.collection('collection_icons')
      .where('category', '==', category)
      .get();
    
    const existingUrls = new Set(existingDocs.docs.map(doc => doc.data().url));
    console.log(`   📊 Found ${existingUrls.size} existing documents in Firestore`);
    
    let successCount = 0;
    let skippedCount = 0;
    let errorCount = 0;
    
    // Process files in batches to avoid overwhelming the system
    const batchSize = 10;
    for (let i = 0; i < files.length; i += batchSize) {
      const batch = files.slice(i, i + batchSize);
      const promises = batch.map(async (file) => {
        try {
          // Skip if it's a folder
          if (file.name.endsWith('/')) {
            return;
          }
          
          // Get download URL
          const url = await getDownloadURL(file);
          
          // Skip if already exists
          if (existingUrls.has(url)) {
            skippedCount++;
            return;
          }
          
          // Extract name from filename
          const fileName = file.name.split('/').pop();
          const name = getNameFromFileName(fileName);
          
          // Create Firestore document
          await db.collection('collection_icons').add({
            name: name,
            url: url,
            category: category
          });
          
          successCount++;
          if (successCount % 10 === 0) {
            process.stdout.write(`   ✅ Processed ${successCount} icons...\r`);
          }
        } catch (error) {
          console.error(`\n   ❌ Error processing ${file.name}:`, error.message);
          errorCount++;
        }
      });
      
      await Promise.all(promises);
    }
    
    console.log(`\n   ✅ Successfully migrated: ${successCount}`);
    console.log(`   ⏭️  Skipped (already exists): ${skippedCount}`);
    if (errorCount > 0) {
      console.log(`   ❌ Errors: ${errorCount}`);
    }
    
    return { success: successCount, skipped: skippedCount, errors: errorCount };
  } catch (error) {
    console.error(`   ❌ Error migrating category ${category}:`, error.message);
    return { success: 0, skipped: 0, errors: 1 };
  }
}

/**
 * Detect the correct bucket name
 */
async function detectBucketName() {
  try {
    // Try to list buckets to find the correct one
    const [buckets] = await storage.getBuckets();
    if (buckets.length > 0) {
      console.log(`\n📦 Found ${buckets.length} bucket(s):`);
      buckets.forEach(b => console.log(`   - ${b.name}`));
      
      // Try to find a bucket that matches our project or contains collection_icons
      const projectBucket = buckets.find(b => b.name.includes(projectId));
      if (projectBucket) {
        console.log(`   ✅ Using project bucket: ${projectBucket.name}\n`);
        return projectBucket.name;
      }
      
      // Try each bucket to see which one has collection_icons
      for (const bucketObj of buckets) {
        try {
          const [files] = await bucketObj.getFiles({ prefix: 'collection_icons/', maxResults: 1 });
          if (files.length > 0) {
            console.log(`   ✅ Found collection_icons in bucket: ${bucketObj.name}\n`);
            return bucketObj.name;
          }
        } catch (e) {
          // Continue to next bucket
        }
      }
      
      // Fallback to first bucket
      console.log(`   ⚠️  Using first available bucket: ${buckets[0].name}\n`);
      return buckets[0].name;
    }
  } catch (error) {
    console.log(`   ⚠️  Could not list buckets: ${error.message}`);
    console.log(`   Will try with default bucket: ${storageBucket}\n`);
  }
  
  return storageBucket;
}

/**
 * Main migration function
 */
async function main() {
  console.log('\n🎯 Starting collection icons migration...\n');
  
  // Try to detect the correct bucket name
  const detectedBucket = await detectBucketName();
  if (detectedBucket !== storageBucket) {
    storageBucket = detectedBucket;
    bucket = storage.bucket(storageBucket);
    console.log(`   Using bucket: ${storageBucket}\n`);
  }
  
  const results = {
    total: { success: 0, skipped: 0, errors: 0 }
  };
  
  for (const category of categories) {
    const result = await migrateCategory(category);
    results[category] = result;
    results.total.success += result.success;
    results.total.skipped += result.skipped;
    results.total.errors += result.errors;
  }
  
  console.log('\n' + '='.repeat(50));
  console.log('📊 Migration Summary');
  console.log('='.repeat(50));
  
  for (const category of categories) {
    const result = results[category];
    console.log(`${category.padEnd(10)}: ✅ ${result.success.toString().padStart(4)}  ⏭️  ${result.skipped.toString().padStart(4)}  ❌ ${result.errors.toString().padStart(4)}`);
  }
  
  console.log('-'.repeat(50));
  console.log(`TOTAL       : ✅ ${results.total.success.toString().padStart(4)}  ⏭️  ${results.total.skipped.toString().padStart(4)}  ❌ ${results.total.errors.toString().padStart(4)}`);
  console.log('='.repeat(50));
  
  if (results.total.errors === 0) {
    console.log('\n🎉 Migration completed successfully!');
  } else {
    console.log('\n⚠️  Migration completed with some errors. Please review the output above.');
  }
  
  process.exit(results.total.errors > 0 ? 1 : 0);
}

// Run migration
main().catch((error) => {
  console.error('\n❌ Fatal error:', error);
  process.exit(1);
});

