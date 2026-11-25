#!/usr/bin/env bats
load helpers

setup() {
  setup_common
  make_release
  printf 'export KEEP=1\n' > "$HOME/.bashrc"
  cp "$HOME/.bashrc" "$TEST_TMP/bashrc.orig"
}

@test "fresh install: files, VERSION, one block, backup, gw commands load in a new shell" {
  inst GW_SUIT_RC="$HOME/.bashrc"
  [ "$status" -eq 0 ]
  [ -f "$HOME/$DEST_REL/gw-suit.sh" ]
  [ -x "$HOME/$DEST_REL/uninstall.sh" ]
  [ "$(cat "$HOME/$DEST_REL/VERSION")" = "v1.1.0" ]
  [ "$(count_blocks "$HOME/.bashrc")" -eq 1 ]
  grep -qx 'export KEEP=1' "$HOME/.bashrc"
  ls "$HOME"/.bashrc.gw-suit.bak.* >/dev/null
  run bash -ic 'type gwclone >/dev/null && echo "$GW_SUIT_VERSION"' </dev/null
  [[ "$output" == *"1.1.0"* ]]
}

@test "block keeps \$HOME symbolic" {
  inst GW_SUIT_RC="$HOME/.bashrc"
  grep -qF '. "$HOME/.local/share/gw-suit/gw-suit.sh"' "$HOME/.bashrc"
}

@test "running twice: one block, no second backup, no state duplication" {
  inst GW_SUIT_RC="$HOME/.bashrc"
  inst GW_SUIT_RC="$HOME/.bashrc"
  [ "$status" -eq 0 ]
  [[ "$output" == *"already set up"* ]]
  [ "$(count_blocks "$HOME/.bashrc")" -eq 1 ]
  [ "$(ls "$HOME"/.bashrc.gw-suit.bak.* | wc -l)" -eq 1 ]
  [ "$(wc -l < "$HOME/$DEST_REL/state")" -eq 1 ]
}

@test "an outdated block is replaced in place; surrounding lines survive" {
  inst GW_SUIT_RC="$HOME/.bashrc"
  printf 'export AFTER=1\n' >> "$HOME/.bashrc"
  sed -i.x 's|^if \[ -f .*|echo old-line|' "$HOME/.bashrc" && rm -f "$HOME/.bashrc.x"
  inst GW_SUIT_RC="$HOME/.bashrc"
  [ "$status" -eq 0 ]
  [[ "$output" == *"updated the gw-suit block"* ]]
  ! grep -q old-line "$HOME/.bashrc"
  grep -qx 'export KEEP=1' "$HOME/.bashrc"
  grep -qx 'export AFTER=1' "$HOME/.bashrc"
  [ "$(count_blocks "$HOME/.bashrc")" -eq 1 ]
}

@test "dry run writes nothing" {
  inst GW_SUIT_RC="$HOME/.bashrc" GW_SUIT_DRY_RUN=1
  [ "$status" -eq 0 ]
  [[ "$output" == *"dry run"* ]]
  [ ! -e "$HOME/$DEST_REL" ]
  cmp "$HOME/.bashrc" "$TEST_TMP/bashrc.orig"
}

@test "tampered download fails the checksum and changes nothing" {
  echo 'echo pwned' >> "$REL/gw-suit.sh"
  inst GW_SUIT_RC="$HOME/.bashrc"
  [ "$status" -ne 0 ]
  [[ "$output" == *"checksum mismatch"* ]]
  [ ! -e "$HOME/$DEST_REL" ]
  cmp "$HOME/.bashrc" "$TEST_TMP/bashrc.orig"
}

@test "missing file on the server fails and changes nothing" {
  rm "$REL/uninstall.sh"
  inst GW_SUIT_RC="$HOME/.bashrc"
  [ "$status" -ne 0 ]
  [ ! -e "$HOME/$DEST_REL" ]
  cmp "$HOME/.bashrc" "$TEST_TMP/bashrc.orig"
}

@test "a truncated installer piped to bash changes nothing" {
  total="$(wc -c < "$REPO/install.sh")"
  for n in 300 1500 4000 $((total - 30)); do
    run bash -c "head -c $n '$REPO/install.sh' | GW_SUIT_BASE_URL='$BASE_URL' GW_SUIT_RC='$HOME/.bashrc' bash"
    [ ! -e "$HOME/$DEST_REL" ]
    cmp "$HOME/.bashrc" "$TEST_TMP/bashrc.orig"
  done
  run bash -c "sed '\$d' '$REPO/install.sh' | GW_SUIT_BASE_URL='$BASE_URL' GW_SUIT_RC='$HOME/.bashrc' bash"
  [ ! -e "$HOME/$DEST_REL" ]
}

