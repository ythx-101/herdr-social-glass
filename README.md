# Herdr Social Glass

Herdr Social Glass is a Herdr plugin for macOS with two screenshot-friendly workspace themes — Social Glass and Island Glass — plus macOS Terminal window launchers. It is for people who share screenshots or recordings of multi-agent terminal workspaces (for example, AI coding agents running side by side) and want a polished light look without hand-editing `config.toml`; every apply is validated, backed up, and reversible with one `restore` action.

Social Glass keeps the translucent editorial workspace, while the optional Island Glass variant adds a warm cream sidebar, natural status signals, card-like spacing, and a compact time board. Both use Herdr's built-in Catppuccin Latte theme and the existing macOS Terminal `Clear Light` profile. "Social" refers to the screenshot-friendly look; the plugin has no social-platform integration.

![Herdr Social Glass workspace](assets/social-glass-workspace.jpg)

## Design language

- **Soft transparency** — our visual language uses restrained blur and translucency to keep the desktop present without competing with the work.
- **Editorial structure** — a clear reading order, generous spacing, and deliberate pane proportions turn a terminal workspace into a composed canvas.
- **Hairline architecture** — fine pane borders and gaps provide structure without visual weight.
- **Lavender signal** — a focused accent color identifies active controls and agent state.
- **Visible collaboration** — pane titles, status lines, and the optional agent sidebar make roles and progress legible in screenshots.
- **Island Glass** — warm cream, soil brown, leaf green, teal, yellow, and coral create a calm collaboration station without copying game artwork, logos, fonts, or icons.

## Social Glass vs Island Glass

| | Social Glass | Island Glass |
|---|---|---|
| Apply action | `apply` | `apply-island` |
| Window action | `open-window` | `open-island-window` |
| Base theme | `catppuccin-latte` | `catppuccin-latte` |
| Look | Translucent panels (`panel_bg = "reset"`), lavender accent `#7287fd` | Translucent panels (`panel_bg = "reset"`) with a warm cream sidebar `#F1EAD8`, leaf-green accent `#4F7D2A` |
| Sidebar width (default / min–max) | 29 / 25–33 | 32 / 28–36 |
| Tab bar right side | Not set | `QINGYUE LAB` text and a `%m/%d %H:%M` date-time |
| Status indicators | Not set in the preset | `symbols` |
| Window launcher | Opens the `Clear Light` profile | Same profile, plus per-window OSC 10/11 text and background colors |

**Good fit:** running several agents in Herdr on macOS and sharing screenshots or recordings of the workspace.

**Not a fit:**

- Linux or Windows — the manifest declares `platforms = ["macos"]`, and the window actions rely on AppleScript and Terminal.app.
- Keeping your own Herdr configuration and changing only a few colors — apply replaces the whole file and does not merge keys.

## Requirements

- macOS
- Herdr 0.8.2 or newer (protocol 20)
- macOS Terminal with the built-in `Clear Light` profile for the window actions
- Bash and AppleScript, both included with macOS

## Quick start

