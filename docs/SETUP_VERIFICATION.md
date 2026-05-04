# First-time setup & verification checklist

This document walks through every manual step needed to make the full
DevOps/CI/AI stack work, and gives you concrete ways to verify each piece is
live. Check items off as you go.

If you're just getting the app building, start with [`SETUP.md`](../SETUP.md).
This document is for wiring up the **Observability → Quality gates → AI →
Release automation** stack on top of a working build.

---

## 0. Prerequisites

- [ ] macOS with Xcode installed (project uses Xcode 16.2 in CI — match locally
      when possible)
- [ ] Homebrew installed
- [ ] Ruby + Bundler available (`gem install bundler` if missing)
- [ ] Node 20+ available
- [ ] You've completed [`SETUP.md`](../SETUP.md) and can build `nose-staging` in
      Xcode

---

## 1. Install local tooling

```bash
brew install swiftlint swiftformat lefthook maestro
bundle install
pod install
lefthook install   # installs pre-commit + commit-msg git hooks
```

- [ ] `swiftlint version` prints a version
- [ ] `swiftformat --version` prints a version
- [ ] `lefthook version` prints a version
- [ ] `maestro --version` prints a version
- [ ] `ls .git/hooks/pre-commit` exists (created by `lefthook install`)

### Known transient issue

After running `pod install` for the first time, Xcode's SourceKit cache may
still surface "No such module 'FirebaseCrashlytics'" / "No such module
'FirebaseCore'" errors until it re-indexes. **This is cosmetic.** Clean build
folder (Cmd+Shift+K) and rebuild once; it resolves itself.

---

## 2. GitHub secrets

Add these under **Settings → Secrets and variables → Actions** on the GitHub
repo. Items marked _(existing)_ should already be set from the original CI
setup — just verify they're still there.

### Required — new for this rollout

- [ ] `ANTHROPIC_API_KEY` — powers the AI PR reviewer
      (`.github/workflows/ai-pr-review.yml`). Get one from
      <https://console.anthropic.com/>.

### Optional — new for this rollout

- [ ] `RELEASE_PUSH_TOKEN` — a GitHub Personal Access Token (fine-grained, with
      `contents: write` on this repo) used by `deploy-production.yml` to push
      the `chore(release): bump version` commit back to `main` and create
      tags. If unset, the workflow falls back to `GITHUB_TOKEN`, which can
      create tags but cannot push to a branch-protected `main`. Without this
      secret, the auto-bump commits will be created locally on the runner but
      never make it back to the repo.

### Existing (verify still present)

- [ ] `APP_STORE_CONNECT_API_KEY`, `APP_STORE_CONNECT_API_KEY_ID`,
      `APP_STORE_CONNECT_API_KEY_ISSUER_ID`
- [ ] `FASTLANE_USER`, `FASTLANE_PASSWORD`,
      `FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD`
- [ ] `FIREBASE_SERVICE_ACCOUNT_STAGING`, `FIREBASE_SERVICE_ACCOUNT_PRODUCTION`
- [ ] `GOOGLE_SERVICE_INFO_DEVELOPMENT_PLIST`,
      `GOOGLE_SERVICE_INFO_STAGING_PLIST`,
      `GOOGLE_SERVICE_INFO_PRODUCTION_PLIST`
- [ ] `CI_ENV_FILE`

---

## 3. Firebase Console — manual configuration

### Crashlytics

- [ ] Open Firebase Console → **nose-staging** project → Crashlytics → verify
      the dashboard shows the app (first crash from the verification step in
      §5 will populate it)
- [ ] Same for **nose-production**
- [ ] **Integrations → Email alerts**: enable **New issue** and **Velocity
      alert** notifications to your email. Optionally wire a Slack webhook if
      you have a workspace.

### Performance Monitoring

- [ ] Firebase Console → **nose-staging** → Performance → verify the app is
      reporting. Automatic traces (`app_start`, HTTP) appear within ~24 hours
      of the first real session.
- [ ] Once custom traces appear (`addressables_catalog_load`, `unity_init`,
      `home_initial_load`), set threshold alerts on the ones that matter to
      you (e.g. alert if `unity_init` p95 > 3s).

---

## 4. Branch protection — recommended

On GitHub → **Settings → Branches**, for both `main` and `staging`:

- [ ] Require pull request reviews before merging (1 approval minimum; for
      solo-dev you are the reviewer — use the AI review as your first pass)
- [ ] Require status checks to pass: `swiftlint`, `swiftformat`, `pr-title`,
      `unit-tests`, `maestro-e2e`
