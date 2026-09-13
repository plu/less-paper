#!/usr/bin/env python3
"""Tests for coverage_report.py.

Only the pure half is tested. Everything that shells out to xcrun lives behind
read_coverage/read_executed_bundles and is exercised by running the script for real.
"""

import unittest
from pathlib import Path

from coverage_report import (
    FileRow,
    ModuleRow,
    changed_source_files,
    file_rows,
    instrumented_modules,
    module_for_target,
    module_for_test_bundle,
    module_rows,
    percent,
    relative_path,
)


def target(name, covered, executable, files=None):
    return {
        "name": name,
        "coveredLines": covered,
        "executableLines": executable,
        "files": files or [],
    }


class PercentTests(unittest.TestCase):
    def test_rounds_to_one_decimal(self):
        self.assertEqual(percent(228, 322), "70.8%")

    def test_reports_a_fully_covered_target_as_whole(self):
        self.assertEqual(percent(7, 7), "100.0%")

    # A target with nothing executable is not 0% covered, it is unmeasurable. Dividing would
    # raise, and printing 0% would read as a regression.
    def test_survives_a_target_with_no_executable_lines(self):
        self.assertEqual(percent(0, 0), "n/a")


class ModuleNameTests(unittest.TestCase):
    def test_target_name_drops_the_product_extension(self):
        self.assertEqual(module_for_target("Logging.framework"), "Logging")

    def test_test_bundle_name_drops_the_tests_suffix(self):
        self.assertEqual(module_for_test_bundle("ApiImplementationTests"), "ApiImplementation")

    # AppSnapshots and AppUITests cover other modules, not one of their own, so they must never
    # be turned into a module name.
    def test_a_bundle_not_named_tests_maps_to_nothing(self):
        self.assertIsNone(module_for_test_bundle("AppSnapshots"))


class ModuleRowsTests(unittest.TestCase):
    def test_lists_a_module_whose_own_tests_ran(self):
        coverage = {"targets": [target("Logging.framework", 228, 322)]}

        rows = module_rows(coverage, ["LoggingTests"])

        self.assertEqual(rows, [ModuleRow("Logging", 228, 322)])

    # The whole point of the filter: Components is instrumented and was exercised sideways by
    # DocumentsFeatureTests, and must not be listed on the strength of that.
    def test_omits_a_dependency_whose_own_tests_did_not_run(self):
        coverage = {
            "targets": [
                target("DocumentsFeature.framework", 100, 200),
                target("Components.framework", 40, 400),
            ]
        }

        rows = module_rows(coverage, ["DocumentsFeatureTests"])

        self.assertEqual([row.name for row in rows], ["DocumentsFeature"])

    def test_omits_a_test_bundle_with_no_instrumented_target(self):
        coverage = {"targets": [target("Logging.framework", 228, 322)]}

        rows = module_rows(coverage, ["LoggingTests", "ShareAppTests"])

        self.assertEqual([row.name for row in rows], ["Logging"])

    def test_orders_rows_by_name(self):
        coverage = {
            "targets": [
                target("TagsFeature.framework", 1, 2),
                target("ApiInterface.framework", 3, 4),
            ]
        }

        rows = module_rows(coverage, ["TagsFeatureTests", "ApiInterfaceTests"])

        self.assertEqual([row.name for row in rows], ["ApiInterface", "TagsFeature"])

ROOT = Path("/repo")


def source_file(path, covered, executable):
    return {
        "name": Path(path).name,
        "path": path,
        "coveredLines": covered,
        "executableLines": executable,
    }


class InstrumentedModulesTests(unittest.TestCase):
    def test_reads_the_module_set_out_of_the_coverage_report(self):
        coverage = {
            "targets": [
                target("Logging.framework", 1, 2),
                target("DesignTokens.framework", 0, 30),
            ]
        }

        self.assertEqual(instrumented_modules(coverage), {"Logging", "DesignTokens"})


class RelativePathTests(unittest.TestCase):
    def test_makes_a_build_path_repository_relative(self):
        self.assertEqual(
            relative_path("/repo/Modules/Logging/LogWriter.swift", ROOT),
            "Modules/Logging/LogWriter.swift",
        )

    # Coverage reports carry paths into the SPM checkouts too. They belong to nobody's module.
    def test_ignores_a_path_outside_the_repository(self):
        self.assertIsNone(relative_path("/elsewhere/Vendor/Thing.swift", ROOT))


class ChangedSourceFilesTests(unittest.TestCase):
    def test_keeps_swift_sources_in_an_instrumented_module(self):
        changed = ["Modules/Logging/LogWriter.swift"]

        self.assertEqual(
            changed_source_files(changed, {"Logging"}),
            ["Modules/Logging/LogWriter.swift"],
        )

    # LoggingTests is not instrumented, so its sources never reach the set and drop out here
    # without a second rule naming test modules.
    def test_drops_sources_in_a_module_that_is_not_instrumented(self):
        changed = ["Modules/LoggingTests/LogWriterTests.swift"]

        self.assertEqual(changed_source_files(changed, {"Logging"}), [])

    def test_drops_files_outside_modules(self):
        changed = [".github/workflows/ci.yml", "Workspace.swift"]

        self.assertEqual(changed_source_files(changed, {"Logging"}), [])

    def test_drops_non_swift_files(self):
        changed = ["Modules/Logging/Resources/en.lproj/Localizable.strings"]

        self.assertEqual(changed_source_files(changed, {"Logging"}), [])


class FileRowsTests(unittest.TestCase):
    def test_reports_coverage_for_a_changed_file_in_a_listed_module(self):
        coverage = {
            "targets": [
                target(
                    "Logging.framework",
                    228,
                    322,
                    [source_file("/repo/Modules/Logging/LogWriter.swift", 105, 111)],
                )
            ]
        }

        rows = file_rows(
            coverage, ["Modules/Logging/LogWriter.swift"], {"Logging"}, ROOT
        )

        self.assertEqual(rows, [FileRow("Modules/Logging/LogWriter.swift", 105, 111)])

    # DesignTokens is instrumented but has no DesignTokensTests, so it can never be listed. Its
    # files must read as unmeasured - rendering 0% would read as a regression this pull request
    # caused, which is the one thing this report must not do.
    def test_reports_a_file_in_an_unlisted_module_as_not_measured(self):
        coverage = {
            "targets": [
                target(
                    "DesignTokens.framework",
                    0,
                    30,
                    [source_file("/repo/Modules/DesignTokens/Spacing.swift", 0, 30)],
                )
            ]
        }

        rows = file_rows(
            coverage, ["Modules/DesignTokens/Spacing.swift"], set(), ROOT
        )

        self.assertEqual(rows, [FileRow("Modules/DesignTokens/Spacing.swift", None, None)])

    def test_reports_a_brand_new_untested_file_as_zero_not_as_unmeasured(self):
        coverage = {
            "targets": [
                target(
                    "Logging.framework",
                    228,
                    322,
                    [source_file("/repo/Modules/Logging/LogClient.swift", 0, 24)],
                )
            ]
        }

        rows = file_rows(
            coverage, ["Modules/Logging/LogClient.swift"], {"Logging"}, ROOT
        )

        self.assertEqual(rows, [FileRow("Modules/Logging/LogClient.swift", 0, 24)])


if __name__ == "__main__":
    unittest.main()
