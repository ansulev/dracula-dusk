#!/usr/bin/env bash
# fetch-targets.sh — populate targets/ with Dracula-Soft patched theme files
#
# Source priority per app:
#   1. Existing installed files in user's ~/.config / ~/.themes / /usr/share
#   2. Git submodule (git submodule update --init themes/<name>)
#
# Usage:
#   ./fetch-targets.sh [--dry-run] [--list] [APP...]
#   ./fetch-targets.sh --dry-run alacritty gtk hyprland
#   ./fetch-targets.sh                      # runs tier1 apps
#   ./fetch-targets.sh --all               # runs tier1 + tier2 apps
#
# After populating targets/<app>/, apply the Dracula-Soft palette:
#   ./dracula-soft.sh targets/<app>/
#
# Apps marked [ANSI] are skipped: their colors are ANSI escape codes, not hex.
# Apps marked [BGR]  are skipped: Geany uses BGR byte-reversed hex — patch manually.
set -euo pipefail

readonly REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TARGETS_DIR="${REPO_DIR}/targets"
readonly PATCHER="${REPO_DIR}/dracula-soft.sh"
readonly MAP="${REPO_DIR}/palette.map"
readonly GTK_MAP="${REPO_DIR}/palette.gtk.map"

log()  { echo "[$(date '+%H:%M:%S')] $*"; }
die()  { echo "[ERROR] $*" >&2; exit 1; }
info() { echo "  $*"; }

# ---------------------------------------------------------------------------
# App registry: NAME -> "submodule|sys_path1|sys_path2|..."
# First sys_path that exists wins. If none found, submodule is used.
# Special values: ANSI (skip), BGR (skip).
# ---------------------------------------------------------------------------
declare -A APP_SOURCES=(
  # ── Tier 1: editor, terminal, gtk, qt, wm ────────────────────────────────
  [vim]="themes/vim
    ${HOME}/.local/share/nvim/site/pack/dracula/opt/vim
    ${HOME}/.vim/pack/themes/start/vim"
  [visual-studio-code]="themes/visual-studio-code
    ${HOME}/.vscode/extensions/dracula-theme.theme-dracula-*/
    ${HOME}/.config/Code/extensions/dracula-theme.theme-dracula-*/"
  [alacritty]="themes/alacritty
    ${HOME}/.config/alacritty/themes
    ${HOME}/.config/alacritty"
  [kitty]="themes/kitty
    ${HOME}/.config/kitty"
  [foot]="themes/foot
    ${HOME}/.config/foot"
  [gtk]="themes/gtk
    ${REPO_DIR}/../gtk-themes/archcraft-gtk-theme-dracula/files/Dracula
    ${HOME}/.themes/Dracula
    /usr/share/themes/Dracula"
  [gtksourceview]="themes/gtksourceview
    ${HOME}/.local/share/gtksourceview-5/styles
    ${HOME}/.local/share/gtksourceview-4/styles
    /usr/share/gtksourceview-5/styles
    /usr/share/gtksourceview-4/styles"
  [qt5]="themes/qt5
    ${HOME}/.config/qt5ct/colors
    /usr/share/qt5ct/colors"
  [hyprland]="themes/hyprland
    ${HOME}/.config/hypr"
  [waybar]="themes/waybar
    ${HOME}/.config/waybar"
  [rofi]="themes/rofi
    ${HOME}/.config/rofi"
  [openbox]="themes/openbox
    ${REPO_DIR}/../labwc-themes/OB-Dracula/openbox-3
    ${HOME}/.themes/Dracula/openbox-3
    /usr/share/themes/Dracula/openbox-3"
  [labwc-config]="themes/labwc-config
    ${REPO_DIR}/../labwc-config/files"
  # ── Tier 2 ────────────────────────────────────────────────────────────────
  [zsh]="themes/zsh
    ${HOME}/.oh-my-zsh/themes
    ${HOME}/.config/zsh"
  [zsh-syntax-highlighting]="themes/zsh-syntax-highlighting
    ${HOME}/.config/zsh"
  [zellij]="themes/zellij
    ${HOME}/.config/zellij/themes"
  [zed]="themes/zed
    ${HOME}/.config/zed/themes"
  [sublime]="themes/sublime
    ${HOME}/.config/sublime-text/Packages/Dracula Color Scheme"
  [typora]="themes/typora
    ${HOME}/.config/Typora/themes"
  [lxterminal]="themes/lxterminal
    ${HOME}/.config/lxterminal"
  [xfce4-terminal]="themes/xfce4-terminal
    ${HOME}/.local/share/xfce4/terminal/colorschemes
    /usr/share/xfce4/terminal/colorschemes"
  [dmenu]="themes/dmenu"
  [eclipse]="themes/eclipse"
  [dracula-css]="themes/dracula-css"
  # ── ANSI-based: hex patcher not applicable ─────────────────────────────────
  [fzf]="ANSI"
  [exa]="ANSI"
  [eza]="ANSI"
  [dircolors]="ANSI"
  # ── BGR byte-order: requires manual conversion ─────────────────────────────
  [geany]="BGR"
)