- [ ] Do **not** require `claude-review` to pass (it's `continue-on-error` on
      purpose — don't block merges on AI availability)
- [ ] Require branches to be up to date before merging
- [ ] **Do not** allow force pushes

---

## 5. Verification — actually exercise each piece

This is where you confirm the stack works end-to-end. Do each of these after
the corresponding section is configured.

### Track A — Observability

- [ ] **Force a crash in staging**: add `fatalError("crashlytics test")`
      behind a debug-only button, build `nose-staging` on a device, tap it,
      relaunch. Within ~5 minutes a new issue appears in Firebase Console →
      Crashlytics → **nose-staging**. Delete the debug button, commit the
      removal.
- [ ] **Force a non-fatal**: add a one-off call to
      `Logger.reportNonFatal(message: "non-fatal test")` behind a debug
      button, run, tap. Appears under Crashlytics → Issues as a non-fatal.
      Delete after verifying.
- [ ] **Performance custom traces visible**: launch the app, navigate through
      Home (triggers `home_initial_load`), open the avatar customizer
      (triggers `unity_init` + `addressables_catalog_load`). Within 24 hours,
      check Firebase Console → Performance → Custom traces.
- [ ] **Crashlytics email alert received**: after the first test crash, you
      should receive the "new issue" email within ~10 min. If not, re-check
      §3 Integrations.

### Track B — AI workflow

- [ ] **Open a test PR**: create a throwaway branch with any small change
      (e.g. a typo fix), open a PR against `staging`. Within ~2 minutes the
      `claude-review` workflow posts a comment prefixed `## 🤖 Claude review`.
- [ ] **PR runs without the old label gate**: you should **not** need to add
      an `ai-review` label for the review to happen.
- [ ] **PR title check works**: open a PR with a non-conventional title like
      `"fix stuff"` — the `pr-title` check fails. Rename to `fix: clarify stuff`
      — it passes.
- [ ] **Slash commands resolve**: in Claude Code inside this repo, type `/`
      and verify these appear: `new-flow`, `new-screen`, `bump-firebase`,
      `ship-staging`, `triage-crash`, `update-claude-md`, `commit`,
      `gen-tests`.
- [ ] **`/commit` works**: stage a small change, run `/commit` in Claude Code,
      verify it proposes a conventional-commit message and commits only after
      you confirm.

### Track C — Code quality

- [ ] **Lefthook commit-msg rejects garbage**: try `git commit -m "nope"` — the
      hook rejects it. `git commit -m "chore: test lefthook"` passes.
- [ ] **SwiftFormat auto-fixes**: introduce a trailing-whitespace line, stage
      it, commit. Lefthook auto-runs `swiftformat` and restages the file.
- [ ] **SwiftLint CI job fails on real violations**: temporarily add
      `let x = foo!` somewhere and open a PR. The `swiftlint` CI job fails
      with a `force_unwrapping` error. Remove the change.
- [ ] **Unit tests run in CI**: the `unit-tests` job on a PR shows
      `xcodebuild test` output and reports the test count.
- [ ] **Coverage gathered**: the `unit-tests` job reports >0% line coverage.

### Track D — Release automation

- [ ] **Production workflow bumps version**: merge a `fix:` commit to `main`.
      The `Deploy Production` workflow should run, bump the patch version
      automatically in `MARKETING_VERSION`, and submit to App Store for review.
- [ ] **Dependabot opens a PR**: within a week, Dependabot should open at
      least one PR against `main` for a gem or action update. If nothing
      happens after 8 days, check GitHub → Insights → Dependency graph →
      Dependabot for errors.

---

## 6. Ongoing maintenance

Things to do occasionally to keep the stack healthy:

- **Monthly**: run `/bump-firebase` in Claude Code to review CocoaPods
  updates. Dependabot doesn't cover CocoaPods.
- **Monthly**: run `/update-claude-md` to refresh the AI context file if the
  repo structure has drifted.
- **Per release**: before running `fastlane release build_number:<N>`,
  double-check that `fastlane/metadata/en-US/release_notes.txt` and
  `fastlane/metadata/ja/release_notes.txt` look user-appropriate (the AI does
  a decent job but occasionally slips a developer term in).
- **Per incident**: when Crashlytics alerts fire, use `/triage-crash` in
  Claude Code with the stack trace to get a first-pass diagnosis.

---

## Reference

- Original plan file (on your machine, outside the repo):
  `~/.claude/plans/streamed-hopping-sunrise.md`
- Project conventions and architecture: [`../CLAUDE.md`](../CLAUDE.md)
- Build/env setup: [`../SETUP.md`](../SETUP.md)
- Top-level overview: [`../README.md`](../README.md)
