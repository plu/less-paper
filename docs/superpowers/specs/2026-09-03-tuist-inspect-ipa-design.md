# Tuist Inspect: Build and Bundle Insights

Report build insights from local Xcode builds and bundle-size insights from the ipa to the Tuist
server, without double-counting what the Tuist CLI already reports on its own.

## Context

`Tuist.swift` carries `fullHandle: "plu/less-paper"`, and CI runs under `fnox exec -P ci`, which
injects `TUIST_TOKEN`. Authentication and project attribution therefore need no changes.

What the CLI already does, read from the Tuist 4.205 sources rather than the docs:

- `tuist xcodebuild archive` routes through `XcodeBuildBuildCommandService`, which calls
  `uploadBuildRunIfNeeded` — so the CI archive in `mise/tasks/ci/build` **already** reports its
  build run. It also injects its own `-resultBundlePath` into the cache directory when the caller
  passes none, so adding one by hand is unnecessary too.
- `tuist test` calls `uploadResultBundleIfNeeded`, which uploads the test summary whenever
  `fullHandle` is set — so the CI test jobs **already** report test insights.

The docs' instruction to add `-resultBundlePath` and `tuist inspect build`/`inspect test`
post-actions is aimed at raw `xcodebuild` users. Applying it here would upload each CI build and
test run twice.

That leaves two genuine gaps:

1. **Local Xcode builds.** Cmd-B never goes through the Tuist CLI, so nothing reports it. This is
   the case the post-action exists for.
2. **The ipa.** Nothing analyses bundle size; `tuist inspect bundle` is the only path.

## Changes

### Build post-action on every scheme (`Tuist/ProjectDescriptionHelpers/Module+Schemes.swift`)

A file-private `inspectBuildPostAction(target:)` helper returning an `ExecutionAction`, attached to
the `buildAction` of every scheme the file defines (the app, Snapshots, ShareExtension, ShareApp
and each feature module), with `runPostActionsOnFailure: true` so failed builds are tracked too.
The scheme's own target supplies the build settings; the Snapshots scheme uses `.app`, which is
what it builds.

The script:

```sh
if [ "${CI:-}" = "true" ]; then exit 0; fi

"$HOME/.local/bin/mise" x -C "$SRCROOT" -- tuist inspect build || echo "warning: build insights upload failed"
```

Three decisions worth recording:

- **The CI guard** is what keeps this from double-counting: on CI the archive is already reported
  by `tuist xcodebuild`, and the post-action would otherwise add a second run for the same build.
  GitHub Actions sets `CI=true`, and it propagates through mise → tuist → xcodebuild to the script.
- **`mise x -C "$SRCROOT"`, not the shims.** A post-action shell has no usable PATH, and the
  documented `mise activate --shims` form fails here: a shim resolves the version from the working
  directory, which is not the repository, and this machine has tuist installed twice (the project's
  `aqua:tuist` 4.205.0 and a global 4.206.0), so the shim aborts with "No version is set for shim".
  `mise x -C` resolves against the repository's `mise.toml` and picks the pinned version.
  `SRCROOT` is the repository root for every target, since Tuist generates one project there.
- **`|| echo`** — without it a failed upload fails the whole build. This was not theoretical: the
  first attempt turned `xcodebuild ... build` into `** BUILD FAILED **`.

### Bundle inspection (`mise/tasks/ci/build`)

After the ipa is copied to `build/LessPaper.ipa`:

```sh
tuist inspect bundle build/LessPaper.ipa || echo "warning: bundle inspection failed"
```

Bundle analysis detects the git ref itself and uploads install and download sizes. Nothing else in
the task changes — no `-resultBundlePath`, no `tuist inspect build`, both of which
`tuist xcodebuild archive` already handles.

## Error handling

Every addition is non-fatal by construction: both invocations are guarded with `|| echo`, so an
unreachable server, an expired token or an unauthenticated local run prints a warning and lets the
build continue. Insights are telemetry; a gap in the dashboard is cheaper than a blocked build or
release. This matches the existing `optionalAuthentication: true` stance in `Tuist.swift`.

## Out of scope

**Test insights from local Cmd-U runs.** `tuist test` covers every CI test run already. A
`tuist inspect test` post-action would only add local runs, and would need the same CI guard to
avoid double-counting. Left out deliberately; it can be added later by mirroring the build helper.

## Verification

Performed while implementing, against Tuist 4.205.0 and Xcode 26.5:

- `tuist generate` succeeds and all 31 generated schemes carry the "Inspect build" post-action,
  with `runPostActionsOnFailure = "YES"`.
- `xcodebuild -workspace LessPaper.xcworkspace -scheme DesignTokens -destination
  'generic/platform=iOS Simulator' build` reports `** BUILD SUCCEEDED **`.
- `TUIST_INSPECT_BUILD_WAIT=YES tuist inspect build` after that build uploads successfully and
  returns a `tuist.dev/plu/less-paper/builds/build-runs/…` URL.
- `bash -n mise/tasks/ci/build` passes, and the `|| echo` guard returns exit 0 under
  `set -euo pipefail` when the inspected path does not exist.
- `mise run format` leaves the manifest unchanged and `mise run ci:lint` reports no dependency
  issues.

The bundle upload itself is first exercised by the next `ci:build` run on main, which is also when
the CI guard is first proven in place.
