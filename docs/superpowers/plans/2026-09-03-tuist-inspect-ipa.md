# Tuist Inspect Insights Implementation Plan

**Goal:** Report build insights from local Xcode builds and bundle-size insights from the ipa, without double-counting what the Tuist CLI already uploads.

**Architecture:** A build post-action on every generated scheme covers local Xcode builds — the one entry point the Tuist CLI never sees — guarded to skip CI, where `tuist xcodebuild archive` reports the build itself. The ipa task gains a single `tuist inspect bundle` call. Both are non-fatal.

**Spec:** `docs/superpowers/specs/2026-09-03-tuist-inspect-ipa-design.md`

**Status:** Implemented on `feat/tuist-inspect-insights`.

## Global Constraints

- Comment style per `AGENTS.md`: only `//`, and only where a reader would otherwise wonder why.
- Nothing added here may fail a build when the Tuist server is unreachable or the run is unauthenticated.
- Conventional commits for the commit message and the PR title.
- No changes to `ci.yml`, `Tuist.swift`, `fnox.toml`, or the test tasks.

---

### Task 1: Build post-action on every scheme

**Files:** Modify `Tuist/ProjectDescriptionHelpers/Module+Schemes.swift`

- [x] **Step 1: Add the helper**

Above the existing `private extension [String: EnvironmentVariable]` block:

```swift
private func inspectBuildPostAction(target: TargetReference) -> ExecutionAction {
    .executionAction(
        title: "Inspect build",
        scriptText: """
        if [ "${CI:-}" = "true" ]; then exit 0; fi

        "$HOME/.local/bin/mise" x -C "$SRCROOT" -- tuist inspect build || echo "warning: build insights upload failed"
        """,
        target: target
    )
}
```

`mise x -C` rather than `mise activate --shims`: a shim resolves the tool version from the working directory, which in a post-action is not the repository, and it aborts outright when a tool is installed twice. `|| echo` is load-bearing — without it a failed upload turns the build into `** BUILD FAILED **`.

- [x] **Step 2: Attach it to all five scheme definitions**

For each of the `.app`, `.appSnapshots`, `.shareExtension`, feature-modules and `.shareApp` cases, extend the build action:

```swift
                    buildAction: .buildAction(
                        targets: [.target(self)],
                        postActions: [inspectBuildPostAction(target: .target(self))],
                        runPostActionsOnFailure: true
                    ),
```

The Snapshots scheme builds the app rather than its own target, so it passes `.target(.app)` in both places.

- [x] **Step 3: Verify generation**

```bash
tuist generate --no-open
grep -rl "Inspect build" LessPaper.xcodeproj/xcshareddata/xcschemes/ | wc -l   # 31, all schemes
grep -c 'runPostActionsOnFailure = "YES"' "LessPaper.xcodeproj/xcshareddata/xcschemes/Less Paper.xcscheme"
```

- [x] **Step 4: Verify a real build and a real upload**

```bash
xcodebuild -workspace LessPaper.xcworkspace -scheme DesignTokens \
  -destination 'generic/platform=iOS Simulator' build          # ** BUILD SUCCEEDED **
TUIST_INSPECT_BUILD_WAIT=YES tuist inspect build               # prints the build-run URL
```

---

### Task 2: Bundle inspection in the ipa build

**Files:** Modify `mise/tasks/ci/build`

- [x] **Step 1: Inspect the ipa after the copy**

Append after `cp $TMP_DIR/LessPaper.ipa build/LessPaper.ipa`:

```bash
# Telemetry, not a gate: an unreachable Tuist server or an unauthenticated local run must not fail
# a build that has already produced the ipa. Build insights need nothing here - tuist xcodebuild
# archive uploads its own build run.
tuist inspect bundle build/LessPaper.ipa || echo "warning: bundle inspection failed"
```

No `-resultBundlePath` and no `tuist inspect build`: `tuist xcodebuild archive` supplies the former and performs the latter itself.

- [x] **Step 2: Verify**

```bash
bash -n mise/tasks/ci/build
```

---

## Final Verification

- [x] `mise run format` leaves the manifest unchanged.
- [x] `mise run ci:lint` reports no dependency issues.
- [ ] The next `ci:build` on main shows a bundle analysis on the dashboard, and exactly one build run for the archive.
