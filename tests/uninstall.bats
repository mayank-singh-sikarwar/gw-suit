#!/usr/bin/env bats
load helpers

setup() { setup_common; make_release; }

# roundtrip <printf-format> -> install + uninstall, assert the rc file is byte-identical
roundtrip() {
  # shellcheck disable=SC2059
  printf "$1" > "$HOME/.bashrc"
  cp "$HOME/.bashrc" "$TEST_TMP/orig"
  inst GW_SUIT_RC="$HOME/.bashrc"
  [ "$status" -eq 0 ]
  [ "$(count_blocks "$HOME/.bashrc")" -eq 1 ]
  uninst
  [ "$status" -eq 0 ]
  cmp "$HOME/.bashrc" "$TEST_TMP/orig"
  [ ! -e "$HOME/$DEST_REL" ]
}

@test "roundtrip is byte-identical: file ending with a newline" { roundtrip 'a=1\nb=2\n'; }
@test "roundtrip is byte-identical: file without a trailing newline" { roundtrip 'a=1\nb=2'; }
@test "roundtrip is byte-identical: empty file" { roundtrip ''; }
@test "roundtrip is byte-identical: CRLF file" { roundtrip 'a=1\r\nb=2\r\n'; }

@test "an rc file the installer created is removed again" {
  inst GW_SUIT_RC="$HOME/.zshrc"
  [ -f "$HOME/.zshrc" ]
  uninst
  [ ! -e "$HOME/.zshrc" ]
}

@test "lines the user added after the block survive" {
  printf 'a=1\n' > "$HOME/.bashrc"
  inst GW_SUIT_RC="$HOME/.bashrc"
  printf 'export GW_BASE_PREFIX=feature/sprint_\n' >> "$HOME/.bashrc"
  uninst
  [ "$(cat "$HOME/.bashrc")" = "$(printf 'a=1\nexport GW_BASE_PREFIX=feature/sprint_')" ]
}

@test "uninstall twice: second run is a no-op that exits 0" {
  printf 'a=1\n' > "$HOME/.bashrc"
  inst GW_SUIT_RC="$HOME/.bashrc"
  uninst
  uninst
  [ "$status" -eq 0 ]
  [[ "$output" == *"nothing to uninstall"* ]]
}

@test "dry run changes nothing" {
  printf 'a=1\n' > "$HOME/.bashrc"
  inst GW_SUIT_RC="$HOME/.bashrc"
  cp "$HOME/.bashrc" "$TEST_TMP/installed"
  uninst GW_SUIT_DRY_RUN=1
  [ "$status" -eq 0 ]
  cmp "$HOME/.bashrc" "$TEST_TMP/installed"
  [ -d "$HOME/$DEST_REL" ]
}

@test "the installed copy can uninstall itself" {
  printf 'a=1\n' > "$HOME/.bashrc"
  inst GW_SUIT_RC="$HOME/.bashrc"
  run bash "$HOME/$DEST_REL/uninstall.sh"
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/$DEST_REL" ]
  [ "$(cat "$HOME/.bashrc")" = "a=1" ]
}

@test "files the user put in the install folder are kept" {
  printf 'a=1\n' > "$HOME/.bashrc"
  inst GW_SUIT_RC="$HOME/.bashrc"
  echo mine > "$HOME/$DEST_REL/notes.txt"
  uninst
  [ "$status" -eq 0 ]
  [ -f "$HOME/$DEST_REL/notes.txt" ]
  [[ "$output" == *"left in place"* ]]
}
