# Dracula Soft CE

A warmer, lower-chroma fork of [Dracula](https://draculatheme.com) designed for 10–14 h coding sessions.  
Two scripts + one map file. No build system. Works on any existing Dracula theme directory.

---

## Why

Dracula's original palette is vivid by design — great for screenshots, tiring after hours.  
Soft CE keeps the same hue relationships but reduces chroma 30–40% on accents and shifts  
the dark surfaces from blue-grey (HSL 231°) to warm brown-grey (38°).

---

## Palette

| Role | Dracula | Soft CE | Change |
|---|---|---|---|
| Background | `#282a36` | `#312e29` | H:231→38°, S:15→9% — warm dark |
| Current Line | `#44475a` | `#565148` | H:231→38°, warm grey |
| Foreground | `#f8f8f2` | `#efeeec` | H:60→40°, S:30→9% — warm cream |
| Comment | `#6272a4` | `#767d93` | S:27→12% — recedes |
| Pink | `#ff79c6` | `#e890c3` | S:100→65% — dusty rose |
| Purple | `#bd93f9` | `#c1a6e5` | S:89→55% — soft lavender |
| Cyan | `#8be9fd` | `#a1dce7` | S:97→60% — soft sky |
| Green | `#50fa7b` | `#73d68c` | S:94→55% — muted sage |
| Yellow | `#f1fa8c` | `#e1e79f` | S:92→60% — soft yellow |
| Orange | `#ffb86c` | `#eab781` | S:100→72% — muted amber |
| Red | `#ff5555` | `#e17373` | S:100→65% — soft rose-red |

All contrasts meet WCAG 2.1 Level AA (≥ 4.5:1).

---

## Standalone use — three files only

```
dracula-ce.sh     universal hex patcher — works on any directory
palette.map       color map (editable)
fetch-targets.sh  optional: discovers & patches your installed themes
```

Download or copy these three files anywhere. No repo required.

### Requirements

`bash` · `perl` · `rsync` (fetch-targets.sh only) · `git` (fetch-targets.sh fallback only)

---

## dracula-ce.sh — patch any directory

```bash
# Patch an existing Dracula theme directory in place
./dracula-ce.sh <theme-dir>

# Use a custom map file
./dracula-ce.sh <theme-dir> /path/to/palette.map

# Preview changes without writing
./dracula-ce.sh --dry-run <theme-dir>
```

The patcher:
- Replaces every `#rrggbb` / `#RRGGBB` (case-insensitive)
- Replaces bare `rrggbb` (no `#`, e.g. foot, Xresources) with word-boundary guard
- Replaces `rgba(rrggbbAA)` preserving the alpha (Hyprland borders)
- Replaces Qt5/Qt6 `#ffrrggbb` ARGB 8-digit format
- Skips binary files automatically
- Runs on: `.css .scss .svg .json .yml .yaml .toml .xml .html .conf .ini .cfg`  
  `.sh .lua .vim .rasi .kdl .ron .theme .colors .colorscheme .js .ts .md .txt`  
  `Xresources .Xresources Xdefaults`

---

## palette.map format

```
; comment (any line without = is skipped)
#rrggbb=#rrggbb      standard 6-digit hex pair
#ffrrggbb=#ffrrggbb  Qt5/Qt6 ARGB 8-digit
```

Matching is **case-insensitive**. Values are always written lowercase.  
Add or override entries freely — the map is the single source of truth.

---

## fetch-targets.sh — discover, copy, patch

Finds your installed Dracula themes on the system, copies them to `targets/<app>/`,  
and applies the CE palette. Falls back to `git clone` from GitHub for apps not yet installed.

```bash
./fetch-targets.sh --list             # show all known apps and resolved source paths
./fetch-targets.sh --dry-run          # preview without touching anything
./fetch-targets.sh                    # fetch + patch tier-1 apps
./fetch-targets.sh --all              # tier-1 + tier-2
./fetch-targets.sh alacritty gtk rofi # specific apps
```

### Tier 1 (core)

| App | Source |
|---|---|
| `vim` | vim + neovim (shared plugin) |
| `visual-studio-code` | `~/.vscode/extensions/dracula-theme.*` |
| `alacritty` | `~/.config/alacritty/themes` |
| `kitty` | `~/.config/kitty` |
| `foot` | `~/.config/foot` |
| `gtk` | `~/.themes/Dracula` or `/usr/share/themes/Dracula` |
| `gtksourceview` | `/usr/share/gtksourceview-{4,5}/styles` |
| `qt5` | `~/.config/qt5ct/colors` |
| `hyprland` | `~/.config/hypr` |
| `waybar` | `~/.config/waybar` |
| `rofi` | `~/.config/rofi` |
| `openbox` | `~/.themes/Dracula-openbox` or `/usr/share/themes/Dracula` |

### Tier 2

`zsh` `zsh-syntax-highlighting` `zellij` `zed` `sublime` `typora`  
`lxterminal` `xfce4-terminal` `dmenu` `eclipse` `dracula-css`

### Applying a patched theme

The script copies the **source directory** to `targets/<app>/` and patches it there.  
Your live config is not modified. Copy back only the relevant files:

```bash
# Example: alacritty
cp targets/alacritty/dracula.toml ~/.config/alacritty/themes/dracula-ce.toml

# Example: gtk (as root or via symlink)
cp -r targets/gtk/ ~/.themes/Dracula-CE/

# Example: hyprland — only the color definitions file
cp targets/hyprland/dracula_colors.conf ~/.config/hypr/dracula_ce_colors.conf
```

---

## Format support

| Format | Examples | Status |
|---|---|---|
| `#rrggbb` hex | GTK, VSCode, Rofi, Vim, Alacritty | ✅ |
| bare `rrggbb` | Foot, Dmenu, Xresources | ✅ |
| `rgb(rrggbb)` | Hyprland variables | ✅ |
| `rgba(rrggbbAA)` | Hyprland borders (alpha preserved) | ✅ |
| `#ffrrggbb` ARGB | Qt5ct / Qt6ct color schemes | ✅ |
| ANSI escape codes | FZF, EZA, EXA, dircolors | ❌ not hex |
| `0xBBGGRR` BGR | Geany colorschemes | ❌ byte-reversed |

---

## Extending

To add a new app or override a color, edit `palette.map` and re-run the patcher:

```bash
# Edit palette.map, then re-patch all targets
for d in targets/*/; do ./dracula-ce.sh "$d"; done

# Or a single app
./dracula-ce.sh targets/alacritty
```

To add a system path for a new app, edit the `APP_SOURCES` block in `fetch-targets.sh`.
