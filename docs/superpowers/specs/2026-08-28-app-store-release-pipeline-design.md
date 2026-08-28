# App Store release pipeline

Submits a build that is already on TestFlight for App Store review, and records what was submitted
as a tagged GitHub release.

Nothing here builds or uploads a binary. `ci.yml` already does that on every push to `main`, and it
keeps doing it unchanged. This is the step that has been missing on the other end: choosing one of
the builds that pipeline produced and sending it to Apple.

## Context

Every push to `main` ships a build to TestFlight. `CURRENT_PROJECT_VERSION` comes from
`TUIST_GITHUB_RUN_NUMBER`, so the build number is the `ci.yml` run number, and `MARKETING_VERSION`
is the `marketingVersion` constant in `Tuist/ProjectDescriptionHelpers/Extensions/String+Extensions.swift`.
A tester looking at 3.0.1 (68) is looking at run 68 of `ci.yml`.

What exists today stops there. There is no way to promote one of those builds to the App Store, no
tag in the repository, and no GitHub release — `git tag` is empty. Submitting means clicking through
App Store Connect and then remembering, by hand, which commit that build came from. The second half
is the part that rots: a month later nothing in the repository records what 3.0.1 actually was.

The listing is already automated in pieces. `metadata:upload` sends the text, `ci:screenshots:upload`
sends the images, both through `deliver` with an App Store Connect API key from fnox. Both are
deliberately narrow — they skip the binary, skip each other, and skip the version — so that neither
can disturb anything it was not asked to touch. This design adds the third piece and reuses those
two rather than duplicating them.

## The shape of the problem

**A build number is not a version, and it is not a commit.** It identifies a `ci.yml` run, and the
run knows its own `head_sha`. That makes the lookup a primary-key read rather than a search, which
matters because the obvious alternative — "the most recent build" — is wrong the moment `main`
moves on, which it does constantly.

Two facts make the read less trivial than it sounds:

| Fact | Consequence |
|---|---|
| The run-number sequence is shared with pull-request runs | Most numbers never produced a build at all. Of runs 61–73, seven were pull requests. |
| Failed and cancelled runs consume numbers | Runs 50, 55, 56 and 57 are numbers with no artefact behind them. |
| `ci.yml` also uploads for pull requests labelled `TestFlight` | A build can legitimately come from a commit that is not on `main`. |

So resolving 68 means reading the run, and then proving the run shipped something: the `Upload` job
must have concluded `success`. Without that check, roughly half of all numbers resolve to a valid
sha and then fail much later, inside fastlane, with an error about a build Apple has never heard of.

**The marketing version must come from the commit, not from App Store Connect and not from `main`.**
`git show <sha>:Tuist/ProjectDescriptionHelpers/Extensions/String+Extensions.swift` reads the literal
string that was compiled into that IPA. Reading it from the working tree instead would pair build 68
with whatever version `main` has drifted to.

## Decisions

**Small tasks under `mise/tasks/release/`, wired together by the workflow.** The existing `ci/*` and
`metadata/*` namespaces are already built this way, but there is a stronger reason here: one step in
this pipeline cannot be undone. Submitting build 68 for review is not something to retry casually.
Keeping the steps separate puts a visible boundary between "everything checked, nothing touched" and
"submitted", and makes the recoverable step after it re-runnable on its own — so a failed tag is a
five-second re-run rather than a judgement call about whether the whole thing is safe to repeat.

**GitHub Actions is the entry point; the logic still lives in mise tasks.** `release.yml` is a
`workflow_dispatch` wrapper that calls tasks, the same shape as `metadata.yml`. The tasks are
runnable locally, and the read-only ones are worth running that way, but the normal path is the
Actions tab.

**The pipeline does not write to the source tree.** It creates a tag and a release, and nothing else.
In particular it does not bump `marketingVersion` — whether 3.0.1 is followed by 3.0.2 or 3.1.0 is a
judgement call, and a script that guesses it wrong writes to `main` from CI to do so.

The cost, recorded so it is a choice rather than a surprise: after 3.0.1 is submitted, every new
TestFlight build off `main` is still 3.0.1 and none of them can ever be submitted, because the
version is spoken for. Bumping the constant is a manual step, and forgetting it wastes a week of
builds. `release:tag` prints a reminder naming the version just submitted.

## Resolving a build

`release:resolve <build>` is read-only and does the whole lookup:

```
68
 ├─ gh run list --workflow=ci.yml --limit 200
 │     select .number == 68            → run 33188027923, sha 6285919, main, push
 │     no match                        → fail: no ci.yml run numbered 68
 │
 ├─ gh api runs/33188027923/jobs
 │     Upload job == success           → the run shipped a binary
 │     otherwise                       → fail: run 68 has no successful Upload job;
 │                                             build 68 does not exist in TestFlight
 │
 ├─ git merge-base --is-ancestor 6285919 origin/main
 │     otherwise                       → fail unless allow_off_main
 │
 └─ git show 6285919:…/String+Extensions.swift
       marketingVersion                → 3.0.1

sha=6285919  version=3.0.1  build=68  branch=main
```

It prints those as `key=value` lines on stdout, and appends them to `$GITHUB_OUTPUT` when that
variable is set. Later workflow steps read them through `steps.resolve.outputs.*`; locally,
`eval "$(mise run release:resolve 68)"` puts them in the shell.

A re-run of a workflow keeps both its `run_number` and its `head_sha`, so re-running run 68 still
resolves to `6285919`.

The `--limit 200` is a practical bound, not a correctness one. TestFlight builds expire after 90
days, so anything submittable is well inside it, and a number outside the window fails loudly rather
than resolving to something else.

