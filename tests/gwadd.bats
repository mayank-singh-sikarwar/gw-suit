#!/usr/bin/env bats
load helpers

setup() { setup_common; make_origin main dev; clone_project; }

@test "gwadd creates a new branch from the default branch as a sibling" {
  cd "$PROJ/main"
  gw "gwadd topic && pwd"
  [ "$status" -eq 0 ]
  [ -d "$PROJ/topic" ]
  [ "$(git -C "$PROJ/topic" branch --show-current)" = "topic" ]
}

@test "gwadd checks out an existing branch" {
  cd "$PROJ/main"
  gw "gwadd dev"
  [ "$status" -eq 0 ]
  [ "$(git -C "$PROJ/dev" branch --show-current)" = "dev" ]
}

@test "gwadd uses an explicit base" {
  commit_in "$PROJ/main" extra
  cd "$PROJ/main"
  gw "gwadd t2 dev"
  [ "$status" -eq 0 ]
  [ "$(git -C "$PROJ/t2" rev-parse HEAD)" = "$(git -C "$PROJ" rev-parse dev)" ]
}

@test "gwadd errors outside a .bare project and without args" {
  cd "$TEST_TMP" && git init -q plain && cd plain
  gw "gwadd x"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not a .bare worktree project"* ]]
  gw "gwadd"
  [ "$status" -eq 1 ]
  [[ "$output" == *"usage: gwadd"* ]]
}
