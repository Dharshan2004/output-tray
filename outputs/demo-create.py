#!/usr/bin/env python3
"""Create one real rehearsal artifact. This is a repeatable helper, not live AI generation."""
from pathlib import Path
from datetime import datetime, timezone
import subprocess
import sys

base = Path(__file__).resolve().parent
folder = base / 'Live Outputs'
folder.mkdir(exist_ok=True)
stamp = datetime.now(timezone.utc).strftime('%H%M%S')
file = folder / ('demo-brief-' + stamp + '.md')
file.write_text('# Output Tray demo brief\n\nCodex made the file. Why am I still looking for it?\n\nA real local file, automatically within reach.\n\nCreated by the repeatable demo helper at ' + datetime.now().astimezone().isoformat(timespec='seconds') + '.\n', encoding='utf-8')
subprocess.run([sys.executable, str(base / 'register-output.py'), str(file), '--title', 'Fresh demo brief', '--project', 'Output Tray', '--task', 'Rehearsal'], check=True)
print(file)
