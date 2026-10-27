#!/usr/bin/env python3
"""Keep only successful complete backups. Destination is an explicit installation value."""
import argparse
from datetime import datetime, timezone
import fcntl
from pathlib import Path
import re
import shutil
import subprocess

p = argparse.ArgumentParser()
p.add_argument('--env-file', required=True)
p.add_argument('--destination', required=True)
p.add_argument('--keep', type=int, default=7)
a = p.parse_args()
if a.keep < 1:
    p.error('--keep must be positive')
root = Path(a.destination).resolve()
root.mkdir(mode=0o700, parents=True, exist_ok=True)
repo = Path(__file__).resolve().parents[1]
with (root/'.backup.lock').open('w') as lock:
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    stamp = datetime.now(timezone.utc).strftime('%Y%m%d_%H%M%S')
    pending = root/(stamp+'.partial')
    subprocess.run(['sh', str(repo/'scripts/backup.sh'), '--env-file', str(Path(a.env_file).resolve()), str(pending)], check=True)
    subprocess.run(['sha256sum', '-c', 'SHA256SUMS'], cwd=pending, check=True)
    pending.rename(root/stamp)
    complete = sorted(x for x in root.iterdir() if re.fullmatch(r'[0-9]{8}_[0-9]{6}', x.name) and not x.is_symlink() and x.is_dir() and (x/'SHA256SUMS').is_file())
    for old in complete[:-a.keep]:
        if old.resolve().parent != root:
            raise RuntimeError('Backup escaped destination')
        shutil.rmtree(old)
    print('Complete backup verified; retention applied:', stamp)
