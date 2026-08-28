# App Store Release Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Submit a build that is already on TestFlight for App Store review, and record what was submitted as a tagged GitHub release.

**Architecture:** Four new bash tasks under `mise/tasks/release/`, wired together by a `workflow_dispatch` workflow that also calls three tasks that already exist. `release:resolve` turns a build number into a commit and a version by reading the `ci.yml` run that produced it; `release:preflight` makes every read-only check that can fail; `release:submit` and `release:tag` are the two steps that write. The irreversible step is second to last, and the step after it is re-runnable on its own.

**Tech Stack:** bash, `gh` CLI, GitHub Actions (self-hosted macOS runner), fastlane `deliver` and `Spaceship::ConnectAPI`, fnox for secrets, mise for task running.

**Spec:** [2026-08-28-app-store-release-pipeline-design.md](../specs/2026-08-28-app-store-release-pipeline-design.md)

## Global Constraints

- **Comments:** Only `//` in Swift. This plan touches no Swift. In bash and Ruby, `#`. Comment only when a future reader would otherwise stop and wonder why — the existing tasks in `mise/tasks/` are the standard to match, and they explain constraints and traps, never what the line already says. (`AGENTS.md`)
- **Never bump `marketingVersion`.** The pipeline does not write to the source tree. `release:tag` prints a reminder; a human does the edit.
- **`mise exec -- fnox get NAME` is how secrets are read.** Plain `fnox` is not on `PATH` in a non-interactive shell. `mise/tasks/metadata/upload` is the pattern to copy.
- **A missing secret is not an error to fnox:** `fnox get` exits 0 and prints nothing. Judge presence on the value being non-empty, never on the exit code. (`mise/tasks/metadata/review-info` explains this at length.)
- **Every task starts `#!/usr/bin/env bash`, then `#MISE description=`, then `set -euo pipefail`.** Arguments are declared with `#USAGE arg "<name>"` and read as `$usage_name` — see `mise/tasks/rename`.
- **Do not use standalone `jq`.** It is not pinned in `mise.toml`. Use `gh`'s built-in `--jq` and have it emit `@tsv`.
- **Do not use `git push`.** The PAT in use needs a credential helper for pushes; `gh release create --target <sha>` creates the tag server-side and avoids the problem entirely.
- **The App Store Connect key lives in fnox as `ALTOOL_KEY_ID`, `ALTOOL_ISSUER_ID`, `ALTOOL_AUTH_KEY`** and is passed to fastlane as `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_AUTH_KEY`. `connect_api_key` in the Fastfile already reads those.
- **App identifier:** `com.aptumtek.app.Paperless`. Team: `HZ7YVCSB89`.
- **The version constant is at** `Tuist/ProjectDescriptionHelpers/Extensions/String+Extensions.swift`, as `static let marketingVersion = "3.0.1"`.

## A note on testing

This repository has no bash test harness, and adding one for four tasks that are almost entirely
`gh` and `git` calls would test the mocks rather than the code. The two tasks with real logic —
`resolve` and `preflight` — are read-only, so they are verified by running them against live data
with known answers. Those answers are recorded below and were confirmed against the repository on
2026-08-28:

| Build | Run id | Result | Why |
|---|---|---|---|
| 68 | 33188027923 | resolves: `6285919`, `main`, `3.0.1` | push to main, `Upload=success` |
| 57 | 33079748249 | fails: no successful Upload job | push to main, UI tests failed, `Upload=skipped` |
| 69 | 33188662279 | fails: no successful Upload job | pull request, `Upload=skipped` |
| 999999 | — | fails: no run numbered 999999 | never existed |

New runs happen constantly, so if build 68 has aged out of `--limit 200` by the time this is
implemented, pick the newest `push`/`main` run whose `Upload` job succeeded and use it instead —
`gh run list --workflow=ci.yml --limit 20 --json number,headSha,headBranch,event` shows candidates.

