#!/usr/bin/env bash
# gw-suit uninstaller
#
#   ~/.local/share/gw-suit/uninstall.sh
#   (or: curl -fsSL https://raw.githubusercontent.com/mayank-singh-sikarwar/gw-suit/v1.1.0/uninstall.sh | bash)
#
# Removes exactly the "# >>> gw-suit >>>" ... "# <<< gw-suit <<<" block from each rc file
# (after a backup) and deletes the install folder. Nothing else is touched. Safe to re-run.
# Options: GW_SUIT_RC (extra rc files, ":"-separated), GW_SUIT_DRY_RUN=1.

# shellcheck disable=SC2088  # literal "~" is matched on purpose
GWU_FILES="gw-suit.sh uninstall.sh VERSION state"

_gwu_say()  { printf 'gw-suit: %s\n' "$*"; }
_gwu_warn() { printf 'gw-suit: warning: %s\n' "$*" >&2; }

_gwu_expand() {
  case "$1" in
    "~/"*) printf '%s\n' "$HOME/${1#"~/"}" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

# _gwu_candidates <state-file> -> "flag<TAB>rc" lines, recorded rc files first, then defaults
_gwu_candidates() {
  local state="$1" rc
  [ -f "$state" ] && cat "$state"
  {
    printf '%s\n' "$HOME/.bashrc" "$HOME/.zshrc"
    [ -n "${GW_SUIT_RC:-}" ] && printf '%s\n' "$GW_SUIT_RC" | tr ':' '\n'
  } | while IFS= read -r rc; do
    [ -n "$rc" ] && printf 'plain\t%s\n' "$(_gwu_expand "$rc")"
  done
}

# _gwu_remove_block <rc> <flag>
_gwu_remove_block() {
  local rc="$1" flag="$2" b tmp
  b="$rc.gw-suit.bak.$(date +%Y%m%d%H%M%S)"
  [ -e "$b" ] && b="$b.$$"
  cp -p "$rc" "$b"
  _gwu_say "backed up $rc -> $b"
  tmp="$rc.gw-suit.tmp"
  awk -v BINMODE=3 '/^# >>> gw-suit >>>/{skip=1; next} skip && /^# <<< gw-suit <<<\r?$/{skip=0; next} !skip{print}' \
    "$rc" > "$tmp"
  if [ "$flag" = nl ]; then
    # the installer added a newline because the file did not end with one; take it back
    awk -v BINMODE=3 'NR > 1 { printf "\n" } { printf "%s", $0 }' "$tmp" > "$tmp.2" && mv "$tmp.2" "$tmp"
  fi
  cat "$tmp" > "$rc"
  rm -f "$tmp"
  if [ "$flag" = created ] && [ ! -s "$rc" ]; then
    rm -f "$rc"
    _gwu_say "$rc: removed (the installer had created it)"
  else
    _gwu_say "$rc: removed the gw-suit block"
  fi
}

gw_suit_uninstall() {
  set -eu
  local dest="${XDG_DATA_HOME:-$HOME/.local/share}/gw-suit"
  local dry="${GW_SUIT_DRY_RUN:-0}"
  local seen="" flag rc f did=0

  while IFS="$(printf '\t')" read -r flag rc; do
    [ -n "$rc" ] || continue
    case "$seen" in *"|$rc|"*) continue ;; esac
    seen="$seen|$rc|"
    if [ ! -f "$rc" ] || ! grep -q "^# >>> gw-suit >>>" "$rc"; then continue; fi
    did=1
    if [ "$dry" = 1 ]; then
      _gwu_say "dry run: would remove the gw-suit block from $rc"
    else
      _gwu_remove_block "$rc" "$flag"
    fi
  done <<EOF
$(_gwu_candidates "$dest/state")
EOF

  if [ -d "$dest" ]; then
    did=1
    if [ "$dry" = 1 ]; then
      _gwu_say "dry run: would delete $dest"
    else
      for f in $GWU_FILES; do rm -f "$dest/$f"; done
      if rmdir "$dest" 2>/dev/null; then
        _gwu_say "deleted $dest"
      else
        _gwu_warn "$dest has other files in it; left in place"
      fi
    fi
  fi

  [ "$did" = 1 ] || _gwu_say "nothing to uninstall"
  [ "$dry" = 1 ] || [ "$did" = 0 ] || _gwu_say "done. Open a new shell to drop the gw commands."
}

gw_suit_uninstall "$@"
