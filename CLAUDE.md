# CLAUDE.md

Project context for Claude Code (local) and the Claude PR review workflow.
Keep this file up to date — it's the single source of truth for AI tooling.
When the repo structure changes meaningfully, re-run `/update-claude-md`.

## Architecture

**nose** is an iOS social bookmarking app (iPhone-only, iOS 17+) with an
embedded Unity subproject used for avatar customization and rendering. All
backend services run on Firebase (Auth, Firestore, Storage, Hosting, Crashlytics,
Performance Monitoring, Analytics).

- **Client**: Swift + UIKit (no SwiftUI yet), Mapbox Maps SDK, Google Places
- **Unity**: 3D avatar customization via UaaL (Unity-as-a-Library). Only
  runs on physical devices — simulator builds must skip Unity (`EXCLUDE_UNITY=1`)
- **Backend**: Firebase (3 projects, one per environment)
- **Environments**: Development / Staging / Production with matching Xcode
  build configurations and schemes
- **Addressables**: Unity assets are hosted per-environment on Firebase Hosting;
  the iOS app fetches the catalog at runtime

## Build configs and schemes

| Scheme           | Configuration | Firebase project    | Use                        |
|------------------|---------------|---------------------|----------------------------|
| `nose`           | Development   | nose-development    | Daily local development    |
| `nose-staging`   | Staging       | nose-staging        | TestFlight beta (internal) |
| `nose-production`| Production    | nose-production     | App Store + TestFlight     |
| `nose-e2e`       | Development   | nose-development    | Maestro E2E runs           |

`GoogleService-Info-<Config>.plist` is copied into the app bundle by the
"Copy GoogleService-Info.plist" Run Script build phase on each build.

## Environment detection

At runtime, the app reads the `NoseEnvironment` key from `Info.plist` via:

```swift
let env = Bundle.main.object(forInfoDictionaryKey: "NoseEnvironment") as? String ?? "Development"
```

Values are `"Development"`, `"Staging"`, or `"Production"` (case-insensitive
compare). Config.plist carries per-environment URLs:
`AddressablesCatalogURLProduction`, `AddressablesCatalogURLStaging`,
`AddressablesCatalogURL` (development fallback).

## Navigation architecture

- `HomeViewController` is the nav root. It **hides the nav bar** in `viewWillAppear`.
- The footer "Personal Library" button (`profileButton`) pushes
  `SettingsViewController` onto the nav stack.
- Settings pushes child VCs (Account, EditName, AddFriend, FriendList,
  Licenses, etc.). Typical depth: Home → Settings → AddFriend.
- Unity avatar screens (`FloatingUIController`, collection avatar editor)
  are presented **modally**, not pushed.

## Key directories

```
nose/
├── AppDelegate.swift        Firebase.configure(), Mapbox token, Google Places
├── SceneDelegate.swift
├── Managers/
│   ├── Core/                Logger, FirestorePaths
│   ├── Services/            CollectionLoadingService, EventManager,
│   │                        CollectionDataService, Unity/UnityManager.swift
│   ├── Map/                 MapboxMapManager, SearchManager
│   └── Navigation/          DeepLinkManager
├── Models/                  PlaceCollection, User, Event, CollectionAvatar
├── ViewControllers/
│   ├── Home/                HomeViewController (map + footer)
│   ├── Login/               LoginViewController (Google/Apple Sign In)
│   ├── Setup/               NameRegistrationViewController
│   ├── Profile/Settings/    SettingsViewController + child VCs
│   ├── Event/               CreateEventViewController, ManageEventViewController
│   └── UnityAvatar/         FloatingUIController (+AssetLoading extension)
├── Components/              Reusable UI (IconButton, cells, modals)
├── Configs/                 Build-time config loaders
├── Resources/               Assets, JSON bundles
└── PrivacyInfo.xcprivacy    Declares CrashData, DeviceID, UserID collection
FirebaseConfig/              GoogleService-Info-*.plist, firestore.rules
fastlane/                    Fastfile with beta/production/build/distribute/release lanes
.maestro/flows/              E2E flows (see .maestro/README.md)
.github/workflows/           CI workflows (deploy-*, pr-checks, ai-pr-review, claude-*)
scripts/                     Build tooling, addressables deploy, config generation
.claude/commands/            Claude Code slash commands for repetitive chores
.claude/hooks/               Hook scripts (sensitive file protection)
.claude/settings.json        Project-level Claude Code hooks config
nose-unity/                  Unity project (Avatar customization)
```

## Commands

### Build
```bash
# Local build from the workspace (not the project!)
xcodebuild -workspace nose.xcworkspace -scheme nose-staging build

# Fastlane build
bundle exec fastlane build
```

