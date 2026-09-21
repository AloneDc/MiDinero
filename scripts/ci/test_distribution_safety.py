"""Fail-closed distribution check. No certificate, profile or API key fixtures."""
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import distribute_testflight


class DistributionSafetyTests(unittest.TestCase):
    def test_missing_credentials_cannot_run_commands_or_create_signing_files(self):
        with tempfile.TemporaryDirectory() as directory:
            work = Path(directory) / 'signing'
            with patch.dict(os.environ, {}, clear=True), patch.object(distribute_testflight, 'run') as command:
                with self.assertRaisesRegex(RuntimeError, '^Missing real configuration:'):
                    distribute_testflight.distribute(work)
                command.assert_not_called()
            self.assertFalse(work.exists())


if __name__ == '__main__':
    unittest.main()
