# shellcheck shell=bash disable=SC2154,SC2034  # bats provides $status/$output; vars are read by .bats files
# Shared bats fixtures. No network: every "origin" is a local bare repo.
# Run the suite under zsh with: GW_TEST_SHELL=zsh bats tests/

GW_SRC="$BATS_TEST_DIRNAME/../gw-suit.sh"

setup_common() {
  TEST_TMP="$(cd "$BATS_TEST_TMPDIR" && pwd)"
  export HOME="$TEST_TMP/home"
  mkdir -p "$HOME"
  export GIT_CONFIG_NOSYSTEM=1
  export GIT_CONFIG_GLOBAL="$HOME/.gitconfig"
  git config --global user.name tester
  git config --global user.email tester@localhost
  git config --global init.defaultBranch main
  git config --global advice.detachedHead false
  unset GW_ROOT PROJECTS_ROOT GW_BASE_PREFIX GW_TASK_PREFIX GW_CLEAN_TARGET XDG_DATA_HOME
  GW_TEST_SHELL="${GW_TEST_SHELL:-bash}"
  if [ "$GW_TEST_SHELL" = zsh ] && ! command -v zsh >/dev/null 2>&1; then
    skip "zsh not installed"
  fi
}

# native <path> -> path git.exe/curl understand (mixed form on Windows)
native() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s\n' "$1"; fi
}

# make_origin [default-branch] [extra-branch...] -> sets ORIGIN (a bare repo path)
make_origin() {
  local def="${1:-main}" src="$TEST_TMP/src" b
  shift || true
  git init -q -b "$def" "$src"
  git -C "$src" commit -q --allow-empty -m init
  for b in "$@"; do
    git -C "$src" branch "$b"
  done
  git clone -q --bare "$src" "$TEST_TMP/origin.git"
  ORIGIN="$(native "$TEST_TMP/origin.git")"
}

# gw <shell code> -> run code with gw-suit sourced, in $GW_TEST_SHELL, from $PWD
gw() {
  if [ "$GW_TEST_SHELL" = zsh ]; then
    run zsh -fc '. "$1"; shift; eval "$*"' _ "$GW_SRC" "$@"
  else
    run bash --norc --noprofile -c '. "$1"; shift; eval "$*"' _ "$GW_SRC" "$@"
  fi
}

# clone_project -> gwclone ORIGIN into $TEST_TMP/proj (requires make_origin)
clone_project() {
  cd "$TEST_TMP" || return 1
  gw "gwclone '$ORIGIN' proj"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  PROJ="$TEST_TMP/proj"
}

# commit_in <dir> <msg> -> empty commit in dir
commit_in() { git -C "$1" commit -q --allow-empty -m "$2"; }

REPO="$BATS_TEST_DIRNAME/.."
DEST_REL=".local/share/gw-suit"

# file_url <path> -> file:// URL curl understands on every platform
file_url() {
  local p
  p="$(native "$1")"
  case "$p" in
    /*) printf 'file://%s\n' "$p" ;;
    *) printf 'file:///%s\n' "$p" ;;
  esac
}

# make_release -> REL dir with the installer's downloadable files + SHA256SUMS; sets BASE_URL
make_release() {
  REL="$TEST_TMP/rel"
  mkdir -p "$REL"
  cp "$REPO/gw-suit.sh" "$REPO/uninstall.sh" "$REL/"
  "$REPO/scripts/make-sums.sh" "$REL"
  BASE_URL="$(file_url "$REL")"
  export SHELL=/bin/bash
}

# inst [VAR=value...] -> run install.sh against the local release
inst() { run env GW_SUIT_BASE_URL="$BASE_URL" "$@" bash "$REPO/install.sh"; }

# uninst [VAR=value...] -> run the repo's uninstall.sh
uninst() { run env "$@" bash "$REPO/uninstall.sh"; }

count_blocks() { grep -c '^# >>> gw-suit >>>' "$1" || true; }
