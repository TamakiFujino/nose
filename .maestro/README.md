# Maestro E2E tests

## Test dependencies

Tests are refactored to run as independently as possible. When one test fails (e.g. name change, copy user ID), others should not cascade. Below is what creates shared state, what restores it, and what prerequisites remain.

### Flows that create shared state

- **01-01** – Copies User A's ID to clipboard (other flows can copy in-flow instead).
- **02-01** – Creates collection "National Parks" and shares with User B.
- **03-01** – Creates collection "Test Collection".

### Flows that restore state (independent teardown)

- **05-01** – Renames "Test Collection" → "Renamed Collection", then renames back to "Test Collection" at end.
- **05-02** – Renames "National Parks" → "Synced Rename", then renames back to "National Parks" at end.

### Tests that copy User A ID in-flow (no 01-01 required)

- **01-02** – Copies User A's ID at start, then User B signs in and pastes.
- **07-02** – Same pattern.
- **07-04** – Same pattern.

### Tests with remaining prerequisites

- **98-01** – Requires **05-01** to have run (expects "Test Collection" to exist).
- **01-03** – Requires **01-02** to have run (User B must have sent a friend request to User A).
- **04-01** – Expects "National Parks" and "Test Collection" to exist (run **02-01** and **03-01** at some point).

### Other independence behavior

- **07-01** – Re-shares "National Parks" with User B at start, so **06-02** need not run first.

Running order (e.g. `scripts/run_maestro.sh`) can still assume 02-01 and 03-01 create the two collections; individual flows that depend on clipboard or collection names now set up or restore as needed.
