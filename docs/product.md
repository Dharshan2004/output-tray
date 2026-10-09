# Output Tray

**Your Codex outputs, ready to use from the macOS menu bar.**

Output Tray is a compact native macOS app that brings real local output files into one accessible tray. Instead of searching through chat folders, users can preview a file, open it, reveal it in Finder, or drag it into another app.

## The problem

Codex can create useful documents, images, and other files across multiple tasks. Finding those files and moving them into the next step of a workflow adds friction. Output Tray makes the handoff from a generated file to its destination more direct.

## How it works

1. Open Output Tray and click its icon in the macOS menu bar.
2. Click **Connect Codex** and select the local Codex work folder, typically `Documents/Codex`.
3. The app discovers `output` and `outputs` folders within that root, including new task folders created later.
4. Open the tray to access the newest files and act on them.

The connection is saved per user. No account, API key, or setup for each individual chat is required. Users can also add an explicit folder to watch.

## Core features

| Feature | What it does |
| --- | --- |
| Menu-bar access | Keeps a compact file tray available at the top of the screen. |
| Automatic discovery | Finds local output folders under the connected Codex root. |
| Live file updates | Detects new, changed, and deleted files while the app is running. |
| Preview | Uses macOS Quick Look to preview supported files. |
| Open | Opens the real file in its default application. |
| Finder reveal | Selects the file in Finder. |
| Drag out | Provides a native file drag handle for handing files to other apps. |
| Optional labels | Supports explicit titles, project names, and task names through local metadata. |

## Product experience

The tray shows the 30 newest files with filenames and folder provenance. Optional metadata adds more descriptive labels. The menu-bar icon displays a file count, and the popover provides actions beside each file.

The app operates on local files and watches only connected locations. File discovery establishes where a file was found; it does not establish that Codex generated it.

## Current coverage

Output Tray currently discovers `output` and `outputs` folders through three directory levels beneath the selected root. It watches files directly inside those folders. Discovery is bounded to 500 visited directories and 100 output folders, with hidden folders, symlinks, application bundles, dependencies, and build directories excluded.

Files refresh every second and require two stable observations before appearing or updating. Folder discovery refreshes every three seconds.

Cloud-only artifacts, files saved elsewhere, and arbitrary nested files are outside automatic coverage. Users can connect an additional explicit folder when needed.

## Current release status

This is a working local prototype for Apple Silicon Macs, built with native SwiftUI and AppKit. It is not yet a signed and notarized public release. Compatibility with other Mac configurations has not been verified.

The release build and core scanner, discovery, persistence, and metadata checks passed. Automatic appearance of real Markdown and SVG files, discovery of a newly created task folder, Quick Look, default-app opening, and Finder reveal were verified in the running app.

A native drag session was verified, but the automated test did not confirm a file arriving in the intended Finder destination. The chosen drag destination should be rehearsed before a demonstration.

## Example workflow

A user asks Codex to create a Markdown brief in a task's `outputs` folder. Output Tray detects the file and displays it in the menu-bar tray. The user previews it, opens it in their editor, or uses its drag handle to move it into the next application in their workflow.

## Product direction

The goal is a plug-and-play handoff layer for local Codex outputs: connect once, keep working across tasks, and reach the resulting files from the menu bar. Broader artifact coverage, verified drag destinations, and public distribution are future work rather than claims about the current release.

## Included deliverables

- `Output-Tray-macOS-arm64.zip`: packaged Apple Silicon app and supporting demo materials.
- `Output-Tray-source.zip`: source code and verification scripts.
- `README.md`: setup and usage instructions.
- `DEMO.md`: a one-minute demonstration workflow.
- `VERIFICATION.md`: tested behavior and remaining limitations.

Product status recorded on October 9, 2026.
