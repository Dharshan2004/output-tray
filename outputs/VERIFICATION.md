# Verification, October 9, 2026

- Native arm64 release build succeeded on macOS 26.5.1 with Swift 6.3.3.
- Real Markdown and SVG files appeared automatically in the tray. The final demo helper created a new real Markdown file, and the final build displayed it with registered labels in its top-bar popover.
- Registered title, project, and task labels displayed correctly.
- Actual top-bar NSPopover inspected through native accessibility: files and drag handles present.
- Quick Look rendered the actual SVG file.
- Show in Finder selected the actual SVG.
- A native dragging session started for the SVG and ended with NSDragOperation.copy (operation 1), recorded by the app itself. The automated Finder destination remained empty, so that specific destination is not verified.
- Open handed the real Markdown file to Cursor, where its file tab appeared.
- A newly created task/output folder under an already connected root appeared automatically in the running app. Disconnect removed those discovered files and restored the manual folder.
- The final app restored a real Codex-folder connection and showed 90 files across 98 watched folders.
- Global connection migration, default-folder relocation, and isolated demo-mode preference preservation passed. The existing live connection was migrated to the global setting and confirmed as the selected local Codex folder.
- Connected-root discovery tests passed for new/deleted folders, depth boundaries, symlinks, exclusions, limits, persistence, and disconnect.
- Direct Swift scanner harness passed lifecycle, stability, deletion, metadata safety, filtering, folder persistence, and duplicate checks.
- Six Python CLI integration tests passed.

This is a local macOS demo, not a signed/notarized public release. Apple Silicon execution is verified. Other Macs, cloud-only files, and files outside connected output folders are not covered by these checks.
