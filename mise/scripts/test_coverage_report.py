#!/usr/bin/env python3
"""Tests for coverage_report.py.

Only the pure half is tested. Everything that shells out to xcrun lives behind
read_coverage/read_executed_bundles and is exercised by running the script for real.
"""

import unittest

from coverage_report import (
    ModuleRow,
    module_for_target,
    module_for_test_bundle,
    module_rows,
    percent,
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


if __name__ == "__main__":
    unittest.main()
