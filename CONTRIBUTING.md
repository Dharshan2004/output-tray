# Contributing

Thanks for helping improve Output Tray.

## Local setup

Use macOS 14 or later with Swift 6 and Python 3. Clone the repository, run `./scripts/test.sh`, then build with `./scripts/build-app.sh`. Launch the generated app from `outputs/Output Tray.app`.

## Reporting an issue

Include your macOS version, processor architecture, steps to reproduce, expected behavior, and actual behavior. For discovery issues, describe the folder structure with private filenames removed. For drag issues, name the destination app and file type. Do not include credentials, private artifacts, or full local paths containing personal information.

## Submitting a change

1. Create a branch for a focused change.
2. Preserve bounded, explicitly connected folder discovery and truthful file labels.
3. Add meaningful regression coverage when changing scanner, discovery, persistence, or metadata behavior.
4. Run `./scripts/test.sh` and `./scripts/build-app.sh`.
5. Open a pull request describing the problem, resulting behavior, and validation. Document any UI checks that still need manual testing.

Do not commit generated app bundles, build caches, archives, or personal rehearsal files. Contributions are provided under the repository's MIT license.
