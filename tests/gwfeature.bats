#!/usr/bin/env bats
load helpers

setup() { setup_common; make_origin main feature/sprint_16 release; clone_project; }

@test "gwfeature checks out a plain base without config" {
  cd "$PROJ/main"
  gw "gwfeature release"
  [ "$status" -eq 0 ]
  [ "$(git -C "$PROJ/release" branch --show-current)" = "release" ]
  [[ "$output" != *sprint* ]]
}

@test "gwfeature resolves sprint short forms with GW_BASE_PREFIX" {
  for form in 16 sprint_16; do
    rm -rf "${PROJ:?}/feature"; git -C "$PROJ" worktree prune
    cd "$PROJ/main"
    gw "GW_BASE_PREFIX=feature/sprint_ gwfeature $form"
    [ "$status" -eq 0 ]
    [ "$(git -C "$PROJ/feature/sprint_16" branch --show-current)" = "feature/sprint_16" ]
  done
}

@test "gwfeature cds into an existing worktree" {
  cd "$PROJ/main"
  gw "gwfeature release"
  gw "gwfeature release && pwd"
  [ "$status" -eq 0 ]
  [[ "$output" == *"already exists"* ]]
  [[ "${lines[${#lines[@]}-1]}" == */origin/release ]]
}

@test "gwfeature creates a tracking branch for an origin-only branch" {
  git -C "$TEST_TMP/origin.git" branch remote-only main
  cd "$PROJ/main"
  gw "gwfeature remote-only"
  [ "$status" -eq 0 ]
  [ "$(git -C "$PROJ/remote-only" rev-parse --abbrev-ref '@{u}')" = "origin/remote-only" ]
}

@test "gwfeature errors on a missing branch" {
  cd "$PROJ/main"
  gw "gwfeature nope"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not found"* ]]
}
