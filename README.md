# nose

iOS app for discovering, collecting, and sharing places with friends, with a
customizable 3D avatar powered by an embedded Unity runtime. Built with Swift +
UIKit on top of Firebase (Auth, Firestore, Storage), Mapbox, Google Places, and
Unity-as-a-Library.

> **Looking for project conventions, architecture notes, or navigation rules?**
> See [`CLAUDE.md`](./CLAUDE.md). That file is the canonical reference for both
> human contributors and AI tooling.

---

## Quick start

```bash
# 1. Prereqs
brew install swiftlint swiftformat lefthook maestro
gem install bundler && bundle install
pod install

# 2. Environment setup (Firebase plists, .env → Config.plist, xcconfig)
cp .env.example .env   # then fill it in
node scripts/generate_config_from_env.js

# 3. Install git hooks
lefthook install

# 4. Open in Xcode
open nose.xcworkspace
```

Full setup instructions live in [`SETUP.md`](./SETUP.md).

---

## First-time setup & verification

After you can build the app, there are a handful of manual steps to light up
the observability / AI / release-automation stack. **See the full checklist in
[`docs/SETUP_VERIFICATION.md`](./docs/SETUP_VERIFICATION.md).**

TL;DR:

- [ ] `brew install swiftlint swiftformat lefthook maestro && lefthook install`
- [ ] Add `ANTHROPIC_API_KEY` to GitHub repo secrets (AI PR reviewer +
      release notes)
- [ ] Add `RELEASE_PUSH_TOKEN` PAT to GitHub repo secrets (optional, needed
      for auto-bump commits to reach `main`)
- [ ] Firebase Console → Crashlytics → Integrations → enable email alerts
- [ ] Force-crash a staging build (`fatalError("test")`) to verify Crashlytics
      ingestion
- [ ] Open a throwaway PR to verify the Claude reviewer comments within ~2 min

The detailed doc has verification steps for every track (Observability, AI,
Quality gates, Release automation) plus ongoing-maintenance reminders.

---

## Architecture at a glance

- **Swift + UIKit**, no SwiftUI. Navigation is a `UINavigationController` with
  `HomeViewController` as the root (nav bar hidden). Settings and its children
  push onto the stack; Unity avatar screens are modal.
- **Embedded Unity** runtime for avatar customization — device-only, does not
  run on the iOS simulator. Set `EXCLUDE_UNITY=1` when running unit tests or
  Maestro on simulators.
- **Firebase backend**: Auth (Google + Apple), Firestore, Storage, Crashlytics,
  Performance Monitoring, Hosting (for Addressables catalog).
- **3 environments**: `Development`, `Staging`, `Production`, each with their
  own Firebase project, `GoogleService-Info-*.plist`, Addressables catalog URL,
  and Xcode scheme (`nose`, `nose-staging`, `nose-production`).
- **Logging**: everything goes through `Logger` in
  [`nose/Managers/Core/Logger.swift`](nose/Managers/Core/Logger.swift). Errors
  at service boundaries are forwarded to Crashlytics as non-fatals via
  `Logger.reportNonFatal(...)`.

See [`CLAUDE.md`](./CLAUDE.md) for the full list of directories, commands,
known gotchas, and conventions.

---

## Release flow

```
feature/*   ─┐
             ├─► PR ──► AI review (Claude) + lint + unit tests + Maestro smoke
             │          │
             │          └─► merge to staging  ──► Deploy Staging workflow
             │                                     ├─ deploy Firebase (staging)
             │                                     └─ TestFlight build (nose-staging)
             │
             └─► test manually on TestFlight
                        │
                        ▼
             merge staging → main  ──► Deploy Production workflow
                                        ├─ deploy Firebase (production)
                                        ├─ smoke E2E (production)
                                        ├─ bump MARKETING_VERSION from conventional commits
                                        ├─ TestFlight build (nose-production)
                                        ├─ AI-generated release notes (en + ja)
                                        ├─ push git tag v<version>
                                        └─ GitHub Release with .ipa attached

             # When ready to submit to App Store:
             fastlane release build_number:'<N>'
```

### Manual scripts

| Command | Purpose |
|---|---|
| `fastlane beta` | Build + upload to TestFlight (staging) |
| `fastlane release [build_number:<N>]` | Build + submit to App Store for review (auto-increments build number if omitted) |
| `scripts/bump_version.sh [--tag]` | Conventional-commits-driven semver bump |
| `scripts/update_changelog.sh <version>` | Prepend a new section to `CHANGELOG.md` |
| `scripts/generate_release_notes.sh` | AI-generated TestFlight notes (en + ja) |

---

## Code quality

Everything is checked both locally (pre-commit) and in CI:

| Tool | Config | Enforced by |
|---|---|---|
| **SwiftLint** | `.swiftlint.yml` | Lefthook + `pr-checks.yml` |
| **SwiftFormat** | `.swiftformat` | Lefthook + `pr-checks.yml` |
| **Lefthook** | `lefthook.yml` | `lefthook install` (pre-commit, commit-msg) |
| **Conventional Commits** | Lefthook regex + `amannn/action-semantic-pull-request` | commit-msg hook + PR title check |
| **Unit tests** | `noseTests/` + `.xcscheme` coverage | `pr-checks.yml` |
| **E2E** | `.maestro/*.yaml` | `pr-checks.yml` → `maestro-e2e-reusable.yml` |

First-time contributors: after cloning, run `lefthook install` so the pre-commit
hooks are active.

---

## AI tooling

This repo is heavily AI-assisted. Relevant files and commands:

- **[`CLAUDE.md`](./CLAUDE.md)** — canonical project context consumed by both
  local Claude Code and the GitHub Actions PR reviewer.
- **`.claude/commands/`** — repo-local slash commands for Claude Code:
  - `/new-flow` — scaffold a Maestro E2E flow
  - `/new-screen` — scaffold a UIKit view controller
  - `/bump-firebase` — AI-assisted CocoaPods bump
  - `/ship-staging` — pre-flight checklist + push to staging
  - `/triage-crash` — read a Crashlytics stack trace and propose a fix
  - `/update-claude-md` — re-scan the repo and refresh `CLAUDE.md`
  - `/commit` — generate a Conventional Commits message from staged diff
  - `/gen-tests` — scaffold unit tests for a file
- **`.github/workflows/ai-pr-review.yml`** — Claude (`claude-sonnet-4-5`)
  reviews every PR to `staging` / `main`, focusing on real bugs.
- **`scripts/generate_release_notes.sh`** — Claude-generated English + Japanese
  release notes (currently unused; can be integrated into custom lanes).

Secrets required in GitHub repo settings:

- `ANTHROPIC_API_KEY` — PR review + release notes
- `RELEASE_PUSH_TOKEN` (optional) — PAT with `contents: write` so
  `deploy-production.yml` can push the version bump commit back to `main`.
  Falls back to `GITHUB_TOKEN` (tags only) if unset.

---

## Directory layout (top level)

```
nose/                  — iOS app source (Swift, UIKit)
nose-unity/            — Unity project (built separately, embedded as framework)
noseTests/             — XCTest unit tests
noseUITests/           — Placeholder (Maestro replaced XCUITest)
.maestro/              — Maestro E2E flows
.github/workflows/     — CI/CD
.claude/commands/      — Claude Code slash commands
fastlane/              — Fastlane lanes and metadata
FirebaseConfig/        — Firebase rules, per-env plists (gitignored)
scripts/               — Build, deploy, release-automation scripts
```

For a comprehensive tree with descriptions, see [`CLAUDE.md`](./CLAUDE.md).

---

## License

Proprietary. All rights reserved.