The off-`main` check exists for the `TestFlight`-labelled pull request case. Such a build is real and
tagging it is defensible — the commit is exactly what shipped — but the branch it came from is
usually squashed and deleted, so it should take an explicit `allow_off_main` to do it by accident.

## Preflight

`release:preflight` is the last exit before anything writes. It is read-only and checks four things:

- the tag `v3.0.1+68` does not already exist, which is what makes submitting the same build twice
  impossible; submitting a *different* build of a version already in review is caught by Apple, not
  here
- `metadata:lint` passes, so text Apple would reject does not cost a round trip
- `release_notes.txt` is non-empty in every locale — the one listing field Apple requires per version
- the build exists in App Store Connect at version 3.0.1, build 68, with `processingState == VALID`

The last is the check `release:resolve` cannot make. A successful `Upload` job proves altool sent the
binary; it does not prove Apple finished processing it or accepted it. It is a new `verify_build`
lane using `Spaceship::ConnectAPI::Build`, filtered by app, pre-release version and build number.

## Submitting

Three writes, in an order that matters, because a version must exist before screenshots or a build
can attach to it:

| Step | Task | Change |
|---|---|---|
| Listing text, and create version 3.0.1 | `metadata:upload` | version awareness, below |
| Screenshots | `ci:screenshots:frame` then `ci:screenshots:upload` | none |
| Attach build 68 and submit | `release:submit` | new `submit_for_review` lane |

**`upload_metadata` learns an optional version.** It sets `skip_app_version_update: true` today,
which is correct for a text-only edit and wrong for a release: the 3.0.1 version has to be created in
App Store Connect for anything to attach to it. With the new environment variable unset the lane
behaves exactly as it does now; set, it passes `app_version` and flips `skip_app_version_update` to
false. `mise run metadata:upload` on its own is unaffected. A new lane would be the alternative, and
would duplicate every other option in `metadata_options` to change one of them.

**`upload_screenshots` is untouched.** It attaches to whichever version is editable, which is 3.0.1
by the time it runs. Framing is cheap — it reads the committed captures and writes finished images in
seconds — but it needs `tuist generate` and a simulator, so it is the slowest step in the pipeline
and the one worth skipping when nothing about the images has changed. `release.yml` takes a
`skip_screenshots` input for that.

**`submit_for_review` carries only the submission.** `skip_binary_upload`, `skip_metadata` and
`skip_screenshots` are all true — those have already happened — leaving `app_version`, `build_number`,
`submit_for_review: true`, `automatic_release: false` and `phased_release: true`.

Those last two are the rollout decision: Apple approves the build and then waits, the version sits in
Pending Developer Release until someone presses Release in App Store Connect, and it then rolls out
over seven days. An approval landing at 3am does not put itself in front of users.

Unlike the existing lanes this one runs `precheck` before submitting. The existing lanes skip it
because they are editing text and a failed precheck would block a routine copy change; here the round
trip it saves is a day of review.

Export compliance needs no answer at submission time: `ITSAppUsesNonExemptEncryption` is `false` in
`Module+InfoPlists.swift`, so Apple has it from the binary.

## Tagging

`release:tag` creates `v3.0.1+68` on `6285919` with `gh release create --target`. GitHub creates the
tag server-side from the sha, so nothing needs `git push` and the credential-helper problem does not
arise.

The build number is in the tag rather than only in the title so that a second submission of the same
marketing version — a rejection, resubmitted — gets its own tag instead of colliding. The cost is a
tag that does not sort as semver, which is why the previous tag is found by
`git tag --sort=-creatordate` rather than by version order.

Release title is `3.0.1 (68)`. The body is the English `release_notes.txt` — what users read on the
App Store — followed by `## Changes` from `git log --pretty='* %s (%h)' <previous tag>..<sha>`, so the
release is both the user-facing note and the developer-facing changelog. The first release has no
predecessor and falls back to `--generate-notes`.

One inconsistency is accepted here. The listing is uploaded from the workflow's checkout of `main`,
while the tag points at the build's commit, so release notes edited after build 68 was cut are sent
to Apple but are not what `6285919` contains. Uploading the notes from the build's commit instead
would mean the notes could never be written after the build, which is backwards — notes are written
when a release is decided on, not when a commit lands.

## The workflow

```yaml
workflow_dispatch:
  inputs: build, dry_run, allow_off_main, skip_screenshots
concurrency: { group: release, cancel-in-progress: false }
permissions: { contents: write }
```

`cancel-in-progress: false` for the same reason `ci.yml` gives for its upload job: killing this
halfway is worse than waiting.

Checkout needs `fetch-depth: 0` — `git show` of an older commit, the tag list and the commit range
all need history — and `lfs: true`, because framing reads the captures.

`dry_run` runs resolve and preflight and then prints what each remaining step would do without
calling Apple or GitHub. It is the only way to exercise the pipeline end to end without submitting
something, so it is worth having even though it cannot prove the writes work.

## Testing

`release:resolve` and `release:preflight` are the parts with logic worth testing, and both are
read-only, so they can be run against real data as often as needed. The resolve cases that matter are
a good main build, a pull-request number, a failed run, a number that does not exist, and an
off-`main` `TestFlight` build.

The writing half cannot be proven without submitting to Apple, and no amount of test scaffolding
changes that. The mitigation is that every irreversible thing it does is gated behind checks that are
themselves testable, and that `dry_run` exercises the path around them.

## Not in scope

- Bumping `marketingVersion`, for the reason given above.
- Anything after submission. Review outcome, pressing Release, and pausing a phased rollout are all
  App Store Connect's job; polling Apple for a verdict would be a second pipeline with a different
  trigger.
- Changing how builds reach TestFlight. `ci.yml` is untouched.