@test "curl | bash style (script on stdin) installs" {
  run bash -c "cat '$REPO/install.sh' | GW_SUIT_BASE_URL='$BASE_URL' GW_SUIT_RC='$HOME/.bashrc' bash"
  [ "$status" -eq 0 ]
  [ "$(count_blocks "$HOME/.bashrc")" -eq 1 ]
}

@test "legacy helper line is reported and left alone" {
  mkdir -p "$HOME/.config/git"
  printf 'gwclone() { :; }\n' > "$HOME/.config/git/worktree-helpers.sh"
  printf 'source ~/.config/git/worktree-helpers.sh\n' >> "$HOME/.bashrc"
  inst GW_SUIT_RC="$HOME/.bashrc"
  [ "$status" -eq 0 ]
  [[ "$output" == *"line 2 sources"*"worktree-helpers.sh"* ]]
  grep -qx 'source ~/.config/git/worktree-helpers.sh' "$HOME/.bashrc"
}

@test "default rc selection: zsh login shell gets ~/.zshrc created" {
  rm -f "$HOME/.bashrc"
  inst SHELL=/bin/zsh
  [ "$status" -eq 0 ]
  [ "$(count_blocks "$HOME/.zshrc")" -eq 1 ]
  [ ! -e "$HOME/.bashrc" ]
}

@test "multiple rc files via GW_SUIT_RC" {
  inst GW_SUIT_RC="$HOME/.bashrc:~/.zshrc"
  [ "$status" -eq 0 ]
  [ "$(count_blocks "$HOME/.bashrc")" -eq 1 ]
  [ "$(count_blocks "$HOME/.zshrc")" -eq 1 ]
}

@test "zsh picks up the commands from ~/.zshrc" {
  command -v zsh >/dev/null || skip "zsh not installed"
  inst GW_SUIT_RC="$HOME/.zshrc"
  run zsh -ic 'whence -w gwclean' </dev/null
  [[ "$output" == *"function"* ]]
}

@test "Git Bash: warns when ~/.bash_profile does not source ~/.bashrc" {
  case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) ;; *) skip "Windows only" ;; esac
  printf 'export X=1\n' > "$HOME/.bash_profile"
  inst GW_SUIT_RC="$HOME/.bashrc"
  [[ "$output" == *"bash_profile does not source"* ]]
  [ "$(cat "$HOME/.bash_profile")" = "export X=1" ]
}

@test "default ref: verifies against the checksums built into install.sh (no SHA256SUMS download)" {
  rm "$REL/SHA256SUMS"
  inst GW_SUIT_RC="$HOME/.bashrc"
  [ "$status" -eq 0 ]
  [[ "$output" == *"checksums built into this installer"* ]]
}

@test "built-in checksums reject a release file that SHA256SUMS would accept" {
  echo '# changed' >> "$REL/gw-suit.sh"
  "$REPO/scripts/make-sums.sh" "$REL"
  inst GW_SUIT_RC="$HOME/.bashrc"
  [ "$status" -ne 0 ]
  [[ "$output" == *"checksum mismatch for gw-suit.sh"* ]]
  [ ! -e "$HOME/$DEST_REL" ]
}

@test "another ref: falls back to that ref's SHA256SUMS and warns" {
  inst GW_SUIT_RC="$HOME/.bashrc" GW_SUIT_REF=v0.9.9
  [ "$status" -eq 0 ]
  [[ "$output" == *"checking against SHA256SUMS from v0.9.9 only"* ]]
  [ "$(cat "$HOME/$DEST_REL/VERSION")" = "v0.9.9" ]
}

@test "built-in checksums match the repo files (run scripts/make-sums.sh after editing)" {
  cp "$REPO/install.sh" "$REPO/gw-suit.sh" "$REPO/uninstall.sh" "$TEST_TMP/"
  "$REPO/scripts/make-sums.sh" "$TEST_TMP"
  cmp "$TEST_TMP/install.sh" "$REPO/install.sh"
}
