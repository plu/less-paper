#!/usr/bin/env python3
"""Report per-module code coverage for the modules whose own tests ran.

Reads an .xcresult bundle and prints a markdown comment body. A module is listed only
when its own test target executed: coverage measured sideways through somebody else's
suite is not something a reviewer can act on, and printing it invites reading a shared
module's number as if its own tests had earned it.

The numbers themselves are still suite-wide - the whole suite runs as one scheme, so a
listed module's percentage counts lines reached by every test that ran, not only its own.
See docs/superpowers/specs/2026-09-13-coverage-reporting-design.md.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

MARKER = "<!-- coverage-report -->"


@dataclass(frozen=True)
class ModuleRow:
    name: str
    covered: int
    executable: int


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


@dataclass(frozen=True)
class FileRow:
    path: str
    covered: int | None
    executable: int | None


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
    coverage: dict, changed: list[str], listed: set[str], repo_root: Path
) -> list[FileRow]:
    measured: dict[str, tuple[int, int]] = {}
    for target in coverage.get("targets", []):
        if module_for_target(target["name"]) not in listed:
            continue
        for entry in target.get("files", []):
            path = relative_path(entry["path"], repo_root)
            if path:
                measured[path] = (entry["coveredLines"], entry["executableLines"])

    rows = []
    for path in changed:
        if path in measured:
            covered, executable = measured[path]
            rows.append(FileRow(path, covered, executable))
        else:
            rows.append(FileRow(path, None, None))

    return rows


def render(modules: list[ModuleRow], files: list[FileRow]) -> str:
    lines = [MARKER, "", "## Coverage", ""]

    if not modules:
        lines += [
            "No modules were tested in this run - selective testing found nothing whose",
            "fingerprint changed.",
            "",
        ]
        return "\n".join(lines)

    lines += ["| Module | Coverage | Lines |", "| --- | ---: | ---: |"]
    lines += [
        f"| {module.name} | {percent(module.covered, module.executable)} "
        f"| {module.covered}/{module.executable} |"
        for module in modules
    ]
    lines += [
        "",
        "Only modules whose own tests ran are listed, and the numbers are suite-wide.",
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
