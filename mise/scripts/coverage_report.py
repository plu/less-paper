#!/usr/bin/env python3
"""Report per-module code coverage for the modules whose own tests ran.

Reads an .xcresult bundle and prints a markdown comment body. A module is listed only
when its own test target executed: coverage measured sideways through somebody else's
suite is not something a reviewer can act on, and printing it invites reading a shared
module's number as if its own tests had earned it.

The numbers themselves are still suite-wide - the whole suite runs as one scheme, so a
listed module's percentage counts lines reached by every test that ran, not only its own.
See docs/superpowers/specs/2026-09-13-coverage-reporting-design.md.

The report accumulates over a pull request rather than describing one push. Selective
testing runs only the targets whose fingerprint moved, so a push that touches a fourth
module runs that module's tests and no others - and a report built from that run alone
would drop the three modules the earlier pushes measured. The previous comment is read
back and merged: this run's rows win, and a module keeps its last measurement until some
push retests it. That measurement is still true for the head, because the only reason a
module was skipped is that nothing it depends on changed.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys

from dataclasses import dataclass
from pathlib import Path

MARKER = "<!-- coverage-report -->"


@dataclass(frozen=True)
class ModuleRow:
    name: str
    covered: int
    executable: int


@dataclass(frozen=True)
class FileRow:
    path: str
    covered: int | None
    executable: int | None


def percent(covered: int, executable: int) -> str:
    if executable == 0:
        return "n/a"
    return f"{covered / executable * 100:.1f}%"


def module_for_target(target_name: str) -> str:
    return Path(target_name).stem


def module_for_test_bundle(bundle_name: str) -> str | None:
    suffix = "Tests"
    if not bundle_name.endswith(suffix):
        return None
    return bundle_name[: -len(suffix)] or None


def split_counts(cell: str) -> tuple[int, int] | None:
    covered, separator, executable = cell.partition("/")
    if not separator:
        return None
    try:
        return int(covered), int(executable)
    except ValueError:
        return None


def parse_previous(body: str) -> tuple[dict[str, ModuleRow], dict[str, FileRow]]:
    """Read back the tables from a comment this script wrote earlier.

    The counts column is parsed rather than the percentage: it is the number the report is
    built from, and a percentage would have to be believed back into two integers.
    """
    modules: dict[str, ModuleRow] = {}
    files: dict[str, FileRow] = {}
    in_files = False

    for line in body.splitlines():
        line = line.strip()
        if line.startswith("### Files changed"):
            in_files = True
            continue
        if not line.startswith("|"):
            continue

        cells = [cell.strip() for cell in line.strip("|").split("|")]
        if len(cells) != 3:
            continue

        name, _, counts_cell = cells
        if name in ("Module", "File") or set(name) <= {"-", ":"}:
            continue

        counts = split_counts(counts_cell)
        if in_files:
            files[name] = (
                FileRow(name, counts[0], counts[1]) if counts else FileRow(name, None, None)
            )
        elif counts:
            modules[name] = ModuleRow(name, counts[0], counts[1])

    return modules, files


def merge_modules(previous: dict[str, ModuleRow], current: list[ModuleRow]) -> list[ModuleRow]:
    merged = dict(previous)
    for row in current:
        merged[row.name] = row
    return sorted(merged.values(), key=lambda row: row.name)


def module_rows(coverage: dict, executed_bundles: list[str]) -> list[ModuleRow]:
    tested = {
        module
        for module in (module_for_test_bundle(name) for name in executed_bundles)
        if module
    }

    rows = [
        ModuleRow(
            module_for_target(target["name"]),
            target["coveredLines"],
            target["executableLines"],
        )
        for target in coverage.get("targets", [])
        if module_for_target(target["name"]) in tested
    ]

    return sorted(rows, key=lambda row: row.name)


def instrumented_modules(coverage: dict) -> set[str]:
    return {module_for_target(target["name"]) for target in coverage.get("targets", [])}


def relative_path(absolute: str, repo_root: Path) -> str | None:
    try:
        return str(Path(absolute).relative_to(repo_root))
    except ValueError:
        return None


def changed_source_files(changed: list[str], instrumented: set[str]) -> list[str]:
    kept = []
    for path in changed:
        parts = Path(path).parts
        if len(parts) < 3 or parts[0] != "Modules" or not path.endswith(".swift"):
            continue
        # Membership of the instrumented set is what excludes test and support modules, so there
        # is no second list of module names here to drift from Module.codeCoverageTarget.
        if parts[1] not in instrumented:
            continue
        kept.append(path)

    return sorted(set(kept))


def file_rows(
    coverage: dict,
    changed: list[str],
    listed: set[str],
    repo_root: Path,
    previous: dict[str, FileRow] | None = None,
) -> list[FileRow]:
    measured: dict[str, tuple[int, int]] = {}
    for target in coverage.get("targets", []):
        if module_for_target(target["name"]) not in listed:
            continue
        for entry in target.get("files", []):
            path = relative_path(entry["path"], repo_root)
            if path:
                measured[path] = (entry["coveredLines"], entry["executableLines"])

    carried = previous or {}

    # Driven by `changed`, which is the pull request's whole diff, so a file that stopped being
    # part of the pull request drops out rather than being carried forever.
    rows = []
    for path in changed:
        if path in measured:
            covered, executable = measured[path]
            rows.append(FileRow(path, covered, executable))
        elif (earlier := carried.get(path)) and earlier.covered is not None:
            rows.append(earlier)
        else:
            rows.append(FileRow(path, None, None))

    return rows


def render(modules: list[ModuleRow], files: list[FileRow]) -> str:
    lines = [MARKER, "", "## Coverage", ""]

    if not modules:
        lines += ["No modules have been tested for this pull request yet.", ""]
        return "\n".join(lines)

    lines += ["| Module | Coverage | Lines |", "| --- | ---: | ---: |"]
    lines += [
        f"| {module.name} | {percent(module.covered, module.executable)} "
        f"| {module.covered}/{module.executable} |"
        for module in modules
    ]
    lines += [
        "",
        "Only modules whose own tests ran are listed, and the numbers are suite-wide. "
        "Rows persist across pushes: a module keeps its last measurement until a push retests it.",
    ]

    if files:
        lines += [
            "",
            "### Files changed in this pull request",
            "",
            "| File | Coverage | Lines |",
            "| --- | ---: | ---: |",
        ]
        for entry in files:
            if entry.covered is None:
                lines.append(f"| {entry.path} | not measured | |")
            else:
                lines.append(
                    f"| {entry.path} | {percent(entry.covered, entry.executable)} "
                    f"| {entry.covered}/{entry.executable} |"
                )

    lines.append("")
    return "\n".join(lines)


def read_coverage(bundle: Path) -> dict:
    try:
        result = subprocess.run(
            ["xcrun", "xccov", "view", "--report", "--json", str(bundle)],
            capture_output=True,
            text=True,
            check=True,
        )
    except subprocess.CalledProcessError:
        # A bundle that exists but was never fed a completed test run (xcodebuild created it,
        # then died before any test produced coverage) makes xccov exit 1 with "No coverage data
        # in result bundle". That is the same legitimate outcome as no bundle at all - not a
        # reason to crash the report - so it flows through module_rows/instrumented_modules
        # exactly like the empty coverage of a bundle that was never written.
        return {}
    return json.loads(result.stdout)


def read_executed_bundles(bundle: Path) -> list[str]:
    result = subprocess.run(
        [
            "xcrun", "xcresulttool", "get", "test-results", "tests",
            "--path", str(bundle), "--format", "json",
        ],
        capture_output=True,
        text=True,
        check=True,
    )

    return [
        child["name"]
        for plan in json.loads(result.stdout).get("testNodes", [])
        for child in plan.get("children", [])
        if child.get("nodeType") == "Unit test bundle"
    ]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bundle", type=Path, required=True)
    parser.add_argument("--repo-root", type=Path, required=True)
    parser.add_argument(
        "--changed-files",
        type=Path,
        help="file listing the pull request's changed paths, one per line",
    )
    parser.add_argument(
        "--previous-report",
        type=Path,
        help="file holding the body of the comment this script wrote last time, if any",
    )
    args = parser.parse_args()

    previous_modules: dict[str, ModuleRow] = {}
    previous_files: dict[str, FileRow] = {}
    if args.previous_report and args.previous_report.exists():
        previous_modules, previous_files = parse_previous(args.previous_report.read_text())

    # No bundle means xcodebuild never ran. run_tests.sh already treats that as a legitimate
    # outcome - and a run that produced nothing has learned nothing, so what the earlier pushes
    # measured is still the best description of this head.
    if not args.bundle.exists():
        print(
            render(
                merge_modules(previous_modules, []),
                list(previous_files.values()),
            ),
            end="",
        )
        return 0

    coverage = read_coverage(args.bundle)
    modules = module_rows(coverage, read_executed_bundles(args.bundle))

    changed = []
    if args.changed_files and args.changed_files.exists():
        changed = args.changed_files.read_text().splitlines()

    # This run's modules, not the merged set: the file table reads per-file numbers out of this
    # bundle, and a carried module has none in it. Its files come from `previous_files` instead.
    listed = {module.name for module in modules}
    files = file_rows(
        coverage,
        changed_source_files(changed, instrumented_modules(coverage)),
        listed,
        args.repo_root,
        previous_files,
    )

    print(render(merge_modules(previous_modules, modules), files), end="")
    return 0


if __name__ == "__main__":
    sys.exit(main())