The writing half cannot be proven without submitting to Apple. `RELEASE_DRY_RUN=true` exercises the
path up to each write and prints what would have happened; that is the honest limit of what can be
verified before a real submission.

---

## File Structure

**Created:**

| File | Responsibility |
|---|---|
| `mise/tasks/release/resolve` | Build number → commit sha, branch, marketing version, tag name. Read-only. |
| `mise/tasks/release/preflight` | Every check that must pass before anything writes. Read-only. |
| `mise/tasks/release/submit` | Attach the build to its version and submit for review. Irreversible. |
| `mise/tasks/release/tag` | Create the tag and the GitHub release on the build's commit. |
| `.github/workflows/release.yml` | `workflow_dispatch` entry point wiring the steps together. |

**Modified:**

| File | Change |
|---|---|
| `fastlane/Fastfile` | `metadata_options` learns an optional `ASC_APP_VERSION`; two new lanes, `verify_testflight_build` and `submit_for_review`. |

**Unchanged, but called by the pipeline:** `mise/tasks/metadata/upload`, `mise/tasks/metadata/lint`, `mise/tasks/ci/screenshots/frame`, `mise/tasks/ci/screenshots/upload`, `.github/workflows/ci.yml`.

---

### Task 1: `release:resolve`

Turns a build number into everything else the pipeline needs. Every later task calls it rather than
taking the values as arguments, so each one is independently runnable and re-runnable.

**Files:**
- Create: `mise/tasks/release/resolve`

**Interfaces:**
- Consumes: nothing.
- Produces: `key=value` lines on stdout, and the same lines appended to `$GITHUB_OUTPUT` when that
  variable is set. Exactly these five keys, in this order: `build`, `sha`, `branch`, `version`,
  `tag`. Callers use `eval "$(mise run release:resolve "$n")"` to get `$build`, `$sha`, `$branch`,
  `$version`, `$tag` as shell variables. Reads `RELEASE_ALLOW_OFF_MAIN`.

- [ ] **Step 1: Verify the task does not exist yet**

```bash
mise run release:resolve 68
```

Expected: failure — mise reports no such task.

- [ ] **Step 2: Write the task**

Create `mise/tasks/release/resolve`:

```bash
#!/usr/bin/env bash
#MISE description="Resolve a TestFlight build number to the commit and version behind it"
#USAGE arg "<build>" help="The TestFlight build number, which is the ci.yml run number"
set -euo pipefail

# The build number is github.run_number: ci.yml passes it as TUIST_GITHUB_RUN_NUMBER, Tuist reads
# it into CURRENT_PROJECT_VERSION, so build 68 is run 68 of ci.yml and nothing else. Newer runs are
# unrelated rows, which is why nothing here looks at "latest".
build="$usage_build"

# The run-number sequence is shared with pull request runs, and failed runs consume numbers too, so
# most numbers have no build behind them. 200 is far more than Apple's 90-day build expiry needs; a
# number outside the window fails here rather than resolving to something else.
row="$(gh run list --workflow=ci.yml --limit 200 \
  --json number,databaseId,headSha,headBranch \
  --jq "[.[] | select(.number == $build)][0] | select(. != null) | [.databaseId, .headSha, .headBranch] | @tsv")"

if [ -z "$row" ]; then
  echo "error: no ci.yml run numbered $build" >&2
  exit 1
fi

IFS=$'\t' read -r run_id sha branch <<<"$row"

# A run number is not a build. ci.yml uploads only from main and from pull requests labelled
# TestFlight, and a run whose UI tests failed skips the job entirely - so the Upload job's
# conclusion is the only thing separating "a number GitHub handed out" from "a build Apple has".
# Without this check most numbers resolve to a valid sha and fail much later inside fastlane.
upload="$(gh api "repos/{owner}/{repo}/actions/runs/$run_id/jobs" \
  --jq '[.jobs[] | select(.name == "Upload") | .conclusion // "unfinished"][0]')"

if [ "$upload" != "success" ]; then
  echo "error: run $build has no successful Upload job (Upload=${upload:-absent})" >&2
  echo "       build $build does not exist in TestFlight" >&2
  exit 1
fi

if ! git rev-parse --verify --quiet origin/main >/dev/null; then
  echo "error: no origin/main - run 'git fetch origin main' first" >&2
  exit 1
fi

if ! git merge-base --is-ancestor "$sha" origin/main; then
  # A TestFlight-labelled pull request build. It is real and tagging it is defensible, but the
  # branch is usually squashed and deleted afterwards, so it should not happen by accident.
  if [ "${RELEASE_ALLOW_OFF_MAIN:-}" != "true" ]; then
    echo "error: $sha is not on origin/main (branch $branch)" >&2
    echo "       set RELEASE_ALLOW_OFF_MAIN=true to tag it anyway" >&2
    exit 1
  fi
  echo "warning: $sha is not on origin/main (branch $branch)" >&2
fi

# Read from the commit, never from the working tree: main has usually moved on, and pairing build 68
# with a version it was not compiled with is the single mistake this task exists to prevent.
version="$(git show "$sha:Tuist/ProjectDescriptionHelpers/Extensions/String+Extensions.swift" \
  | sed -n 's/.*marketingVersion = "\(.*\)".*/\1/p')"

if [ -z "$version" ]; then
  echo "error: no marketingVersion in String+Extensions.swift at $sha" >&2
  exit 1
fi

emit() {
  echo "$1=$2"
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "$1=$2" >> "$GITHUB_OUTPUT"
  fi
}

emit build "$build"
emit sha "$sha"
emit branch "$branch"
emit version "$version"
emit tag "v$version+$build"
```