TIER1=(vim visual-studio-code alacritty kitty foot gtk gtksourceview qt5
       hyprland waybar rofi openbox labwc-config)
TIER2=(zsh zsh-syntax-highlighting zellij zed sublime typora
       lxterminal xfce4-terminal dmenu eclipse dracula-css)

# Deploy targets: after patching, rsync targets/<app>/ to this path.
# Only defined for apps where automatic deployment makes sense.
declare -A DEPLOY_PATHS=(
  [gtk]="${HOME}/.themes/Dracula-Soft"
  [openbox]="${HOME}/.themes/Dracula-Soft/openbox-3"
)

# Paths to exclude from --delete during deployment (space-separated relative paths).
# Use when multiple apps share the same deploy parent directory.
declare -A DEPLOY_EXCLUDES=(
  [gtk]="openbox-3"
)

DRY_RUN=false
RUN_ALL=false
REQUESTED=()

# ---------------------------------------------------------------------------
usage() {
  cat >&2 <<EOF
Usage: $(basename "$0") [--dry-run] [--all] [--list] [APP...]

  --dry-run    Show what would happen; do not copy or patch files.
  --all        Process tier1 + tier2 apps (default: tier1 only).
  --list       Print all known apps and their source paths, then exit.
  APP...       One or more app names (see --list).
EOF
  exit 1
}

list_apps() {
  echo "Known apps (APP -> resolved source):"
  for app in "${TIER1[@]}"; do
    printf "  [t1] %-28s  %s\n" "$app" "$(resolve_source "$app" || echo '(no source found)')"
  done
  for app in "${TIER2[@]}"; do
    printf "  [t2] %-28s  %s\n" "$app" "$(resolve_source "$app" || echo '(no source found)')"
  done
  for app in fzf exa eza dircolors geany; do
    src="${APP_SOURCES[$app]:-?}"
    printf "  [--] %-28s  SKIP: %s\n" "$app" "$src"
  done
}

# Returns the first existing source path for an app (or exits non-zero).
resolve_source() {
  local app="$1"
  local spec="${APP_SOURCES[$app]:-}"
  [[ -n "$spec" ]] || return 1

  local first_line
  first_line=$(echo "$spec" | head -1 | xargs)
  [[ "$first_line" == "ANSI" || "$first_line" == "BGR" ]] && return 1

  # Remaining lines (after first) are system candidate paths
  local candidates
  mapfile -t candidates < <(echo "$spec" | tail -n +2 | sed 's/^[[:space:]]*//')

  for cand in "${candidates[@]}"; do
    # Expand globs (VSCode extension dir uses *)
    for expanded in $cand; do
      [[ -e "$expanded" ]] && { echo "$expanded"; return 0; }
    done
  done

  # Fall back to submodule
  local submod="$first_line"
  [[ -n "$submod" ]] && { echo "${REPO_DIR}/${submod}"; return 0; }

  return 1
}

