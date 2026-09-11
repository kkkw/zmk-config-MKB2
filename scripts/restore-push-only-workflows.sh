#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd "$script_dir/.." && pwd -P)"

python3 - "$repo_root/.github/workflows/build.yml" "$repo_root/.github/workflows/draw-keymap.yml" <<'PY'
import re
import sys
from pathlib import Path

build_path = Path(sys.argv[1])
draw_path = Path(sys.argv[2])

for path in (build_path, draw_path):
    if not path.is_file():
        raise SystemExit(f"Error: workflow not found: {path}")

build = build_path.read_text()
draw = draw_path.read_text()

if (
    "  workflow_dispatch:" not in build
    and "  schedule:" not in build
    and "  workflow_dispatch:" not in draw
    and "  schedule:" not in draw
):
    print("Push-only workflow triggers are already configured.")
    raise SystemExit(0)

new_build, count = re.subn(
    r"^  workflow_dispatch:\n.*?(?=^  schedule:|^  push:)\n?",
    "", build, count=1, flags=re.MULTILINE | re.DOTALL)
if count != 1:
    raise SystemExit("Error: expected one workflow_dispatch block in build.yml")

new_build, count = re.subn(
    r"^  schedule:\n.*?(?=^  push:)\n?",
    "", new_build, count=1, flags=re.MULTILINE | re.DOTALL)
if count != 1:
    raise SystemExit("Error: expected one schedule block in build.yml")

new_build, count = re.subn(
    r"^  notify-daily-build-failure:\n.*\Z",
    "", new_build, count=1, flags=re.MULTILINE | re.DOTALL)
if count != 1:
    raise SystemExit("Error: expected the daily failure notification job in build.yml")

new_build, count = re.subn(
    r"      target: \$\{\{ inputs\.target \|\| '.*?' \}\}\n"
    r"      commit_firmware: \$\{\{ github\.event_name == 'push' \|\| inputs\.commit_firmware == true \}\}",
    '      target: "^(MKB_L_MODULE_ENC|MKB_R_MODULE_TBv4)$"\n'
    "      commit_firmware: true",
    new_build, count=1)
if count != 1:
    raise SystemExit("Error: expected manual input expressions in build.yml")

new_draw, count = re.subn(
    r"^  workflow_dispatch:\n", "", draw, count=1, flags=re.MULTILINE)
if count != 1:
    raise SystemExit("Error: expected workflow_dispatch in draw-keymap.yml")

build_path.write_text(new_build)
draw_path.write_text(new_draw)
print("Restored push-only workflow triggers.")
PY
