# Changelog

All notable changes to the nose iOS app are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
the project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Entries are manually curated from Conventional Commits. Do not edit existing
entries by hand — amend the commit history instead. Seed entries under
`[Unreleased]` are fine.

## [Unreleased]

### Added
- Firebase Crashlytics + Performance Monitoring, Logger forwards non-fatals at service boundaries.
- Claude-powered PR review workflow and repo-local slash commands.
- SwiftLint, SwiftFormat, Lefthook pre-commit hooks, unit test scaffold.
- Conventional Commits PR title enforcement, automated version bump + changelog scripts.

### Changed
- Retired legacy XCUITest suite in favor of Maestro E2E flows.

### Removed
- Disabled XCTest UI test files under `noseUITests/`.