- [ ] **Step 3: Make it executable**

```bash
chmod +x mise/tasks/release/resolve
```

- [ ] **Step 4: Verify the good case**

```bash
mise run release:resolve 68
```

Expected, exactly:

```
build=68
sha=62859198d163720b0e0cc4e320f0752b43d1b78d
branch=main
version=3.0.1
tag=v3.0.1+68
```

- [ ] **Step 5: Verify the three failure cases**

```bash
mise run release:resolve 57      # main, UI tests failed
mise run release:resolve 69      # pull request
mise run release:resolve 999999  # no such run
```

Expected: all three exit non-zero. 57 and 69 report `has no successful Upload job (Upload=skipped)`;
999999 reports `no ci.yml run numbered 999999`.

- [ ] **Step 6: Verify the values survive `eval`**

```bash
eval "$(mise run release:resolve 68)" && echo "$tag on $sha is $version"
```

Expected: `v3.0.1+68 on 62859198d163720b0e0cc4e320f0752b43d1b78d is 3.0.1`

- [ ] **Step 7: Commit**

```bash
git add mise/tasks/release/resolve
git commit -m "feat: resolve a TestFlight build number to its commit"
```

---

### Task 2: `verify_testflight_build` lane and `release:preflight`

The last exit before anything writes. Four checks, all read-only. The App Store Connect one needs a
fastlane lane because it is the only part that talks to Apple.

**Files:**
- Modify: `fastlane/Fastfile` — add one lane after `upload_screenshots`
- Create: `mise/tasks/release/preflight`

**Interfaces:**
- Consumes: `release:resolve`, for `$build`, `$sha`, `$version`, `$tag`.
- Produces: exit status only. The `verify_testflight_build` lane reads `ASC_APP_VERSION` and `ASC_BUILD_NUMBER`
  from the environment and raises via `UI.user_error!` on any failure.

- [ ] **Step 1: Verify the task does not exist yet**

```bash
mise run release:preflight 68
```

Expected: failure — mise reports no such task.

- [ ] **Step 2: Add the `verify_testflight_build` lane**

In `fastlane/Fastfile`, inside `platform :ios do`, after the `upload_screenshots` lane:

