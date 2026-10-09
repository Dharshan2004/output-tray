#!/usr/bin/env python3
"""Attach explicit labels to one existing file in an Output Tray folder."""

import argparse
import json
import os
from pathlib import Path
import sys
import tempfile
from datetime import datetime, timezone


def register(args):
    supplied = Path(args.file).expanduser().absolute()
    folder = Path(args.folder).expanduser().resolve(strict=True) if args.folder else supplied.parent.resolve(strict=True)
    if not folder.is_dir():
        raise ValueError("The watched folder must be a directory.")
    # Preserve the supplied basename so ../ paths and escaping symlinks cannot
    # silently become metadata for a different file.
    if supplied.parent.resolve(strict=True) != folder:
        raise ValueError("The file must be directly inside the watched folder.")
    actual = supplied.resolve(strict=True)
    if actual.parent != folder:
        raise ValueError("Symlinks must not escape the watched folder.")
    if not actual.is_file():
        raise ValueError("Only existing regular files can be registered.")
    if supplied.name.startswith(".") or supplied.name.endswith((".tmp", ".part", ".download", "~")):
        raise ValueError("Hidden and temporary files cannot be registered.")

    manifest = folder / ".output-tray.json"
    if manifest.is_symlink():
        raise ValueError("The metadata manifest must not be a symlink.")
    payload = {"artifacts": []}
    if manifest.exists():
        payload = json.loads(manifest.read_text(encoding="utf-8"))
        if not isinstance(payload, dict) or not isinstance(payload.get("artifacts"), list):
            raise ValueError("Existing manifest must contain an artifacts array.")
        if any(not isinstance(item, dict) for item in payload["artifacts"]):
            raise ValueError("Existing manifest contains an invalid artifact entry.")
    previous = next((item for item in payload["artifacts"] if item.get("path") == supplied.name), {})
    entry = {
        "path": supplied.name,
        "title": args.title or previous.get("title") or supplied.stem,
        "createdAt": previous.get("createdAt") or datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z"),
    }
    for field in ("project", "task"):
        value = getattr(args, field)
        if value is not None:
            entry[field] = value
        elif previous.get(field):
            entry[field] = previous[field]
    payload["artifacts"] = [item for item in payload["artifacts"] if item.get("path") != supplied.name] + [entry]
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", prefix=".output-tray-", suffix=".tmp", dir=folder, delete=False) as handle:
            temporary = Path(handle.name)
            json.dump(payload, handle, indent=2, ensure_ascii=False)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, manifest)
    finally:
        if temporary and temporary.exists():
            temporary.unlink()
    print(f"Registered {supplied.name} in {manifest}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("file", help="Existing file, directly inside the watched folder")
    parser.add_argument("--folder", help="Watched folder; defaults to the file's parent")
    parser.add_argument("--title", help="Display title; defaults to filename without extension")
    parser.add_argument("--project", help="Explicit project label")
    parser.add_argument("--task", help="Explicit task label")
    args = parser.parse_args()
    try:
        register(args)
    except (OSError, ValueError) as error:
        print(f"Registration failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
