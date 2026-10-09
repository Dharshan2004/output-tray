# Output Tray

“Codex made the file. Why am I still looking for it?”

A compact native macOS menu-bar tray for real local files. Preview with Quick Look, open in the default app, reveal in Finder, or drag the real file out by its grip.

## Use on your Mac

Open **Output Tray.app**, then click its tray icon in the macOS menu bar. Click **Connect Codex**, and select your local Codex work folder, usually `Documents/Codex`. The app discovers `output` and `outputs` folders through three directory levels, including new task folders created later. One connection replaces configuring each chat separately.

This covers local files in those output folders. It does not capture every possible Codex file, cloud-only artifacts, or files saved elsewhere. Add another explicit folder through the folder control. Files found in watched folders show filenames and folder provenance; optional registration provides titles and project/task labels. Folder discovery does not prove a file was created by Codex.

The app stores its default output folder in the current user's Application Support directory. No account or API key is required. Files refresh every second and need two stable observations; folder discovery refreshes every three seconds. Discovery is bounded to 500 visited directories and 100 output folders; hidden folders, symlinks, apps, dependencies, and build directories are excluded. The tray shows the 30 newest files.

## Demo tonight

Double-click **Launch Output Tray.command** to watch the adjacent **Live Outputs** folder and open the top-bar popover. `DEMO.md` contains the one-minute sequence. Prepared files must be described as prepared earlier.

## Build and verify

From the project root:

```sh
./scripts/build-app.sh
./scripts/test.sh
open -n "outputs/Output Tray.app" --args --folder "$PWD/outputs/Live Outputs" --window
```

The window flag is for rehearsal. Normal launch uses only the menu bar. The Codex connection persists per user even if the app moves or the default output folder changes. `swift test` also has XCTest sources for full Xcode environments; `scripts/test.sh` runs meaningful checks with the command-line toolchain.

## Optional explicit labels

```sh
python3 outputs/register-output.py "outputs/Live Outputs/brief.md" \
  --title "Launch brief" --project "Output Tray" --task "Demo preparation"
```

The file must exist directly in a watched folder. The CLI atomically writes `.output-tray.json` and rejects unsafe paths. Registration adds labels; it does not establish generation provenance.

See `VERIFICATION.md` for tested behavior and remaining limits. This is an Apple Silicon local demo, not a signed/notarized public release. Built with GPT-6.1 Sol and native SwiftUI/AppKit; no new DevDay feature integration is claimed.
