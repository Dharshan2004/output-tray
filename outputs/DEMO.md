# One-minute demo

Build the app with `./scripts/build-app.sh`, then launch **Launch Output Tray.command**. It watches **Live Outputs** and opens the actual top-bar popover. The demo run keeps your saved full Codex collection separate, without clearing its connection. Keep Finder already open to a destination folder. Rehearse your destination before presenting. If showing existing files, say Codex prepared them earlier.

| Time | Action and words |
| --- | --- |
| 0–8 s | Click the top-bar icon. “Codex made the file. Why am I still looking for it? This is Output Tray.” |
| 8–20 s | “Connect your local Codex folder once. New task output folders are picked up automatically.” Show **Connect Codex**, or the connected status, without spending stage time in a picker. |
| 20–35 s | Create a real file using the prepared command below, or show the prepared brief. “The real file appears in the tray.” If using the helper, describe it as a repeatable file-creation demo, not live Codex inference. |
| 35–52 s | Preview the SVG or brief. Drag a file by its grip to your rehearsed destination. If that destination was not verified, click **Show in Finder** instead. “Preview it, take the file to your next tool, or find the original immediately.” |
| 52–60 s | “One tiny tray between generating a file and actually using it. Built with GPT-6.1 Sol.” |

One-command real file creation, from the project root:

```sh
python3 outputs/demo-create.py
```

For live Codex generation, ask Codex to write a new brief into `outputs/Live Outputs` and wait for the actual file before describing it as live generation. The helper was authored by Codex, but executing it is ordinary local file creation.

The app covers files inside connected local `output` and `outputs` folders through three levels. It does not capture every possible Codex file or cloud-only artifact. Unregistered files show filenames and folder provenance. Project/task labels appear only when explicitly registered.

Verified: actual menu-bar popover, real-file appearance, new task-folder discovery, explicit labels, SVG and Markdown Quick Look, opening in the default app, and Finder reveal. A native drag session ended with macOS copy acceptance, but the automated Finder destination stayed empty. Manually rehearse your intended drop target before using drag on stage. `VERIFICATION.md` records these limits.