```ruby
  # A successful Upload job in ci.yml proves altool sent the binary. It does not prove Apple
  # finished processing it, or accepted it - and deliver's own error for a build it cannot find
  # names neither the version nor the build number, so it is worth failing here instead.
  desc "Fail unless the given build is on App Store Connect and finished processing"
  lane :verify_testflight_build do
    connect_api_key

    version = ENV.fetch("ASC_APP_VERSION")
    number = ENV.fetch("ASC_BUILD_NUMBER")

    app = Spaceship::ConnectAPI::App.find(APP_IDENTIFIER)
    UI.user_error!("no app #{APP_IDENTIFIER} on App Store Connect") if app.nil?

    build = Spaceship::ConnectAPI::Build.all(
      app_id: app.id,
      version: version,
      build_number: number
    ).first

    UI.user_error!("no build #{version} (#{number}) on App Store Connect") if build.nil?

    unless build.processing_state == "VALID"
      UI.user_error!("build #{version} (#{number}) is #{build.processing_state}, not VALID")
    end

    UI.success("build #{version} (#{number}) is VALID")
  end
```

If `Build.all` rejects that keyword combination on the pinned fastlane version, filter client-side
instead — same behaviour, one more round trip:

```ruby
    build = Spaceship::ConnectAPI::Build.all(app_id: app.id, version: version)
                                        .find { |b| b.version == number }
```

Note the naming trap: in `Spaceship::ConnectAPI::Build`, `version` is the build number
(`CFBundleVersion`) and the marketing version lives on the associated pre-release version. The
`Build.all(version:)` *filter* takes the marketing version. That is why the fallback compares
`b.version` against `number`.

- [ ] **Step 3: Write the preflight task**

Create `mise/tasks/release/preflight`:

```bash
#!/usr/bin/env bash
#MISE description="Check everything that must be true before a build is submitted for review"
#USAGE arg "<build>" help="The TestFlight build number, which is the ci.yml run number"
set -euo pipefail

cd "$MISE_PROJECT_ROOT"

eval "$(mise run release:resolve "$usage_build")"

echo "Preflight for $version ($build) at $sha"

# Tags carry the build number, so this is what makes submitting the same build twice impossible.
# Submitting a different build of a version already in review is caught by Apple, not here.
if gh release list --limit 200 --json tagName --jq '.[].tagName' | grep -Fxq "$tag"; then
  echo "error: $tag already exists - build $build has been released" >&2
  exit 1
fi

# Text Apple would reject costs a round trip through review, so check the published limits first.
mise run metadata:lint

# The one listing field Apple requires for every new version. deliver would upload an empty file
# without complaint and let the review board find it.
for dir in fastlane/metadata/*/; do
  name="$(basename "$dir")"
  [ "$name" = "review_information" ] && continue

  notes="$dir/release_notes.txt"
  if [ ! -f "$notes" ] || [ -z "$(tr -d '[:space:]' < "$notes")" ]; then
    echo "error: $notes is empty - Apple requires What's New for every version" >&2
    exit 1
  fi
done

bundle config set --local path vendor/bundle
bundle check >/dev/null 2>&1 || bundle install

ASC_KEY_ID="$(mise exec -- fnox get ALTOOL_KEY_ID)" \
ASC_ISSUER_ID="$(mise exec -- fnox get ALTOOL_ISSUER_ID)" \
ASC_AUTH_KEY="$(mise exec -- fnox get ALTOOL_AUTH_KEY)" \
ASC_APP_VERSION="$version" \
ASC_BUILD_NUMBER="$build" \
  bundle exec fastlane verify_testflight_build

echo "Preflight passed: $version ($build) is ready to submit as $tag"
```

- [ ] **Step 4: Make it executable**

```bash
chmod +x mise/tasks/release/preflight
```

- [ ] **Step 5: Verify against the real build**

```bash
mise run release:preflight 68
```

Expected: prints `Preflight for 3.0.1 (68) at 6285919…`, the lint output, then either
`Preflight passed: 3.0.1 (68) is ready to submit as v3.0.1+68`, or a clear failure naming which
check failed. A failure from `verify_testflight_build` is a real answer, not a bug — it means that build is not
`VALID` on App Store Connect.

