#!/usr/bin/env bats
load helpers

setup() { setup_common; make_origin main feature/sprint_16; clone_project; }

@test "gwtask creates wip/<slug> from origin base without tracking" {
  cd "$PROJ/main"
  gw "gwtask main fix-login"
  [ "$status" -eq 0 ]
  [ "$(git -C "$PROJ/wip/fix-login" branch --show-current)" = "wip/fix-login" ]
  run git -C "$PROJ/wip/fix-login" rev-parse --abbrev-ref '@{u}'
  [ "$status" -ne 0 ]
}

@test "gwtask sprint config: 16 and sprint_16 use origin/feature/sprint_16" {
  cd "$PROJ/main"
  gw "GW_BASE_PREFIX=feature/sprint_ gwtask 16 a"
  [ "$status" -eq 0 ]
  [[ "$output" == *"from origin/feature/sprint_16"* ]]
  gw "GW_BASE_PREFIX=feature/sprint_ gwtask sprint_16 b"
  [ "$status" -eq 0 ]
  [[ "$output" == *"from origin/feature/sprint_16"* ]]
}

@test "gwtask honours GW_TASK_PREFIX" {
  cd "$PROJ/main"
  gw "GW_TASK_PREFIX=task/ gwtask main x"
  [ "$status" -eq 0 ]
  [ -d "$PROJ/task/x" ]
}

@test "gwtask rejects invalid names, existing branch/folder, missing base, bad flag" {
  cd "$PROJ/main"
  gw "gwtask main 'bad..name'"
  [ "$status" -eq 1 ]; [[ "$output" == *"invalid branch name"* ]]
  gw "gwtask main dup"
  gw "gwtask main dup"
  [ "$status" -eq 1 ]; [[ "$output" == *"already exists"* ]]
  mkdir -p "$PROJ/wip/folder"
  gw "gwtask main folder"
  [ "$status" -eq 1 ]; [[ "$output" == *"folder exists"* ]]
  gw "gwtask nope z"
  [ "$status" -eq 1 ]; [[ "$output" == *"not found"* ]]
  gw "gwtask main z --pish"
  [ "$status" -eq 1 ]; [[ "$output" == *"usage: gwtask"* ]]
}

@test "gwtask --push creates the branch on origin with upstream" {
  cd "$PROJ/main"
  gw "gwtask main pushed --push"
  [ "$status" -eq 0 ]
  git -C "$TEST_TMP/origin.git" show-ref --verify --quiet refs/heads/wip/pushed
  [ "$(git -C "$PROJ/wip/pushed" rev-parse --abbrev-ref '@{u}')" = "origin/wip/pushed" ]
}
