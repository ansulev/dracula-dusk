#!/usr/bin/env bash
# dracula-dusk.sh — patch a Dracula theme directory with the Dracula Dusk palette
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DEFAULT_MAP="${SCRIPT_DIR}/palette.map"

log()   { echo "[$(date '+%H:%M:%S')] $*"; }
die()   { echo "[ERROR] $*" >&2; exit 1; }

usage() {
  cat >&2 <<EOF
Usage: $(basename "$0") [--dry-run] <theme-dir> [palette.map]

Replace every Dracula hex color found in <theme-dir> with its Dracula Dusk
equivalent defined in the palette map.

  --dry-run / -n   Show which files would change; do not modify them.
  theme-dir        Root of a checked-out Dracula theme submodule
                   (e.g. themes/alacritty, or any ad-hoc path).
  palette.map      Color map file. Default: ${DEFAULT_MAP}

Map format:
  ; comment line (or any line without '=')
  #rrggbb=#rrggbb      hex pair, lowercase, case-insensitive match

Matching covers:
  - #RRGGBB  and  #rrggbb  (hash-prefixed, case-insensitive)
  - bare RRGGBB / rrggbb   (no hash, word-boundary-guarded, for ini/conf/Xresources)

File types patched (text files only; binaries are silently skipped):
  css scss sass less svg json yml yaml toml xml html htm conf ini cfg
  properties sh lua vim vimrc rasi kdl ron theme colors colorscheme
  js ts tsx jsx md txt Xresources .Xresources Xdefaults themerc
EOF
  exit 1
}

# ── Argument parsing ──────────────────────────────────────────────────────────

DRY_RUN=false
ROOT=""
MAP="${DEFAULT_MAP}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run|-n) DRY_RUN=true; shift ;;
    -h|--help)    usage ;;
    -*)           die "Unknown option: $1. Run with --help for usage." ;;
    *)
      if   [[ -z "$ROOT" ]];               then ROOT="$1"
      elif [[ "$MAP" == "$DEFAULT_MAP" ]];  then MAP="$1"
      else usage
      fi
      shift ;;
  esac
done

[[ -n "$ROOT" ]] || { echo "[ERROR] Missing <theme-dir> argument." >&2; usage; }
[[ -d "$ROOT" ]] || die "Theme dir not found: '$ROOT'"
[[ -f "$MAP"  ]] || die "Palette map not found: '$MAP'"

# ── Build Perl substitution script from the map ───────────────────────────────
#
# For each #old=#new pair we emit TWO substitutions:
#   1. s/#old/#new/ig          — hash-prefixed, case-insensitive
#   2. s/(?<![0-9a-fA-F])old(?![0-9a-fA-F])/new/ig
#                              — bare hex, word-boundary guarded
#
# Ordering: with-hash runs first so it never double-replaces a hash form.
# The bare pattern's lookbehind/lookahead prevents matching in the middle
# of a longer hex string (e.g. #282a360f stays untouched).
#
# NOTE: Lines that start with ';' or have no '=' are skipped automatically
# by the '=' check — no separate comment handler needed.

tmp_perl="$(mktemp)"
tmp_files="$(mktemp)"
trap 'rm -f "$tmp_perl" "$tmp_files"' EXIT