- [ ] **Step 6: Verify the release-notes check catches an empty file**

```bash
cp fastlane/metadata/en-US/release_notes.txt /tmp/notes.bak
: > fastlane/metadata/en-US/release_notes.txt
mise run release:preflight 68
cp /tmp/notes.bak fastlane/metadata/en-US/release_notes.txt
```

Expected: exits non-zero with `error: fastlane/metadata/en-US/release_notes.txt is empty`, and the
final `cp` restores the file. Confirm `git status --short` is clean afterwards.

- [ ] **Step 7: Commit**

```bash
git add fastlane/Fastfile mise/tasks/release/preflight
git commit -m "feat: preflight a release before anything is submitted"
```

---

### Task 3: Version-aware metadata and `release:submit`

The irreversible step. Also the one change to an existing lane: the 3.0.1 version must exist in App
Store Connect before screenshots or a build can attach to it.

**Files:**
- Modify: `fastlane/Fastfile` — `metadata_options`, plus a `submit_for_review` lane
- Create: `mise/tasks/release/submit`

**Interfaces:**
- Consumes: `release:resolve`, for `$build` and `$version`.
- Produces: nothing on stdout that other tasks read. Reads `RELEASE_DRY_RUN`. The
  `submit_for_review` lane reads `ASC_APP_VERSION` and `ASC_BUILD_NUMBER`. `metadata_options` now
  reads an optional `ASC_APP_VERSION`.

- [ ] **Step 1: Verify today's behaviour is preserved by construction**

Read `fastlane/Fastfile`'s `metadata_options` and confirm it currently hardcodes
`skip_app_version_update: true`. The change below must leave that exact behaviour when
`ASC_APP_VERSION` is unset, because `mise run metadata:upload` is used on its own for routine copy
edits and must not start moving versions around.

- [ ] **Step 2: Make `metadata_options` version-aware**

Replace the body of `metadata_options` in `fastlane/Fastfile`:

```ruby
def metadata_options
  options = {
    app_identifier: APP_IDENTIFIER,
    # deliver removes phased release when this is not set, and it logs "Removing phased release"
    # rather than asking. A text-only upload has no business changing how a version rolls out.
    phased_release: true,
    # Skips the HTML preview, which otherwise waits for a keypress nobody is there to give.
    force: true,
    metadata_path: METADATA,
    run_precheck_before_submit: false,
    skip_app_version_update: true,
    skip_binary_upload: true,
    skip_metadata: false,
    # Screenshots have their own lane, and leaving them to it means neither can disturb the other.
    skip_screenshots: true
  }

  # Set only by the release pipeline. The version has to exist in App Store Connect before
  # screenshots or a build can attach to it; every other caller leaves the editable version alone.
  version = ENV["ASC_APP_VERSION"]
  return options if version.nil? || version.empty?

  options.merge(app_version: version, skip_app_version_update: false)
end
```

- [ ] **Step 3: Add the `submit_for_review` lane**

In `fastlane/Fastfile`, inside `platform :ios do`, after `verify_testflight_build`:

```ruby
  # The binary is already on TestFlight and the listing has already been uploaded, so everything
  # here is skipped except the submission itself.
  desc "Attach an existing TestFlight build to its version and submit it for review"
  lane :submit_for_review do
    connect_api_key

    deliver(
      app_identifier: APP_IDENTIFIER,
      app_version: ENV.fetch("ASC_APP_VERSION"),
      build_number: ENV.fetch("ASC_BUILD_NUMBER"),
      # Apple approves and then waits: the version sits in Pending Developer Release until someone
      # presses Release, and only then rolls out over seven days. An approval landing at 3am does
      # not put itself in front of users.
      automatic_release: false,
      phased_release: true,
      force: true,
      # Unlike the text-only lanes, which skip it: a failed precheck here saves a day of review,
      # where there it would block a routine copy change.
      run_precheck_before_submit: true,
      precheck_include_in_app_purchases: false,
      skip_app_version_update: false,
      skip_binary_upload: true,
      skip_metadata: true,
      skip_screenshots: true,
      # Without this deliver asks about IDFA on stdin and a CI run hangs until it times out.
      # Export compliance needs no answer: ITSAppUsesNonExemptEncryption is false in the plist.
      submission_information: { add_id_info_uses_idfa: false },
      submit_for_review: true
    )
  end
```