Applying a theme replaces your entire Herdr configuration (with a backup), so read [Trust, security, and configuration safety](#trust-security-and-configuration-safety) before installing.

```bash
herdr plugin install ythx-101/herdr-social-glass                     # install from GitHub
herdr plugin action invoke apply --plugin linyu.social-glass         # or apply-island
herdr plugin action invoke open-window --plugin linyu.social-glass   # or open-island-window
herdr plugin action invoke restore --plugin linyu.social-glass       # back to your original config
```

## Actions

```bash
herdr plugin action invoke apply --plugin linyu.social-glass
herdr plugin action invoke apply-island --plugin linyu.social-glass
herdr plugin action invoke open-window --plugin linyu.social-glass
herdr plugin action invoke open-island-window --plugin linyu.social-glass
herdr plugin action invoke status --plugin linyu.social-glass
herdr plugin action invoke restore --plugin linyu.social-glass
```

Open the guide inside Herdr:

```bash
herdr plugin pane open --plugin linyu.social-glass --entrypoint guide
```

### What each action does

- `apply` validates and applies the original Social Glass preset.
- `apply-island` validates and applies the optional Island Glass preset.
- `open-window` opens macOS Terminal with the `Clear Light` profile and starts Herdr in that window. It does not modify the Terminal profile.
- `open-island-window` opens the same unmodified Terminal profile with an Island Glass launch label and per-window OSC defaults for soil-brown text (`#5B4636`) on warm cream (`#F8F4E8`). It does not persist those colors or edit Terminal preferences.
- `status` reports the Herdr version and identifies Social Glass, Island Glass, or a local modification.
- `restore` backs up the current configuration, restores the saved pre-theme baseline, and asks Herdr to reload it.

## Trust, security, and configuration safety

A Herdr plugin can execute local commands. This plugin runs the readable shell scripts in [`scripts/`](scripts/) and uses AppleScript only to open and arrange a macOS Terminal window. Inspect the manifest and scripts before installing if you do not trust the source. The plugin has no third-party runtime or theme dependency and does not request network credentials.

The apply actions intentionally replace the **entire** Herdr configuration; they do not merge individual theme keys. Before replacement, the plugin validates the rendered preset with Herdr, stores a uniquely named copy of the current configuration in the local plugin-state area, and atomically replaces the active file. The first apply that finds an existing configuration also records it as the restore baseline. Later applies keep that original baseline and add new backups. If no configuration exists, apply creates one without a baseline; `restore` remains unavailable until a baseline exists.

If Herdr rejects a new configuration during reload, the script atomically restores the immediate backup (or removes the newly created configuration when none existed) and reloads again. The `restore` action copies the saved baseline back as the full active configuration after first backing up the current file. If that reload fails, the restored baseline remains on disk for inspection. Uninstalling the plugin does not itself restore the old configuration, so invoke `restore` first if you want to return to the baseline.

### Optional local window title

Public presets contain generic window titles. To personalize both variants without changing tracked theme files, place one non-empty line (maximum 120 bytes, no control characters) in the plugin config directory printed by:

```bash
herdr plugin config-dir linyu.social-glass
```

Name the file `window-title.txt`. Its contents are escaped and inserted only as a TOML string; the file is never sourced or evaluated as shell code. Remove the file to return to generic preset titles.

The Island window colors can be overridden for one launch with `HERDR_ISLAND_FOREGROUND` and `HERDR_ISLAND_BACKGROUND`. Both must be strict six-digit `#RRGGBB` values; invalid values are rejected before AppleScript is invoked. The Social launcher does not send OSC 10/11 color overrides.

Backups are local copies of the full Herdr configuration and may therefore contain the same private values as that configuration. Protect and remove them according to your own local security policy.

## Local tests

Requires Python 3.11+ (the tests use `tomllib`); the `python3` bundled with macOS developer tools may be too old. The functional test uses a mock Herdr and a mock `osascript`, so it also runs on Linux.

From the repository root:

```bash
bash tests/smoke.sh
bash tests/functional.sh
bash -n scripts/*.sh
git diff --check
```

The smoke test parses the manifest and both themes, checks compatibility and the Island visual contract, and verifies all six actions. The isolated functional test uses a temporary config and mock Herdr binary to cover both apply paths, literal title injection, invalid-title rejection, status detection, reload rollback, and baseline restore without touching the live Herdr config.

## Project files

- `herdr-plugin.toml` — plugin metadata, actions, and guide entry point
- `theme/social-glass.toml` — the complete Herdr preset
- `theme/island-glass.toml` — the optional warm Island Glass preset
- `scripts/apply-preset.sh` — safely render, validate, back up, apply, and roll back either preset
- `scripts/apply.sh`, `scripts/apply-island.sh` — compatible theme entry points
- `scripts/restore.sh` — restore the original baseline
- `scripts/open-social-window.sh` — open Terminal with the `Clear Light` profile
- `scripts/open-island-window.sh` — open the Island-labelled Terminal window
- `scripts/status.sh` — report whether the preset is active
- `scripts/guide.sh` — display this guide inside Herdr
- `tests/smoke.sh`, `tests/functional.sh` — static and isolated behavioral checks

## FAQ

**Will this overwrite my Herdr config?**
Yes — `apply` and `apply-island` replace the whole file. Before replacing, the script validates the rendered preset with Herdr and saves a copy of your current configuration; the first apply that finds an existing configuration also records it as the restore baseline.

**How do I go back to my old config?**
Run `restore`. Uninstalling the plugin does not restore anything by itself, so run `restore` first.

**Does it work on Linux or Windows?**
No. The manifest declares macOS only, and the window actions use AppleScript and Terminal.app.

**Do I need to install Catppuccin separately?**
No. Both presets use Herdr's built-in `catppuccin-latte` theme.

**Which theme should I pick?**
See [Social Glass vs Island Glass](#social-glass-vs-island-glass).

**How do I change the window title?**
Put one line in `window-title.txt` inside the directory printed by `herdr plugin config-dir linyu.social-glass`; see [Optional local window title](#optional-local-window-title).

**Can I remove the "QINGYUE LAB" label in Island Glass?**
Not through a setting. It is written directly in `theme/island-glass.toml` (`tab_bar_right`), so removing it means editing that file in a local fork or copy.

**Is it safe to install?**
The plugin is plain shell scripts and AppleScript, with no network requests in its scripts and no credentials required. Read [Trust, security, and configuration safety](#trust-security-and-configuration-safety) and inspect `scripts/` before installing.

## 中文简介

Herdr Social Glass 是一个 macOS 上的 Herdr 插件，提供两套适合终端截图分享的 Herdr 主题（Social Glass 毛玻璃/半透明风、Island Glass 暖奶油风），基于 Catppuccin Latte 浅色主题，并附带 macOS 终端美化用的窗口启动器，适合展示多智能体 / AI 编程 agent 工作区。

- 安装：`herdr plugin install ythx-101/herdr-social-glass`
- 应用主题：`herdr plugin action invoke apply --plugin linyu.social-glass`（Island Glass 用 `apply-island`）
- 恢复原配置：`herdr plugin action invoke restore --plugin linyu.social-glass`

注意：应用主题会整份替换 Herdr 配置（替换前会校验并自动备份），不是只合并几项；仅支持 macOS。

## License

MIT. See [LICENSE](LICENSE).
