# iOS CI/CD Pipeline
This repository uses GitHub Actions for PR-gated E2E, Firebase rule deploys, and automated TestFlight/App Store uploads. (chore: test CI)

## Workflows

### 1. PR Checks (`pr-checks.yml`)
- **Trigger**: Pull requests targeting the `staging` branch
- **Action**: Generates config (xcconfig, Config.plist) from secrets, restores `unity-build/` from cache, builds the iOS app, then runs Appium E2E tests. Merge is allowed only when these pass (see Branch Protection).
- **Use Case**: Ensure changes are tested before merging to staging.
- **Requirements**: See "Secrets for PR Checks (E2E build)" and "unity-build cache" below.

### 2. Deploy Staging (`deploy-staging.yml`)
- **Trigger**: Push to the `staging` branch (e.g. after merging a PR)
- **Action**: (1) Deploys Firestore and Storage rules to the **staging** Firebase project. (2) Builds and uploads to TestFlight using the staging scheme (`fastlane beta`).
- **Use Case**: Staging environment is updated with latest code and rules.

### 3. Deploy Production (`deploy-production.yml`)
- **Trigger**: Push to the `main` branch, or manual workflow dispatch
- **Action**: (1) Deploys Firestore and Storage rules to the **production** Firebase project. (2) Optionally runs smoke E2E against the production app. (3) Builds and uploads to TestFlight/App Store using the production scheme (`fastlane production`).
- **Use Case**: Production release with rules and app in sync.

### 4. Build Unity and cache (`build-unity-cache.yml`) — automates unity-build cache
- **Trigger**: Push to `staging` when files under `nose-unity/**` change, or manual workflow dispatch.
- **Action**: Builds the Unity project for iOS (Game CI unity-builder), normalizes output to `unity-build/`, then caches `unity-build/` with the same key as PR Checks. PR Checks will then restore from cache without manual steps.
- **Use Case**: After changing the Unity project, this workflow runs (or trigger it manually); once it succeeds, E2E no longer needs a self-hosted run to populate the cache.
- **Requirements**: Unity の CI 用ライセンス。**Personal（無料）で可** — secret `UNITY_LICENSE` にライセンスファイルの内容を設定。Pro の場合は `UNITY_SERIAL` + `UNITY_EMAIL` + `UNITY_PASSWORD`。取得手順は [Game CI activation](https://game.ci/docs/github/activation)。

#### Unity のビルド＆cache をもう一度動かすには
1. **GitHub** でリポジトリを開く → **Actions** タブ
2. 左のワークフロー一覧から **「Build Unity and cache」** を選ぶ
3. 右の **「Run workflow」** をクリック
4. ブランチ（通常は `staging`）を選んで **「Run workflow」** で実行
5. 実行が緑で完了すれば、`unity-build/` の cache が更新される。以降の PR Checks はこの cache を使う

**自動で動かす場合**: `staging` に **`nose-unity/` 以下を変更したコミット** を push すると、同じワークフローが自動で走る。

### 5. AI PR Review (`ai-pr-review.yml`) — optional, cost-effective
- **Trigger**: Pull requests targeting `staging` or `main`, **only when the PR has the label `ai-review`** (saves API cost).
- **Action**: Posts an AI-generated code review comment. Uses `gpt-3.5-turbo` and `MAX_PATCH_LENGTH: 8000`. Requires `OPENAI_API_KEY` in secrets. Fails gracefully if the secret is missing (does not block merge).
- **Use Case**: Solo developer: add the `ai-review` label when you want AI feedback; leave it off for routine PRs.

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

### Unity (for Build Unity and cache)
**Unity Personal（無料）で CI ビルド可能。** 次の 3 つの secret を設定する。

1. **マシンで Unity を有効化して `.ulf` を用意する**
   - [Unity Hub](https://unity.com/download) を入れ、Unity にログインする。
   - **Unity Hub** → **Preferences** → **Licenses** → **Add** → 「Get a free personal license」で有効化する（ここをやらないと `.ulf` が作られない）。
   - ライセンスファイルの場所:
     - **Mac**: `/Library/Application Support/Unity/Unity_lic.ulf`
     - **Windows**: `C:\ProgramData\Unity\Unity_lic.ulf`
     - **Linux**: `~/.local/share/unity3d/Unity/Unity_lic.ulf`
2. **GitHub の secret を追加する**  
   **Settings** → **Secrets and variables** → **Actions** で次を登録:
   - `UNITY_LICENSE`: 上記 `.ulf` ファイルを開き、**中身全体**をコピーして貼る。
   - `UNITY_EMAIL`: Unity にログインしているメールアドレス。
   - `UNITY_PASSWORD`: その Unity アカウントのパスワード。

Game CI はメール・パスワード・ライセンス内容を保存しない（ビルド時の有効化にのみ使用）。詳細は [Game CI – Activation (Personal)](https://game.ci/docs/github/activation)。

**Pro の場合**: `UNITY_SERIAL` + `UNITY_EMAIL` + `UNITY_PASSWORD` のみ（`UNITY_LICENSE` は不要）。

### Secrets for PR Checks (E2E build)
Required for the **PR Checks** workflow to build the app:

- `CI_ENV_FILE`: Contents of your `.env` file (or a CI-safe version with the same keys required by `scripts/generate_config_from_env.js`). Used to generate `nose/Configs/*.xcconfig` and `Config.plist`.
- `GOOGLE_SERVICE_INFO_DEVELOPMENT_PLIST`: Full file content of `FirebaseConfig/GoogleService-Info-Development.plist`.
- `GOOGLE_SERVICE_INFO_STAGING_PLIST`: Full file content of `FirebaseConfig/GoogleService-Info-Staging.plist`.
- `GOOGLE_SERVICE_INFO_PRODUCTION_PLIST`: Full file content of `FirebaseConfig/GoogleService-Info-Production.plist`.

If a plist contains special characters or newlines, base64-encode it and in the workflow use `echo "$SECRET" | base64 -d > path` (you would need to add a small decode step).

### unity-build cache (for PR Checks)
The app depends on **Unity** (`unity-build/Unity-iPhone.xcodeproj` → UnityFramework). The folder `unity-build/` is gitignored. The workflow restores it from **actions/cache** with key based on `nose-unity/`. To populate the cache automatically: use the **Build Unity and cache** workflow (`build-unity-cache.yml`). It runs on push to `staging` when `nose-unity/**` changes (or manually); it builds Unity for iOS and caches `unity-build/`, so PR Checks can restore it without self-hosted runs. You need a Unity license for CI: set secret `UNITY_LICENSE` (Personal) or `UNITY_SERIAL` + `UNITY_EMAIL` + `UNITY_PASSWORD` (Pro). To obtain `UNITY_LICENSE`: activate Unity on a machine, then copy the license file (see [Game CI licensing](https://game.ci/docs/github/activation)).

### Optional: AI PR review
- `OPENAI_API_KEY`: OpenAI API key for the optional **AI PR Review** workflow (`ai-pr-review.yml`). The workflow runs only when a PR has the **`ai-review`** label (cost-effective). Create the label in **Settings → Labels** if it does not exist. The job uses `continue-on-error: true`, so missing or invalid key does not block merges.

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
