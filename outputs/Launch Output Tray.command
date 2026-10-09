#!/bin/zsh
set -euo pipefail
OUTPUT_TRAY_DIR="${0:A:h}"
open -n "$OUTPUT_TRAY_DIR/Output Tray.app" --args --folder "$OUTPUT_TRAY_DIR/Live Outputs" --demo --show-tray
