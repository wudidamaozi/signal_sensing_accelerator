"""Install only the pinned demo dependency in a project-local environment."""
from pathlib import Path
import os
import subprocess
import sys
import venv

ROOT = Path(__file__).resolve().parents[1]

if __name__ == '__main__':
    if sys.version_info[:2] != (3, 12):
        raise SystemExit('Use Python 3.12, matching the frozen technical report.')
    target = ROOT / '.venv'
    venv.EnvBuilder(with_pip=True).create(target)
    python = target / ('Scripts/python.exe' if os.name == 'nt' else 'bin/python')
    subprocess.run([str(python), '-m', 'pip', 'install', '-r', str(ROOT / 'requirements.txt')], check=True)
    print('SETUP_COMPLETE', python, flush=True)
