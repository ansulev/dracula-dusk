# Dracula Dusk

A warmer, lower-chroma fork of [Dracula](https://draculatheme.com) designed for 10–14 h coding sessions.  
Two scripts + one map file. No build system. Works on any existing Dracula theme directory.

---

## Why

Dracula's original palette is vivid by design — great for screenshots, tiring after hours.  
Dracula Dusk keeps the same hue relationships but reduces chroma 30–40% on accents and shifts  
the dark surfaces toward Pro Dark near-black purple (HSL 246–252°, L:12–20%) — premium midnight  
feel with barely-there current-line lift, while keeping all accents soft for long sessions.

---

## Palette

| Role | Dracula | Dracula Dusk | Change |
|---|---|---|---|
| Background | `#282a36` | `#272538` | H:246°, S:10%, L:18% — soft purple-dark |
| Current Line | `#44475a` | `#302e45` | H:248°, S:10%, L:22% — barely-there lift |
| Foreground | `#f8f8f2` | `#c8c5be` | H:40°, S:4%, L:76% — dim warm grey |
| Comment | `#6272a4` | `#878ea1` | S:27→12%, L:52→58% — recedes, WCAG AA |
| Pink | `#ff79c6` | `#e890c3` | S:100→65% — dusty rose |
| Purple | `#bd93f9` | `#c1a6e5` | S:89→55% — soft lavender |
| Cyan | `#8be9fd` | `#a1dce7` | S:97→60% — soft sky |
| Green | `#50fa7b` | `#73d68c` | S:94→55% — muted sage |
| Yellow | `#f1fa8c` | `#e1e79f` | S:92→60% — soft yellow |
| Orange | `#ffb86c` | `#eab781` | S:100→72% — muted amber |
| Red | `#ff5555` | `#e17373` | S:100→65% — soft rose-red |

All accent/text pairs meet WCAG 2.1 Level AA (≥ 4.5:1 on `#272538`).  
GTK selection bg (`#454158`) vs page bg = 1.53:1 — intentional dark-purple surface lift.
Selected text (`#c8c5be` on `#454158`) = 5.67:1 ✓

---

## Standalone use — three files only

```
dracula-dusk.sh      universal hex patcher — works on any directory
palette.map          color map (editable)
palette.gtk.map      GTK-specific second pass (selection color override)
fetch-targets.sh     optional: discovers & patches your installed themes
```

Download or copy these three files anywhere. No repo required.

### Requirements

`bash` · `perl` · `rsync` (fetch-targets.sh only) · `git` (fetch-targets.sh fallback only)

---

## dracula-dusk.sh — patch any directory

```bash
# Patch an existing Dracula theme directory in place
./dracula-dusk.sh <theme-dir>

# Use a custom map file
./dracula-dusk.sh <theme-dir> /path/to/palette.map

# Preview changes without writing
./dracula-dusk.sh --dry-run <theme-dir>

# GTK — always start from a clean Dracula copy, then two passes
rsync -a --delete ~/.themes/Dracula/ ~/.themes/Dracula-Dusk/
./dracula-dusk.sh ~/.themes/Dracula-Dusk              # pass 1: full palette
./dracula-dusk.sh ~/.themes/Dracula-Dusk palette.gtk.map  # pass 2: GTK selection override
```

The patcher operates on the current state of files — each pass consumes what the previous produced.
Always start from a clean copy; never re-run a pass on an already-patched directory.

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

Automates the full pipeline: finds your installed Dracula themes, copies them clean,
applies the palette, and deploys where it can. Falls back to `git clone --depth=1`
from GitHub for any app not found on the system.

```bash
./fetch-targets.sh --list              # show all known apps and resolved source paths
./fetch-targets.sh --dry-run           # preview every step without touching anything
./fetch-targets.sh                     # fetch + patch tier-1 apps
./fetch-targets.sh --all               # tier-1 + tier-2 (~24 apps)
./fetch-targets.sh alacritty gtk rofi  # specific apps only
```

**Always run `--dry-run` first** to see which sources resolve locally and which will trigger a clone:

```bash
./fetch-targets.sh --dry-run --all 2>&1 | grep -E "FETCH|SKIP|CLONE|INIT"
```

### What it does per app

For each app, in order:

1. **Resolve source** — checks system paths (`~/.config/…`, `~/.themes/…`, `/usr/share/…`).
   First match wins. If nothing is found locally and the app directory does not exist,
   it clones `https://github.com/dracula/<app>.git` into `themes/<app>/`.
2. **rsync** `source/` → `targets/<app>/` with `--delete` (always a clean copy).
3. **Patch** `targets/<app>/` with `palette.map`.
4. **GTK only** — second pass with `palette.gtk.map` (selection color override).
5. **Deploy** — `gtk` and `openbox` are rsynced to `~/.themes/Dracula-Dusk/` automatically.
   All other apps land in `targets/` and need a manual copy (see below).

> Cold run with `--all` and no local Dracula installs will clone up to 24 repos.
> Subsequent runs skip the clone if `themes/<app>/` already exists.

### Tier 1 (core)

| App | System source looked up |
|---|---|
| `vim` | `~/.local/share/nvim/site/pack/dracula/opt/vim`, `~/.vim/pack/themes/start/vim` |
| `visual-studio-code` | `~/.vscode/extensions/dracula-theme.*` |
| `alacritty` | `~/.config/alacritty/themes` |
| `kitty` | `~/.config/kitty` |
| `foot` | `~/.config/foot` |
| `gtk` | `~/.themes/Dracula`, `/usr/share/themes/Dracula` |
| `gtksourceview` | `/usr/share/gtksourceview-{4,5}/styles` |
| `qt5` | `~/.config/qt5ct/colors` |
| `hyprland` | `~/.config/hypr` |
| `waybar` | `~/.config/waybar` |
| `rofi` | `~/.config/rofi` |
| `openbox` | `~/.themes/Dracula/openbox-3`, `/usr/share/themes/Dracula/openbox-3` |

### Tier 2

`zsh` `zsh-syntax-highlighting` `zellij` `zed` `sublime` `typora`  
`lxterminal` `xfce4-terminal` `dmenu` `eclipse` `dracula-css`

### Applying a patched theme

`gtk` and `openbox` are auto-deployed to `~/.themes/Dracula-Dusk/`. All others
land in `targets/<app>/` and need a manual copy:

```bash
# Alacritty
cp targets/alacritty/dracula.toml ~/.config/alacritty/themes/dracula-dusk.toml

# Hyprland — color definitions only
cp targets/hyprland/dracula_colors.conf ~/.config/hypr/dracula_soft_colors.conf

# gtk and openbox — nothing to do, already deployed
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
for d in targets/*/; do ./dracula-dusk.sh "$d"; done

# Or a single app
./dracula-dusk.sh targets/alacritty
```

To add a system path for a new app, edit the `APP_SOURCES` block in `fetch-targets.sh`.

---

## Credits

Built on top of the [Dracula Theme](https://draculatheme.com) by [Zeno Rocha](https://zenorocha.com)
and contributors — original palette licensed MIT.  
This patcher and palette map are original work, also MIT licensed.