fetch_app() {
  local app="$1"
  local spec="${APP_SOURCES[$app]:-}"

  if [[ -z "$spec" ]]; then
    log "SKIP $app — not in registry"
    return
  fi

  local first_line
  first_line=$(echo "$spec" | head -1 | xargs)

  if [[ "$first_line" == "ANSI" ]]; then
    log "SKIP $app — ANSI color codes, hex patcher not applicable"
    return
  fi
  if [[ "$first_line" == "BGR" ]]; then
    log "SKIP $app — BGR byte-reversed format (Geany), patch manually"
    return
  fi

  local src
  if ! src=$(resolve_source "$app"); then
    # Try initializing the submodule
    local submod="${first_line}"
    if [[ -d "${REPO_DIR}/${submod}/.git" ]] || [[ -f "${REPO_DIR}/${submod}/.git" ]]; then
      src="${REPO_DIR}/${submod}"
    else
      if [[ "$DRY_RUN" == false ]]; then
        # In the dracula-theme monorepo: use submodule init.
        # Standalone (no .gitmodules listing this path): git clone from GitHub.
        if grep -qs "path = ${submod}" "${REPO_DIR}/.gitmodules" 2>/dev/null; then
          log "INIT submodule ${submod}"
          git -C "${REPO_DIR}" submodule update --init "${submod}"
        else
          log "CLONE github.com/dracula/${app} -> ${submod}"
          git clone --depth=1 "https://github.com/dracula/${app}.git" \
            "${REPO_DIR}/${submod}"
        fi
      fi
      src="${REPO_DIR}/${submod}"
    fi
  fi

  local dest="${TARGETS_DIR}/${app}"
  log "FETCH $app  <-  ${src}"

  if [[ "$DRY_RUN" == true ]]; then
    info "would rsync: ${src}/ -> ${dest}/"
    info "would patch: ${dest}/"
    local _deploy="${DEPLOY_PATHS[$app]:-}"
    [[ -n "$_deploy" ]] && info "would deploy: ${dest}/ -> ${_deploy}/"
    return
  fi

  mkdir -p "${dest}"
  rsync -a --delete "${src%/}/" "${dest}/"
  "${PATCHER}" "${dest}" "${MAP}"

  # GTK second pass: replace selection pink with muted plum (palette.gtk.map)
  if [[ "$app" == "gtk" ]] && [[ -f "${GTK_MAP}" ]]; then
    "${PATCHER}" "${dest}" "${GTK_MAP}"
  fi

  local deploy="${DEPLOY_PATHS[$app]:-}"
  if [[ -n "$deploy" ]]; then
    log "DEPLOY $app -> ${deploy}"
    mkdir -p "${deploy}"
    local excl_args=()
    local excl="${DEPLOY_EXCLUDES[$app]:-}"
    for e in $excl; do excl_args+=(--exclude="$e"); done
    rsync -a --delete "${excl_args[@]}" "${dest}/" "${deploy}/"
  fi
}

# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run|-n) DRY_RUN=true; shift ;;
    --all)        RUN_ALL=true; shift ;;
    --list)       list_apps; exit 0 ;;
    -h|--help)    usage ;;
    -*)           die "Unknown option: $1" ;;
    *)            REQUESTED+=("$1"); shift ;;
  esac
done

[[ -f "$PATCHER" ]] || die "patcher not found: $PATCHER"
[[ -f "$MAP"     ]] || die "palette map not found: $MAP"

if [[ ${#REQUESTED[@]} -gt 0 ]]; then
  APPS=("${REQUESTED[@]}")
elif [[ "$RUN_ALL" == true ]]; then
  APPS=("${TIER1[@]}" "${TIER2[@]}")
else
  APPS=("${TIER1[@]}")
fi

for app in "${APPS[@]}"; do
  fetch_app "$app"
done

log "Done. Patched themes are in: ${TARGETS_DIR}/"
