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

@test "gwclone uses GW_ROOT, then PROJECTS_ROOT" {
  cd "$TEST_TMP"
  gw "GW_ROOT='$TEST_TMP/r1' PROJECTS_ROOT='$TEST_TMP/r2' gwclone '$ORIGIN' a"
  [ "$status" -eq 0 ]
  [ -d "$TEST_TMP/r1/a/main" ]
  gw "PROJECTS_ROOT='$TEST_TMP/r2' gwclone '$ORIGIN' b"
  [ "$status" -eq 0 ]
  [ -d "$TEST_TMP/r2/b/main" ]
}

@test "gwclone treats a dest containing / as a literal path (relative works)" {
  mkdir -p "$TEST_TMP/w" && cd "$TEST_TMP/w"
  gw "GW_ROOT='$TEST_TMP/ignored' gwclone '$ORIGIN' ../deep/x"
  [ "$status" -eq 0 ]
  [ -d "$TEST_TMP/deep/x/main" ]
  [ ! -e "$TEST_TMP/ignored" ]
}

@test "gwclone refuses an existing destination and a missing url" {
  cd "$TEST_TMP" && mkdir taken
  gw "gwclone '$ORIGIN' taken"
  [ "$status" -eq 1 ]
  [[ "$output" == *"destination exists"* ]]
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
  [ -d "$TEST_TMP/t/trunk" ]
}

@test "gwclone leaves no empty folder behind when the clone fails" {
  cd "$TEST_TMP"
  gw "gwclone '$TEST_TMP/nope.git' z"
  [ "$status" -ne 0 ]
  [ ! -e "$TEST_TMP/z" ]
}