{
  echo 'use strict; use warnings;'
  echo 'while (<>) {'

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip blank lines and lines without '=' (covers ; comments too)
    [[ -z "$line" ]]       && continue
    [[ "$line" == *=* ]]   || continue

    old="${line%%=*}"
    new="${line#*=}"

    # Trim leading/trailing whitespace
    old="${old#"${old%%[![:space:]]*}"}"; old="${old%"${old##*[![:space:]]}"}"
    new="${new#"${new%%[![:space:]]*}"}"; new="${new%"${new##*[![:space:]]}"}"

    # Strip inline ; comment from value
    new="${new%%;*}"; new="${new%"${new##*[![:space:]]}"}"

    [[ -n "$old" && -n "$new" ]] || continue

    old_bare="${old#\#}"
    new_bare="${new#\#}"

    # Escape special regex/replacement chars for Perl.
    # \$ inside the char class avoids $] being interpolated as Perl's version string.
    old_esc=$(printf '%s' "$old"      | perl -pe 's/([\\\/|.*+?(){}\[\]^\$])/\\$1/g')
    new_esc=$(printf '%s' "$new"      | perl -pe 's/\\/\\\\/g; s/\$/\\\$/g; s/@/\\@/g')
    ob_esc=$(printf '%s'  "$old_bare" | perl -pe 's/([\\\/|.*+?(){}\[\]^\$])/\\$1/g')
    nb_esc=$(printf '%s'  "$new_bare" | perl -pe 's/\\/\\\\/g; s/\$/\\\$/g; s/@/\\@/g')

    # 1. Hash-prefixed form (case-insensitive)
    printf 's/%s/%s/ig;\n' "$old_esc" "$new_esc"
    # 2. Bare hex form with word-boundary lookarounds (case-insensitive)
    printf 's/(?<![0-9a-fA-F])%s(?![0-9a-fA-F])/%s/ig;\n' "$ob_esc" "$nb_esc"
    # 3. Hyprland rgba(rrggbbAA) — alpha suffix blocks lookahead in pattern 2.
    #    Captures and preserves the 2-digit alpha; replacement uses $1 backref.
    printf 's/rgba\\(%s([0-9a-fA-F]{2})\\)/rgba(%s$1)/ig;\n' "$ob_esc" "$nb_esc"
  done < "$MAP"

  echo 'print; }'
} > "$tmp_perl"

# ── Collect candidate text files ──────────────────────────────────────────────

find "$ROOT" \
  \( -type d \( -name .git -o -name node_modules -o -name dist \
                -o -name build -o -name .next -o -name coverage \
                -o -name __pycache__ \) -prune \) -o \
  \( -type f \
    \( -name "*.css"  -o -name "*.scss" -o -name "*.sass"  -o -name "*.less" \
    -o -name "*.svg"  -o -name "*.json" -o -name "*.yml"   -o -name "*.yaml" \
    -o -name "*.toml" -o -name "*.xml"  -o -name "*.html"  -o -name "*.htm"  \
    -o -name "*.conf" -o -name "*.ini"  -o -name "*.cfg"   -o -name "*.properties" \
    -o -name "*.sh"   -o -name "*.lua"  -o -name "*.vim"   -o -name "*.vimrc" \
    -o -name "*.rasi" -o -name "*.kdl"  -o -name "*.ron"   \
    -o -name "*.theme" -o -name "*.colors" -o -name "*.colorscheme" \
    -o -name "*.js"   -o -name "*.ts"   -o -name "*.tsx"   -o -name "*.jsx"  \
    -o -name "*.md"   -o -name "*.txt"  \
    -o -name "Xresources" -o -name ".Xresources" -o -name "Xdefaults" \
    -o -name "themerc" \
    \) -print0 \) > "$tmp_files"

# ── Apply substitutions ───────────────────────────────────────────────────────

changed=0
skipped=0

while IFS= read -r -d '' file; do
  if ! grep -Iq . "$file" 2>/dev/null; then
    (( skipped++ )) || true
    continue
  fi

  if ! perl "$tmp_perl" "$file" | cmp -s "$file" -; then
    if [[ "$DRY_RUN" == true ]]; then
      echo "DRY  $file"
    else
      perl -i "$tmp_perl" "$file"
      log "OK   $file"
    fi
    (( changed++ )) || true
  fi
done < "$tmp_files"

echo
if [[ "$DRY_RUN" == true ]]; then
  log "Would modify: ${changed} file(s)  (binary skipped: ${skipped})"
else
  log "Modified: ${changed} file(s)  (binary skipped: ${skipped})"
fi