- [ ] **Step 4: Write the submit task**

Create `mise/tasks/release/submit`:

```bash
#!/usr/bin/env bash
#MISE description="Submit an existing TestFlight build for App Store review"
#USAGE arg "<build>" help="The TestFlight build number, which is the ci.yml run number"
set -euo pipefail

# The one step in the pipeline that cannot be undone. Everything checkable has been checked by
# release:preflight; everything after this is re-runnable on its own.
cd "$MISE_PROJECT_ROOT"

eval "$(mise run release:resolve "$usage_build")"

if [ "${RELEASE_DRY_RUN:-}" = "true" ]; then
  echo "dry run: would submit $version ($build) for review,"
  echo "         to be released manually and then rolled out over seven days"
  exit 0
fi

bundle config set --local path vendor/bundle
bundle check >/dev/null 2>&1 || bundle install

ASC_KEY_ID="$(mise exec -- fnox get ALTOOL_KEY_ID)" \
ASC_ISSUER_ID="$(mise exec -- fnox get ALTOOL_ISSUER_ID)" \
ASC_AUTH_KEY="$(mise exec -- fnox get ALTOOL_AUTH_KEY)" \
ASC_APP_VERSION="$version" \
ASC_BUILD_NUMBER="$build" \
  bundle exec fastlane submit_for_review
```

- [ ] **Step 5: Make it executable**

```bash
chmod +x mise/tasks/release/submit
```

- [ ] **Step 6: Verify the dry run, and that it stops before Apple**

```bash
RELEASE_DRY_RUN=true mise run release:submit 68
```

Expected, exactly:

```
build=68
sha=62859198d163720b0e0cc4e320f0752b43d1b78d
branch=main
version=3.0.1
tag=v3.0.1+68
dry run: would submit 3.0.1 (68) for review,
         to be released manually and then rolled out over seven days
```

Do **not** run it without `RELEASE_DRY_RUN`. That submits to Apple.

- [ ] **Step 7: Verify the metadata lane still behaves as before**

```bash
bundle exec fastlane lanes
```

Expected: `verify_testflight_build`, `submit_for_review` and the three original lanes are listed. Confirm by
reading `metadata_options` that with `ASC_APP_VERSION` unset it returns a hash with
`skip_app_version_update: true` and no `app_version` key.

- [ ] **Step 8: Commit**

```bash
git add fastlane/Fastfile mise/tasks/release/submit
git commit -m "feat: submit an existing TestFlight build for review"
```

---

### Task 4: `release:tag`

**Files:**
- Create: `mise/tasks/release/tag`

**Interfaces:**
- Consumes: `release:resolve`, for `$build`, `$sha`, `$version`, `$tag`.
- Produces: a GitHub release. Reads `RELEASE_DRY_RUN`.

- [ ] **Step 1: Verify the task does not exist yet**

```bash
RELEASE_DRY_RUN=true mise run release:tag 68
```

Expected: failure — mise reports no such task.

- [ ] **Step 2: Write the task**

Create `mise/tasks/release/tag`:

```bash
#!/usr/bin/env bash
#MISE description="Tag the commit a submitted build came from and publish a GitHub release"
#USAGE arg "<build>" help="The TestFlight build number, which is the ci.yml run number"
set -euo pipefail

cd "$MISE_PROJECT_ROOT"

eval "$(mise run release:resolve "$usage_build")"

notes="$(mktemp)"
trap 'rm -f "$notes"' EXIT

# What users read on the App Store, then what actually changed in the code: the release is both the
# user-facing note and the developer-facing changelog.
cat fastlane/metadata/en-US/release_notes.txt > "$notes"

# Tags carry the build number, so they do not sort as versions. Creation order is the only order
# that means anything here.
previous="$(git tag --sort=-creatordate | head -1)"

args=(--target "$sha" --title "$version ($build)" --notes-file "$notes")

if [ -n "$previous" ]; then
  {
    echo
    echo "## Changes"
    echo
    git log --pretty='* %s (%h)' "$previous..$sha"
  } >> "$notes"
else
  # The first release has no predecessor to diff against. gh appends its generated notes to the
  # ones given here.
  args+=(--generate-notes)
fi

if [ "${RELEASE_DRY_RUN:-}" = "true" ]; then
  echo "dry run: would create release $tag on $sha titled \"$version ($build)\""
  echo "---"
  cat "$notes"
  echo "---"
  exit 0
fi

# --target creates the tag server-side from the sha, so nothing here needs a git push - which
# matters, because pushing over HTTPS here prompts for a username and hangs.
gh release create "$tag" "${args[@]}"

echo
echo "Submitted $version. Nothing bumps marketingVersion automatically:"
echo "edit Tuist/ProjectDescriptionHelpers/Extensions/String+Extensions.swift before the next"
echo "build, or every new TestFlight build stays on a version that can never be submitted."
```

- [ ] **Step 3: Make it executable**

```bash
chmod +x mise/tasks/release/tag
```

- [ ] **Step 4: Verify the dry run**

```bash
RELEASE_DRY_RUN=true mise run release:tag 68
```

Expected: the five `key=value` lines, then
`dry run: would create release v3.0.1+68 on 6285919… titled "3.0.1 (68)"`, then the contents of
`fastlane/metadata/en-US/release_notes.txt` between `---` markers. There are no tags in the
repository yet, so no `## Changes` section appears and `--generate-notes` is what would be passed.

- [ ] **Step 5: Verify the changelog branch of the code**

```bash
git tag test-previous-tag 8e0947d
RELEASE_DRY_RUN=true mise run release:tag 68
git tag -d test-previous-tag
```

Expected: the dry-run output now ends with a `## Changes` section listing the commits between
`8e0947d` and `6285919` as `* subject (sha)` lines. Confirm the tag is gone afterwards with
`git tag`, which should print nothing.

- [ ] **Step 6: Commit**

```bash
git add mise/tasks/release/tag
git commit -m "feat: tag and release the commit behind a submitted build"
```

---

### Task 5: The workflow

**Files:**
- Create: `.github/workflows/release.yml`

**Interfaces:**
- Consumes: all four `release:*` tasks, plus `metadata:upload`, `ci:screenshots:frame` and
  `ci:screenshots:upload`.
- Produces: nothing other tasks read.

- [ ] **Step 1: Write the workflow**

Create `.github/workflows/release.yml`:

