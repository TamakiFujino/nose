#!/usr/bin/env node

/**
 * Generate iOS config files from .env
 *
 * Run from repo root: node scripts/generate_config_from_env.js
 *
 * Requires: copy .env.example to .env and fill in values first.
 */

const fs = require('fs');
const path = require('path');

// Load .env from repo root (one level up from scripts/)
const repoRoot = path.resolve(__dirname, '..');
const envPath = path.join(repoRoot, '.env');

if (!fs.existsSync(envPath)) {
  console.error('❌ .env not found at', envPath);
  console.error('   Copy .env.example to .env and fill in your values.');
  process.exit(1);
}

// Parse .env manually to avoid adding dotenv dependency for this script
const envContent = fs.readFileSync(envPath, 'utf8');
const env = {};
for (const line of envContent.split('\n')) {
  const trimmed = line.trim();
  if (!trimmed || trimmed.startsWith('#')) continue;
  const eq = trimmed.indexOf('=');
  if (eq === -1) continue;
  const key = trimmed.slice(0, eq).trim();
  let value = trimmed.slice(eq + 1).trim();
  if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
    value = value.slice(1, -1).replace(/\\(.)/g, '$1');
  }
  env[key] = value;
}

function get(key, required = true) {
  const v = env[key];
  if (required && (v === undefined || v === '')) {
    console.error('❌ Missing or empty required key in .env:', key);
    process.exit(1);
  }
  return v || '';
}

function escapePlistString(s) {
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

// Required for app build (Google OAuth and Maps/Places)
const requiredKeys = [
  'GOOGLE_PLACES_API_KEY',
  'GOOGLE_MAPS_API_KEY',
  'MAPBOX_ACCESS_TOKEN',
  'GOOGLE_CLIENT_ID_DEVELOPMENT',
  'GOOGLE_REVERSED_CLIENT_ID_DEVELOPMENT',
  'GOOGLE_CLIENT_ID_STAGING',
  'GOOGLE_REVERSED_CLIENT_ID_STAGING',
  'GOOGLE_CLIENT_ID_PRODUCTION',
  'GOOGLE_REVERSED_CLIENT_ID_PRODUCTION',
];
for (const key of requiredKeys) {
  if ((env[key] || '').trim() === '') {
    console.error('❌ Missing or empty required key in .env:', key);
    process.exit(1);
  }
}

// 1. Write Config.plist
const configPlistPath = path.join(repoRoot, 'Config.plist');
const configPlist = `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>GooglePlacesAPIKey</key>
	<string>${escapePlistString(get('GOOGLE_PLACES_API_KEY'))}</string>
	<key>GoogleMapsAPIKey</key>
	<string>${escapePlistString(get('GOOGLE_MAPS_API_KEY'))}</string>
	<key>GoogleMapsMapID</key>
	<string>${escapePlistString(get('GOOGLE_MAPS_MAP_ID', false))}</string>
	<key>MapboxAccessToken</key>
	<string>${escapePlistString(get('MAPBOX_ACCESS_TOKEN'))}</string>
	<key>FirebaseHostingBaseURL</key>
	<string>${escapePlistString(get('FIREBASE_HOSTING_BASE_URL', false))}</string>
	<key>AddressablesCatalogURL</key>
	<string>${escapePlistString(get('ADDRESSABLES_CATALOG_URL', false))}</string>
	<key>AddressablesCatalogURLStaging</key>
	<string>${escapePlistString(get('ADDRESSABLES_CATALOG_URL_STAGING', false))}</string>
</dict>
</plist>
`;
fs.writeFileSync(configPlistPath, configPlist, 'utf8');
console.log('✅ Wrote Config.plist');

// 2. Generate xcconfig files from .example templates
const configsDir = path.join(repoRoot, 'nose', 'Configs');
const envs = [
  { name: 'Development', suffix: 'DEVELOPMENT' },
  { name: 'Staging', suffix: 'STAGING' },
  { name: 'Production', suffix: 'PRODUCTION' },
];

for (const { name, suffix } of envs) {
  const examplePath = path.join(configsDir, `${name}.xcconfig.example`);
  const outPath = path.join(configsDir, `${name}.xcconfig`);
  if (!fs.existsSync(examplePath)) {
    console.error('❌ Template not found:', examplePath);
    process.exit(1);
  }
  let content = fs.readFileSync(examplePath, 'utf8');
  content = content.replace(/\$\{([^}]+)\}/g, (_, key) => env[key.trim()] ?? '');
  fs.writeFileSync(outPath, content, 'utf8');
  console.log('✅ Wrote nose/Configs/' + name + '.xcconfig');
}

// 3. Generate TestConfig.generated.swift for UI tests (optional)
const testUserAEmail = get('TEST_USER_A_EMAIL', false);
const testUserBEmail = get('TEST_USER_B_EMAIL', false);
const testHelpersDir = path.join(repoRoot, 'noseUITests', 'Helpers');
const generatedPath = path.join(testHelpersDir, 'TestConfig.generated.swift');

const generatedSwift = `// Generated from .env by scripts/generate_config_from_env.js - do not edit
import Foundation

enum TestConfigGenerated {
    static let userAEmail = "${(testUserAEmail || '').replace(/"/g, '\\"')}"
    static let userBEmail = "${(testUserBEmail || '').replace(/"/g, '\\"')}"
}
`;
fs.mkdirSync(testHelpersDir, { recursive: true });
fs.writeFileSync(generatedPath, generatedSwift, 'utf8');
console.log('✅ Wrote noseUITests/Helpers/TestConfig.generated.swift');

console.log('');
console.log('Done. You can build the app now.');
