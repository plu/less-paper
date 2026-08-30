#!/usr/bin/env bash
# Shared by ci:test:unit and ci:test:ui. Runs one slice of the suite and turns a failure into a
# readable GitHub step summary.
#
# Usage: run_tests.sh <result-bundle-path> [extra tuist test flags…]
set -euo pipefail

bundle="$1"
shift

# xcodebuild refuses to write over an existing result bundle — "Existing file at
# -resultBundlePath" — and errors out before running a single test. In CI `ci:clean` has already
# removed the last one, but locally the second run of a task would otherwise fail while still
# leaving the previous bundle behind for anyone inspecting it afterwards.
rm -rf "$bundle"

# Selective testing is on: Tuist runs only the targets whose fingerprint changed, using the
# selection state on the server. Skipping everything is now a legitimate outcome - a documentation
# change should run nothing - which is why the reporting below exists.
#
# It was off for a long time because a skipped run is indistinguishable from a pass, and once
# produced a green run on main that executed zero tests. What has changed is that the run is no
# longer silent: the server records what was selected, and a run that tested nothing now says so
# here instead of printing an empty summary.
set +e
tuist test -d "iPhone 17 Pro" --clean "$@" -T "$bundle" \
  -- -testLanguage en -testRegion DE
test_exit_code=$?
set -e

# No bundle means xcodebuild never ran: either selective testing found nothing to do, or the build
# failed before any test started. Those look identical from here and must not - one is fine and the
# other is the failure this whole script exists to report.
if [ ! -d "$bundle" ]; then
  if [ "$test_exit_code" -eq 0 ]; then
    note="No tests ran. Selective testing found nothing whose fingerprint changed."
  else
    note="No tests ran, and the run failed - the build did not get as far as testing."
  fi
  echo "$note"
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    echo "$note" >> "$GITHUB_STEP_SUMMARY"
  fi
fi

if [ -d "$bundle" ]; then
  # xcresultparser's github format wraps every line in $\textcolor{…}{\text{…}}$ and then forgets
  # to close the wrapper on failure-message lines, so GitHub tries to render the one line that
  # matters as maths and prints it raw. Stripping the wrapper leaves plain, readable markdown.
  summary=$(xcresultparser --output-format github --failed-tests-only "$bundle" \
    | sed -E 's/\$\\textcolor\{[a-z]+\}\{\\text\{//g; s/\}\}\$//g')
  echo "$summary"
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    echo "$summary" >> "$GITHUB_STEP_SUMMARY"
  fi
fi

exit "$test_exit_code"