```yaml
name: Release

# Promotes a build that is already on TestFlight to the App Store. It builds and uploads nothing:
# ci.yml does that on every push to main, and this picks one of the builds it produced.
on:
  workflow_dispatch:
    inputs:
      build:
        description: The TestFlight build number to submit (the ci.yml run number)
        type: string
        required: true
      dry_run:
        description: Run every check and print what would happen, touching neither Apple nor GitHub
        type: boolean
        default: false
      skip_screenshots:
        description: Leave the screenshots on the listing alone
        type: boolean
        default: false
      allow_off_main:
        description: Allow a build from a TestFlight-labelled pull request
        type: boolean
        default: false

# One release at a time, and never cancelled. Same reasoning as ci.yml's upload job: killing a
# submission halfway is worse than waiting.
concurrency:
  group: release
  cancel-in-progress: false

permissions:
  contents: write

defaults:
  run:
    shell: /bin/bash --noprofile --norc -euo pipefail {0}

env:
  GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  RELEASE_ALLOW_OFF_MAIN: ${{ inputs.allow_off_main }}
  RELEASE_DRY_RUN: ${{ inputs.dry_run }}

jobs:
  release:
    name: Release
    runs-on: [self-hosted, macOS]
    timeout-minutes: 90

    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          clean: false
          # git show of an older commit, the tag list and the commit range all need real history.
          fetch-depth: 0
          # Framing reads the committed captures.
          lfs: true

      - name: mise
        uses: jdx/mise-action@v3
        with:
          cache: false
          cache_save: false

      - name: Resolve the build
        id: resolve
        run: mise run release:resolve ${{ inputs.build }}

      # The last step that touches nothing. Everything below writes.
      - name: Preflight
        run: mise run release:preflight ${{ inputs.build }}

      - name: Upload the listing text and create the version
        if: inputs.dry_run != true
        run: mise run metadata:upload
        env:
          ASC_APP_VERSION: ${{ steps.resolve.outputs.version }}

      - name: Frame the screenshots
        if: inputs.dry_run != true && inputs.skip_screenshots != true
        run: mise run ci:screenshots:frame

      - name: Upload the screenshots
        if: inputs.dry_run != true && inputs.skip_screenshots != true
        run: mise run ci:screenshots:upload

      - name: Submit for review
        run: mise run release:submit ${{ inputs.build }}

      - name: Tag and release
        run: mise run release:tag ${{ inputs.build }}

      - name: Summary
        if: always()
        run: |
          {
            echo "## Release"
            echo
            echo "| | |"
            echo "|---|---|"
            echo "| Build | ${{ inputs.build }} |"
            echo "| Version | ${{ steps.resolve.outputs.version }} |"
            echo "| Commit | ${{ steps.resolve.outputs.sha }} |"
            echo "| Branch | ${{ steps.resolve.outputs.branch }} |"
            echo "| Tag | ${{ steps.resolve.outputs.tag }} |"
            echo "| Dry run | ${{ inputs.dry_run }} |"
          } >> "$GITHUB_STEP_SUMMARY"
```

- [ ] **Step 2: Check the YAML parses**

```bash
python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/release.yml')); print('ok')"
```

Expected: `ok`

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "feat: add the release workflow"
```

Note for whoever pushes: the fine-grained PAT in use has no `workflow` scope, so pushing this file
will 403. Either re-mint the token with workflow permission, or add this one file through the web
UI.

---

### Task 6: Document the pipeline

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: nothing.
- Produces: nothing.

- [ ] **Step 1: Find where the release story belongs**

```bash
grep -n -i "testflight\|mise\|Tooling is pinned" README.md
```

The README already explains that a public beta is on TestFlight and that tooling is pinned with
mise. The release pipeline belongs alongside whatever section covers CI and distribution.

- [ ] **Step 2: Add a short section**

Add to `README.md`, in the development/CI area found in Step 1:

````markdown
### Releasing

Every push to `main` ships a build to TestFlight, numbered with the CI run number — a tester on
3.0.1 (68) is looking at run 68 of `ci.yml`.

Promoting one of those builds to the App Store is the Release workflow, which takes that number and
nothing else:

```sh
gh workflow run release.yml -f build=68
```

It resolves the number to the commit and version that produced it, checks the build is `VALID` on
App Store Connect, uploads the listing, submits for review, and tags the commit as `v3.0.1+68` with
a GitHub release. Pass `-f dry_run=true` to see all of that without doing any of it.

Apple holds the approved version in Pending Developer Release until you press Release, and it then
rolls out over seven days.

Nothing bumps `marketingVersion` in
`Tuist/ProjectDescriptionHelpers/Extensions/String+Extensions.swift` — do that by hand after a
submission, or every subsequent TestFlight build carries a version that can never be submitted.
````

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: describe the release pipeline"
```

---

## Done

Five files created, one modified, six commits. The pipeline is exercised end to end with
`gh workflow run release.yml -f build=<n> -f dry_run=true`, which is the furthest it can be verified
without submitting something to Apple.