### Run unit tests
```bash
xcodebuild test \
  -workspace nose.xcworkspace \
  -scheme nose-staging \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  -only-testing:noseTests \
  EXCLUDE_UNITY=1
```

### Run Maestro flows
```bash
# Single flow
maestro test .maestro/flows/01_account_creation_01_create_user_a.yaml

# Full suite
bundle exec fastlane e2e
```

### Ship to TestFlight
```bash
bundle exec fastlane beta        # staging → TestFlight internal
bundle exec fastlane production  # production → TestFlight + App Store
```

### Submit to App Store
```bash
bundle exec fastlane release build_number:'<N>'
```

### Lint + format
```bash
swiftlint                            # Check
swiftformat nose noseTests           # Auto-format
swiftformat --lint nose noseTests    # CI-style check
```

## Conventions

- **Logging**: Use `Logger.log(message, level:, category:)` for local logs.
  Use `Logger.reportNonFatal(error, category:, context:)` at service
  boundaries (network, Firebase, Unity bridge) to forward to Crashlytics.
  Never `print(...)` directly in production code.
- **Force unwraps**: Banned in VCs and services. Use `guard let` / `if let`.
  SwiftLint enforces `force_unwrapping` as a warning.
- **File length**: 500 lines = warning, 1000 = error. Split large VCs into
  extensions in separate files (see `FloatingUIController+AssetLoading.swift`).
- **Commits**: Conventional Commits (`feat:`, `fix:`, `chore:`, etc.).
  Enforced by lefthook `commit-msg` hook and the PR-title CI check.
- **PRs**: Title must be a conventional commit. Squash-merge uses the PR
  title as the commit message.
- **Branches**: `feature/*` → PR → `staging` → PR → `main`. Direct pushes
  to `staging`/`main` are blocked by branch protection.

## Testing

- **Unit tests**: `noseTests/`. Organized by subject (`Managers/`,
  `Helpers/`). Keep tests hermetic — use `FirebaseMock.configureIfNeeded()`
  if you need Firebase types. Code coverage is enabled on `nose-staging`
  and `nose-production` schemes.
- **E2E**: `.maestro/flows/*.yaml`. Flow naming: `NN_feature_NN_scenario.yaml`.
  Shared steps live in `.maestro/shared/`. Numbered prefixes express
  ordering — flows 01-09 are onboarding, 90-99 are teardown.
- **Adding a new Maestro flow**: Use `/new-flow <screen>` in Claude Code.

## Known gotchas

- **Unity doesn't run on simulator.** Pass `EXCLUDE_UNITY=1` to `xcodebuild`
  or set it in the scheme's Run > Arguments. The `patch_project_exclude_unity.sh`
  script handles this for CI.
- **Mapbox dSYM warnings during archive** are safe to ignore (Mapbox ships
  pre-built frameworks).
- **iPhone-only build.** `TARGETED_DEVICE_FAMILY = 1`. Don't enable iPad in
  scheme deploy settings — layout will break.
- **Addressables catalog URL is read from `Config.plist` per environment.**
  When adding a new environment, add the key in both `UnityManager.configureUnityRemoteCatalogURL()`
  and `FloatingUIController.addressablesCatalogURL()`.
- **Pods fast path**: `SourceKit: No such module ...` errors after editing
  the Podfile mean the user needs to run `bundle exec pod install`.
- **Firebase Crashlytics dSYM upload** runs as a Run Script build phase on
  every build (`[CP] Crashlytics Upload dSYMs`). Fastlane lanes additionally
  call `upload_symbols_to_crashlytics` after `build_app` so release builds
  ship fully symbolicated.
- **Login flow cancellation is not a failure.** Google Sign In code `-5`
  and Apple `ASAuthorizationError.canceled` must NOT be reported as
  non-fatals. See `LoginViewController` for the pattern.

## AI agent workflows

### Issue → PR full-auto flow

```
[Issue + claude:implement label] → [claude-implement.yml] Claude implements → PR to staging
  → [pr-checks.yml] Lint/Tests/E2E → [auto-generate-tests.yml] Auto-gen tests (claude/ branches)
  → [ai-pr-review.yml] AI review
  → [CI failure on claude/ branch?] → [claude-ci-fix.yml] Auto-fix (max 3×)
  → [@claude comment on PR] → [claude-pr-assist.yml] Follow-up
  → [Human review → Merge → staging → deploy]

[Crashlytics crash] → [crashlytics-to-issue.yml] AI triage → Issue + claude:fix → (auto-fix pipeline above)

[Dependabot PR] → [dependabot-auto-merge.yml] patch/minor auto-merge, major → needs-review

[Weekly / manual] → [create-release-pr.yml] staging → main release PR with AI summary
```

