#!/usr/bin/env python3
"""Exercise retention, failed backups and concurrent runs in disposable directories."""
import fcntl
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

SOURCE = Path(__file__).resolve().parents[1]/'scripts/backup-retained.py'

class Retention(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.scripts = self.root/'scripts'
        self.scripts.mkdir()
        shutil.copy(SOURCE, self.scripts/'backup-retained.py')
        (self.scripts/'backup.sh').write_text('#!/bin/sh\nset -eu\nmkdir -p "$3"\n[ "$(cat "$2")" != FAIL ] || exit 9\nprintf payload > "$3/payload"\n(cd "$3" && sha256sum payload > SHA256SUMS)\n')
        self.profile = self.root/'profile'
        self.profile.write_text('OK')
        self.dest = self.root/'backups'
        self.dest.mkdir()
        for day in range(1, 9):
            old = self.dest/f'202001{day:02d}_000000'
            old.mkdir()
            (old/'SHA256SUMS').touch()
        (self.dest/'old.partial').mkdir()
        self.outside = self.root/'outside'
        self.outside.mkdir()
        (self.outside/'keep').touch()
        (self.dest/'20190101_000000').symlink_to(self.outside, target_is_directory=True)
    def tearDown(self):
        self.tmp.cleanup()
    def run_backup(self):
        return subprocess.run(['python3',str(self.scripts/'backup-retained.py'),'--env-file',str(self.profile),'--destination',str(self.dest),'--keep','7'],capture_output=True)
    def test_success_keeps_seven_and_preserves_partial_and_symlink(self):
        self.assertEqual(self.run_backup().returncode, 0)
        complete = [x for x in self.dest.iterdir() if x.is_dir() and not x.is_symlink() and (x/'SHA256SUMS').is_file()]
        self.assertEqual(len(complete), 7)
        self.assertTrue((self.dest/'old.partial').exists())
        self.assertTrue((self.outside/'keep').exists())
    def test_failure_does_not_prune(self):
        self.profile.write_text('FAIL')
        self.assertNotEqual(self.run_backup().returncode, 0)
        self.assertEqual(len(list(self.dest.glob('202001*'))), 8)
    def test_lock_rejects_concurrent_backup(self):
        with (self.dest/'.backup.lock').open('w') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            self.assertNotEqual(self.run_backup().returncode, 0)
        self.assertEqual(len(list(self.dest.glob('202001*'))), 8)

if __name__ == '__main__':
    unittest.main()
