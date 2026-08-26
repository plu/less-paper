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

set +e
tuist test -d "iPhone 17 Pro" --clean "$@" -T "$bundle" -- -testLanguage en -testRegion DE
test_exit_code=$?
set -e

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
