# Re-running CI When a Gating Label Is Added

Make adding the `TestFlight` or `UITests` label to an open pull request start a CI run, so the jobs
those labels gate actually happen without needing a new push.

## Context

`ci.yml` already gates its two expensive jobs on labels: `test_ui` runs when the pull request
carries `TestFlight` or `UITests`, and `upload` when it carries `TestFlight`. Both conditions read
`github.event.pull_request.labels.*.name`.

The conditions work, but they are only ever evaluated when the workflow is triggered, and
`on: pull_request` triggers on `opened`, `synchronize` and `reopened` by default — `labeled` is not
among them. Labelling an existing pull request therefore changes nothing: no event reaches the
workflow, so no run re-reads the labels. The only way to act on a label today is to push a commit.

## Changes

Both in `.github/workflows/ci.yml`.

### Trigger on `labeled`

```yaml
  pull_request:
    branches:
      - main
    types: [opened, synchronize, reopened, labeled]
```

Naming any type replaces the default list, so the three defaults are respelled alongside the
addition.

### Guard `test_unit`

```yaml
    if: github.event.action != 'labeled' || github.event.label.name == 'TestFlight' || github.event.label.name == 'UITests'
```

Every label now reaches the workflow, so unrelated labels have to be filtered out; on a single
self-hosted runner an accidental full run is expensive.

One guard covers all three jobs. `test_ui` needs `test_unit` and `upload` needs both, and the
GitHub documentation for `jobs.<job_id>.needs` states: "If a job fails or is skipped, all jobs that
need it are skipped unless the jobs use a conditional expression that causes the job to continue."
Neither dependent job uses `always()` or `!cancelled()`, so skipping `test_unit` skips the chain.
The existing label conditions on `test_ui` and `upload` are left untouched and now get evaluated
against a payload in which the new label is present.

Push events carry no `action` field, so the first clause is true and behaviour on `main` is
unchanged.

### Why check `github.event.label.name` rather than the label list

Reusing the file's existing `contains(github.event.pull_request.labels.*.name, …)` idiom would
read "does this pull request want the heavy jobs" rather than "was a gating label just added".
On a pull request already carrying `TestFlight`, that phrasing would start a build and a
TestFlight upload every time any unrelated label — `documentation`, say — was added. Checking the
label that triggered the event avoids shipping a build as a side effect of tidying labels.

## Behaviour when a run is already in flight

`concurrency` is unchanged. `cancel-in-progress` is already true for pull requests, so labelling a
pull request mid-run cancels that run and starts a new one. The restarted unit tests are the cost
of not shipping a build from a superseded run, which is the trade-off the file already documents.

## Rejected alternative

A separate workflow listening for `labeled` and calling `gh run rerun` on the last CI run does not
work: a re-run replays the original event payload, which is precisely the one without the label, so
every label condition would evaluate exactly as it did the first time.

## Verification

- `actionlint` passes on the workflow. Note it validates syntax only: a deliberately corrupted
  `github.event.labelx.namex` also passed, so it does not confirm payload paths.
- `github.event.label.name` is confirmed instead by its use in 15,776 public workflow files.
- The `needs` skip-propagation behaviour is confirmed by the sentence quoted above, from
  `data/reusables/actions/jobs/section-using-jobs-in-a-workflow-needs.md` in `github/docs`.
- End-to-end proof requires a live pull request. Adding `UITests` exercises the whole trigger path
  — new run, guard passes, `test_ui` runs — without shipping anything, so it is the cheap way to
  confirm before trusting `TestFlight`.