### GitHub labels

| Label              | Purpose                                    |
|--------------------|--------------------------------------------|
| `claude:implement` | Triggers Claude to implement a feature/chore from an issue |
| `claude:fix`       | Triggers Claude to implement a bug fix from an issue       |
| `needs-review`     | Major dependency update — needs human review |
| `bug`              | Something isn't working                     |
| `crash`            | App crash from Crashlytics                  |

### CI workflows (Claude agent)

| Workflow                 | File                                  | Trigger                         | What it does                                   |
|--------------------------|---------------------------------------|---------------------------------|------------------------------------------------|
| Claude: Implement Issue  | `claude-implement.yml`                | `claude:implement`/`claude:fix` label on issue | Branches from staging, implements, opens PR    |
| Claude: PR Assist        | `claude-pr-assist.yml`                | `@claude` in PR comment         | Code fixes or question answers on demand       |
| Claude: Fix CI           | `claude-ci-fix.yml`                   | `pr-checks` failure on `claude/` branch | Reads logs, fixes source, pushes (max 3×)      |
| Claude: Auto-gen Tests   | `auto-generate-tests.yml`             | PR to staging with Swift changes on `claude/` branch | Generates unit tests for changed files         |

All four use `@anthropics/claude-code-action@v1` with `claude-sonnet-4-6`.

### CI workflows (automation)

| Workflow                 | File                                  | Trigger                         | What it does                                   |
|--------------------------|---------------------------------------|---------------------------------|------------------------------------------------|
| Dependabot: Auto-merge   | `dependabot-auto-merge.yml`           | Dependabot PR opened            | Auto-merges patch/minor; escalates major       |
| Release: Create PR       | `create-release-pr.yml`               | Weekly schedule + manual        | Creates staging → main PR with changelog       |
| Crashlytics: Create Issue| `crashlytics-to-issue.yml`            | Manual dispatch                 | AI-triages stack trace, creates issue, optionally triggers auto-fix |

### Safety controls

- **Label gate**: Only human-applied labels trigger implementation.
- **Branch protection**: Claude PRs target `staging`, never push directly.
- **Existing CI gate**: Claude PRs pass the same lint/test/E2E checks as human PRs.
- **Loop prevention**: CI auto-fix stops after 3 `fix(ci):` commits and escalates.
- **Cost control**: `max_turns` (10–25), timeouts (15–25 min), Sonnet model.
- **Sensitive file protection**: Workflows and hooks block writes to `.env`,
  `GoogleService-Info*.plist`, `*.pbxproj`, lock files.
- **Tool restriction**: `allowedTools` disables WebSearch/WebFetch in CI.

### Prerequisites

| Item                | Status          | Action                           |
|---------------------|-----------------|----------------------------------|
| `ANTHROPIC_API_KEY` | In repo secrets | None                             |
| `GITHUB_TOKEN`      | Auto-provided   | None                             |
| Claude GitHub App   | Required        | Install on repo                  |
| GitHub Labels       | Required        | Create `claude:implement`, `claude:fix`, `needs-review`, `bug`, `crash` |

## Claude Code hooks (`.claude/settings.json`)

Project-level hooks run automatically during local Claude Code sessions:

| Hook            | Event        | Matcher       | What it does                                       |
|-----------------|-------------|---------------|----------------------------------------------------|
| Sensitive guard | PreToolUse  | `Write\|Edit` | Blocks writes to `.env`, plists, `.pbxproj`, locks |
| Auto-format     | PostToolUse | `Write\|Edit` | Runs `swiftformat` on edited `.swift` files        |
| Notification    | Notification| (all)         | macOS notification when Claude Code needs input     |

Hook scripts live in `.claude/hooks/`.

## AI slash commands (`.claude/commands/`)

| Command                       | What it does                                              |
|-------------------------------|-----------------------------------------------------------|
| `/new-flow <name>`            | Scaffolds a new Maestro flow YAML                         |
| `/new-screen <name>`          | Scaffolds a VC + nav wiring following Home→Settings       |
| `/bump-firebase`              | Checks Firebase pod versions, updates Podfile             |
| `/ship-staging`               | Pre-flight checklist + push to `staging`                  |
| `/triage-crash`               | Reads a Crashlytics stack trace and proposes a fix        |
| `/gen-tests <file>`           | Generates XCTest unit tests for pure functions in a file  |
| `/commit`                     | AI-authored conventional commit message from staged diff  |
| `/update-claude-md`           | Re-scans the repo and updates this file                   |
| `/implement-issue <number>`   | Implements a GitHub issue locally (branch + code + commit)|
| `/fix-ci [PR number]`         | Fetches CI failure logs and fixes issues locally          |
