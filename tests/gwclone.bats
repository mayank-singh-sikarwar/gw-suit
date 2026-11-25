#!/usr/bin/env bats
load helpers

setup() { setup_common; make_origin main dev; }

@test "gwclone defaults to \$PWD/<repo> and builds the bare layout" {
  mkdir -p "$TEST_TMP/here" && cd "$TEST_TMP/here"
  gw "gwclone '$ORIGIN' && pwd"
  [ "$status" -eq 0 ]
  [ -d "$TEST_TMP/here/origin/.bare" ]
  [ "$(cat "$TEST_TMP/here/origin/.git")" = "gitdir: ./.bare" ]
  [ -d "$TEST_TMP/here/origin/main" ]
  [ "$(git -C "$TEST_TMP/here/origin/main" rev-parse --abbrev-ref '@{u}')" = "origin/main" ]
  [ "$(git -C "$TEST_TMP/here/origin" config remote.origin.fetch)" = "+refs/heads/*:refs/remotes/origin/*" ]
  [[ "${lines[${#lines[@]}-1]}" == */here/origin/main ]]
}

@test "gwclone puts projects in GW_ROOT, then PROJECTS_ROOT" {
  cd "$TEST_TMP"
  gw "GW_ROOT='$TEST_TMP/r1' PROJECTS_ROOT='$TEST_TMP/r2' gwclone '$ORIGIN'"
  [ "$status" -eq 0 ]
  [ -d "$TEST_TMP/r1/origin/main" ]
  gw "PROJECTS_ROOT='$TEST_TMP/r2' gwclone '$ORIGIN'"
  [ "$status" -eq 0 ]
  [ -d "$TEST_TMP/r2/origin/main" ]
}

@test "gwclone: a relative folder goes under GW_ROOT and keeps the repo name" {
  cd "$TEST_TMP"
  gw "GW_ROOT='$TEST_TMP/root' gwclone '$ORIGIN' phd/code"
  [ "$status" -eq 0 ]
  [ -d "$TEST_TMP/root/phd/code/origin/main" ]
  [[ "${lines[${#lines[@]}-1]}" == */root/phd/code/origin/main ]]
}

@test "gwclone: a relative folder without GW_ROOT goes under the current folder" {
  mkdir -p "$TEST_TMP/w" && cd "$TEST_TMP/w"
  gw "gwclone '$ORIGIN' code"
  [ "$status" -eq 0 ]
  [ -d "$TEST_TMP/w/code/origin/main" ]
}

@test "gwclone: an absolute folder is used as it is, even with GW_ROOT set" {
  cd "$TEST_TMP"
  gw "GW_ROOT='$TEST_TMP/ignored' gwclone '$ORIGIN' '$TEST_TMP/deep/x'"
  [ "$status" -eq 0 ]
  [ -d "$TEST_TMP/deep/x/origin/main" ]
  [ ! -e "$TEST_TMP/ignored" ]
}

@test "gwclone: an existing folder is fine, an existing project is refused" {
  mkdir -p "$TEST_TMP/existing/other"
  cd "$TEST_TMP"
  gw "gwclone '$ORIGIN' existing"
  [ "$status" -eq 0 ]
  [ -d "$TEST_TMP/existing/origin/main" ]
  [ -d "$TEST_TMP/existing/other" ]
  gw "gwclone '$ORIGIN' existing"
  [ "$status" -eq 1 ]
  [[ "$output" == *"destination exists"* ]]
}

@test "gwclone refuses a missing url" {
  gw "gwclone"
  [ "$status" -eq 1 ]
  [[ "$output" == *"usage: gwclone"* ]]
}

@test "gwclone follows a non-main default branch" {
  rm -rf "$TEST_TMP/src" "$TEST_TMP/origin.git"
  make_origin trunk
  cd "$TEST_TMP"
  gw "gwclone '$ORIGIN' t"
  [ "$status" -eq 0 ]
  [ -d "$TEST_TMP/t/origin/trunk" ]
}

@test "gwclone leaves no new folders behind when the clone fails" {
  mkdir -p "$TEST_TMP/keep"
  cd "$TEST_TMP"
  gw "gwclone '$TEST_TMP/nope.git' a/b"
  [ "$status" -ne 0 ]
  [ ! -e "$TEST_TMP/a" ]
  gw "gwclone '$TEST_TMP/nope.git' keep"
  [ "$status" -ne 0 ]
  [ -d "$TEST_TMP/keep" ]
  [ ! -e "$TEST_TMP/keep/nope" ]
}
