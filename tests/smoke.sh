#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

for script in "$ROOT"/scripts/*.sh; do
  bash -n "$script"
done

python3 - "$ROOT/herdr-plugin.toml" "$ROOT/theme/social-glass.toml" "$ROOT/theme/island-glass.toml" <<'PY'
import pathlib
import os
import sys
import tomllib

manifest_path, social_path, island_path = map(pathlib.Path, sys.argv[1:])
manifest = tomllib.loads(manifest_path.read_text())
social = tomllib.loads(social_path.read_text())
island = tomllib.loads(island_path.read_text())

assert manifest["id"] == "linyu.social-glass"
assert manifest["version"] == "1.1.0"
assert manifest["min_herdr_version"] == "0.8.2"
assert manifest["platforms"] == ["macos"]

actions = {action["id"]: action for action in manifest["actions"]}
assert set(actions) == {
    "apply",
    "apply-island",
    "restore",
    "open-window",
    "open-island-window",
    "status",
}
assert actions["apply"]["command"] == ["bash", "scripts/apply.sh"]
assert actions["open-window"]["command"] == ["bash", "scripts/open-social-window.sh"]
assert actions["restore"]["command"] == ["bash", "scripts/restore.sh"]
assert actions["status"]["command"] == ["bash", "scripts/status.sh"]
assert actions["apply-island"]["command"] == ["bash", "scripts/apply-island.sh"]
assert actions["open-island-window"]["command"] == ["bash", "scripts/open-island-window.sh"]

assert social["theme"]["name"] == "catppuccin-latte"
assert social["theme"]["custom"]["panel_bg"] == "reset"
assert social["ui"]["sidebar_collapsed_mode"] == "hidden"
assert social["ui"]["tab_bar_position"] == "top"
assert social["ui"]["sidebar_width"] == 29
assert social["ui"]["sidebar_min_width"] == 25
assert social["ui"]["sidebar_max_width"] == 33

custom = island["theme"]["custom"]
assert island["theme"]["name"] == "catppuccin-latte"
assert custom["sidebar_bg"] == "#F1EAD8"
assert custom["active_row_bg"] == "#E3EFCF"
assert custom["selection_bg"] == "#F3D77D"
assert custom["accent"] == "#4F7D2A"
assert custom["blue"] == "#2FAFA0"
assert custom["mauve"] == "#2FAFA0"
assert custom["green"] == "#68A942"
assert custom["yellow"] == "#D6A53A"
assert custom["red"] == "#D86D5F"
assert custom["surface0"] == "#E9DFC9"
assert custom["surface1"] == "#DED1B8"
assert custom["overlay0"] == "#A89578"
assert custom["overlay1"] == "#8E7A60"
assert custom["text"] == "#5B4636"
assert custom["subtext0"] == "#7B6750"
assert island["ui"]["accent"] == "#4F7D2A"

def relative_luminance(color):
    channels = [int(color[index:index + 2], 16) / 255 for index in (1, 3, 5)]
    linear = [channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4 for channel in channels]
    return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]

assert 1.05 / (relative_luminance(island["ui"]["accent"]) + 0.05) >= 4.5
assert island["ui"]["sidebar_width"] == 32
assert island["ui"]["sidebar_min_width"] == 28
assert island["ui"]["sidebar_max_width"] == 36
assert island["ui"]["pane_gaps"] is True
assert island["ui"]["pane_borders"] is True
assert island["ui"]["status_indicators"] == "symbols"
assert island["ui"]["tab_bar_right"] == [
    {"type": "text", "text": "QINGYUE LAB"},
    {"type": "datetime", "format": "%m/%d %H:%M"},
]
assert island["ui"]["tab_bar_right_separator"] == " · "

for path, theme in ((social_path, social), (island_path, island)):
    assert "yulin807" not in path.read_text()
    assert theme["ui"]["window_title"] in {"Herdr Social Glass", "Herdr Island Glass"}

short_version = ".".join(manifest["version"].split(".")[:2])
for relative in ("scripts/status.sh", "scripts/guide.sh"):
    assert short_version in (manifest_path.parent / relative).read_text(), f"{relative} lacks version {short_version}"

for relative in (
    "scripts/apply-island.sh",
    "scripts/apply-preset.sh",
    "scripts/open-island-window.sh",
    "tests/functional.sh",
):
    assert os.access(manifest_path.parent / relative, os.X_OK), f"not executable: {relative}"

assert "assets/plugin-actions.png" not in (manifest_path.parent / "README.md").read_text()
PY

printf 'smoke tests passed\n'
