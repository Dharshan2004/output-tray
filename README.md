# Output Tray

[![CI](https://github.com/Dharshan2004/output-tray/actions/workflows/ci.yml/badge.svg)](https://github.com/Dharshan2004/output-tray/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black)
![Swift 6](https://img.shields.io/badge/Swift-6-orange)

**Your local Codex outputs, ready to use from the macOS menu bar.**

Output Tray is a native macOS app that collects real files from connected output folders. Connect your local Codex work folder once, then preview, open, reveal, or drag files from a compact tray as you work across tasks.

## Features

- **Connect once:** discover `output` and `outputs` folders, including newly created task folders.
- **Stay up to date:** detect new, changed, and deleted files while the app runs.
- **Preview quickly:** inspect supported files with macOS Quick Look.
- **Use the real file:** open it in its default app, reveal it in Finder, or drag it to another app.
- **Keep context:** show filenames and folder provenance, with optional title, project, and task labels.
- **Keep setup local:** no account, API key, or setup for each chat is required.

## Getting started

### Requirements

- macOS 14 or later.
- A Swift 6 toolchain, available with a compatible Xcode or Command Line Tools installation.
- Python 3 for the test suite and optional metadata helpers.

Apple Silicon execution has been verified. Other Mac configurations have not yet been verified. The current app is a local prototype with an ad-hoc signature; it is not a notarized public release.

### Build and launch

```sh
git clone https://github.com/Dharshan2004/output-tray.git
cd output-tray
./scripts/build-app.sh
open "outputs/Output Tray.app"
```

Click the tray icon in the macOS menu bar, choose **Connect Codex**, and select your local work folder, typically `Documents/Codex`. The connection persists between launches. Use the folder control to watch an additional explicit folder.

The build script creates the app bundle in `outputs/Output Tray.app`. Normal launch uses the menu bar. To open a rehearsal window:

```sh
open -n "outputs/Output Tray.app" --args --window
```

### Watch a specific folder

```sh
open -n "outputs/Output Tray.app" --args --folder "/path/to/outputs"
```

You can also provide `--codex-root "/path/to/Codex"` to connect a root or `--show-tray` to open the popover on launch. Only one instance of the app runs at a time.

## How discovery works

Output Tray searches up to three directory levels beneath the connected root for folders named `output` or `outputs`. It watches files directly inside those folders and displays the 30 newest files.

File scans run every second, with two stable observations required before a new or changed file appears. Folder discovery runs every three seconds. Discovery is bounded to 500 visited directories and 100 output folders; coverage limits are reported in the tray.

Hidden folders, symlinks, application bundles, dependency directories, and build directories are excluded. Cloud-only artifacts, files saved outside connected output folders, and arbitrary nested files are outside automatic coverage. Finding a file does not establish that Codex generated it.

## Optional labels

Register an existing file to give it a title and project/task labels:

```sh
python3 outputs/register-output.py "/path/to/outputs/brief.md" \
  --title "Launch brief" --project "My project" --task "Planning"
```

The helper atomically updates `.output-tray.json` beside the file. Registered paths must refer to files directly in the watched folder. Labels describe the file; they do not establish generation provenance.

## Development

```sh
./scripts/test.sh
./scripts/build-app.sh
```

The test script runs a Swift harness against the actual scanner and discovery sources, followed by Python integration tests for registration. XCTest sources are also available through `swift test` on environments with the required test frameworks.

| Path | Purpose |
| --- | --- |
| `Sources/OutputTray/` | Native menu-bar UI, file store, and bounded folder discovery |
| `Tests/OutputTrayTests/` | XCTest scanner tests |
| `scripts/` | Build and verification tools |
| `docs/` | Product overview and verification record |
| `outputs/` | Metadata helpers, prepared demo fixtures, and generated app bundle |

## Current status

Release builds and core scanner, discovery, persistence, and metadata checks have passed locally. Automatic appearance of real files, new-folder discovery, Quick Look, default-app opening, and Finder reveal were verified in the running app.

A native drag session was verified, but the intended Finder destination was not confirmed by the automated test. Rehearse your chosen destination before relying on it in a demonstration. See [the verification record](docs/verification.md) for evidence and remaining limits.

## Contributing

Bug reports and pull requests are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) for setup, validation, and what to include in a report.

## License

[MIT](LICENSE).
