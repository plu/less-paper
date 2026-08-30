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

# Reporting this run to the Tuist server, which is what makes test insights - durations over time,
# flakiness, which targets dominate a run - exist at all. Without it `tuist test` behaves exactly as
# before and reports nothing.
#
# The token is stored in fnox as TUIST_TOKEN, deliberately not under the name Tuist reads: `fnox
# activate` hooks directory changes and exports every secret in the default profile, so a secret
# named TUIST_CONFIG_TOKEN would sit in every shell opened in this repo and shadow the developer's
# own `tuist auth login` session.
#
# Only in CI, and only if it decrypts. A checkout without the age key reports nothing and tests
# exactly as before rather than failing, which is what a pull request from a fork needs.
if [ -n "${CI:-}" ] && token=$(fnox get TUIST_TOKEN 2>/dev/null) && [ -n "$token" ]; then
  export TUIST_CONFIG_TOKEN="$token"
fi

# --no-selective-testing is not optional. Without it Tuist skips any target whose fingerprint has
# not changed and reports success having run nothing - which is indistinguishable from a pass, and
# has already produced a green run on main that executed zero tests.
set +e
tuist test -d "iPhone 17 Pro" --clean --no-selective-testing "$@" -T "$bundle" \
  -- -testLanguage en -testRegion DE
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
