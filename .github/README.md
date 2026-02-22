# iOS CI/CD Pipeline

This repository uses GitHub Actions for PR-gated E2E, Firebase rule deploys, and automated TestFlight/App Store uploads.

## Workflows

### 1. PR Checks (`pr-checks.yml`)
- **Trigger**: Pull requests targeting the `staging` branch
- **Action**: Runs Appium E2E tests (and optionally lint when configured). Merge is allowed only when these pass (see Branch Protection).
- **Use Case**: Ensure changes are tested before merging to staging.

### 2. Deploy Staging (`deploy-staging.yml`)
- **Trigger**: Push to the `staging` branch (e.g. after merging a PR)
- **Action**: (1) Deploys Firestore and Storage rules to the **staging** Firebase project. (2) Builds and uploads to TestFlight using the staging scheme (`fastlane beta`).
- **Use Case**: Staging environment is updated with latest code and rules.

### 3. Deploy Production (`deploy-production.yml`)
- **Trigger**: Push to the `main` branch, or manual workflow dispatch
- **Action**: (1) Deploys Firestore and Storage rules to the **production** Firebase project. (2) Optionally runs smoke E2E against the production app. (3) Builds and uploads to TestFlight/App Store using the production scheme (`fastlane production`).
- **Use Case**: Production release with rules and app in sync.

### 4. AI PR Review (`ai-pr-review.yml`) — optional
- **Trigger**: Pull requests opened or updated targeting `staging` or `main`
- **Action**: Posts an AI-generated code review comment on the PR. Requires `OPENAI_API_KEY` in secrets. Fails gracefully if the secret is missing (does not block merge).
- **Use Case**: Solo developer: get automated review feedback without a second human reviewer.

## Required Secrets

Configure these in **Settings → Secrets and variables → Actions**:

### App Store Connect / Fastlane (for TestFlight uploads)
- `APP_STORE_CONNECT_API_KEY`: App Store Connect API Key (JSON content)
- `APP_STORE_CONNECT_API_KEY_ID`: API Key ID
- `APP_STORE_CONNECT_API_KEY_ISSUER_ID`: Issuer ID
- `FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD`: App-specific password for Apple ID
- `FASTLANE_PASSWORD`: Apple ID password
- `FASTLANE_USER`: Apple ID email

### Firebase (for rule deploys)
- `FIREBASE_SERVICE_ACCOUNT_STAGING`: Service account JSON (full file contents) for the **staging** Firebase project (`nose-staging`). Used by `deploy-staging.yml`. Create in Firebase Console → Project settings → Service accounts → Generate new private key.
- `FIREBASE_SERVICE_ACCOUNT_PRODUCTION`: Service account JSON for the **production** Firebase project (`nose-production`). Used by `deploy-production.yml`.

### Optional: AI PR review
- `OPENAI_API_KEY`: OpenAI API key for the optional **AI PR Review** workflow (`ai-pr-review.yml`). When set, the workflow posts an AI-generated code review comment on pull requests to `staging` and `main`. The job uses `continue-on-error: true`, so missing or invalid key does not block merges.

## Branch Strategy

### Recommended Workflow

1. **Development**: Work on feature branches; open a PR to `staging`.
2. **Staging**: After PR checks (E2E) pass, merge to `staging`. CI deploys Firebase to staging and uploads to TestFlight (staging).
3. **Production**: Open a PR from `staging` to `main`. After merge, CI deploys Firebase to production and uploads to TestFlight/App Store (production).

### Branch Protection Rules

Configure in **Settings → Branches → Branch protection rules**:

- **`staging`**: Require status check **E2E** (from "PR Checks" workflow) to pass before merge. Optionally require **Lint** if you add a lint job.
- **`main`**: Require a pull request from `staging`, and require status checks if you run checks on the PR; or require at least one review if you prefer manual gate.

## Test Updates

Update tests in the **same PR** that changes app behavior. E2E tests live in `AppiumTests/`. When you add or change a feature, add or update the relevant test cases in that PR so the PR Checks workflow runs against the new behavior.

## Fastlane Lanes

### `beta` Lane
- Builds using `nose-staging` scheme
- Uploads to TestFlight
- Used for staging deployments

### `production` Lane
- Builds using `nose-production` scheme
- Uploads to TestFlight
- Used for production deployments

### `build` Lane
- Builds the app only (no upload)
- Useful for local testing

## Troubleshooting

See the main repository README or SETUP.md for build and environment issues. For CI: check GitHub Actions logs, verify secrets, and ensure branch protection status check names match the job names (e.g. **E2E**).
