"""Check that CI rejects absent, skipped or incomplete Xcode test evidence."""
import unittest

from xcode_evidence import discovered_methods, require_complete_tests, select_simulator, test_counts


class EvidenceTests(unittest.TestCase):
    def test_complete_xcode_evidence(self):
        discovered = discovered_methods("MiDineroTests/MoneyTests/testExactMoney()\nMiDineroUITests/AppTests/testRegister()")
        counts = test_counts(dict(totalTestCount=2, passedTests=2, failedTests=0, skippedTests=0, expectedFailures=0))
        require_complete_tests(discovered, ["testExactMoney", "testRegister"], counts)

    def test_missing_or_invalid_counts_are_not_assumed_zero(self):
        for summary in ({}, dict(totalTestCount=0, passedTests=0, failedTests=0, skippedTests=0),
                        dict(totalTestCount=True, passedTests=1, failedTests=0, skippedTests=0, expectedFailures=0)):
            with self.assertRaises(ValueError):
                test_counts(summary)

    def test_skipped_test_is_not_success(self):
        counts = test_counts(dict(totalTestCount=2, passedTests=1, failedTests=0, skippedTests=1, expectedFailures=0))
        with self.assertRaises(ValueError):
            require_complete_tests(["testOne", "testTwo"], ["testOne", "testTwo"], counts)

    def test_missing_discovery_is_not_success(self):
        with self.assertRaises(ValueError):
            discovered_methods("No test methods")
        counts = test_counts(dict(totalTestCount=1, passedTests=1, failedTests=0, skippedTests=0, expectedFailures=0))
        with self.assertRaises(ValueError):
            require_complete_tests(["testOne"], ["testOne", "testTwo"], counts)

    def test_simulator_selection_uses_installed_sdk_when_xcode_lists_only_generic(self):
        udid = "DC4CD8B3-4457-4153-9087-A0D7A2F9BFD9"
        runtime = "com.apple.CoreSimulator.SimRuntime.iOS-18-5"
        inventory = {"runtimes": [{"identifier": runtime, "version": "18.5", "isAvailable": True}],
                     "devices": {runtime: [{"udid": udid, "name": "iPhone 16 Pro", "isAvailable": True, "state": "Shutdown"}]}}
        self.assertEqual(select_simulator(inventory, "Any iOS Simulator", sdk_version="18.5")["udid"], udid)
        self.assertEqual(select_simulator(inventory, "id:" + udid)["udid"], udid)
        newer = "com.apple.CoreSimulator.SimRuntime.iOS-26-2"
        newer_id = "4C675116-265D-488F-BFFA-836A4545674C"
        inventory["runtimes"].append({"identifier": newer, "version": "26.2", "isAvailable": True})
        inventory["devices"][newer] = [{"udid": newer_id, "name": "iPhone 17 Pro", "isAvailable": True, "state": "Shutdown"}]
        self.assertEqual(select_simulator(inventory, "id:" + udid + " id:" + newer_id, sdk_version="18.5")["udid"], udid)
        with self.assertRaises(ValueError):
            select_simulator(inventory, "Any iOS Simulator", sdk_version="27.0")
        with self.assertRaises(ValueError):
            select_simulator(inventory, "id:" + udid, requested="missing")


if __name__ == "__main__":
    unittest.main()
