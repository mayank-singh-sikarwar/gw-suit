#!/usr/bin/env bats
load helpers

# Fixture: sprint base on origin; wip/a and wip/b merged into it, wip/open not merged.
setup() {
  setup_common
  make_origin main feature/sprint_16
  clone_project
  export GW_BASE_PREFIX=feature/sprint_
  cd "$PROJ/main"
  for s in a b open; do
    gw "gwtask 16 $s"; [ "$status" -eq 0 ]
  done
  commit_in "$PROJ/wip/a" a1
  commit_in "$PROJ/wip/b" b1
  commit_in "$PROJ/wip/open" o1
  # merge a and b into the sprint branch on origin
  git -C "$PROJ" push -q origin wip/a:feature/sprint_16
  git -C "$PROJ" push -q origin wip/b:refs/heads/tmp
  git -C "$TEST_TMP/src" fetch -q "$(native "$TEST_TMP/origin.git")" feature/sprint_16 tmp
  git -C "$TEST_TMP/src" checkout -q -b s FETCH_HEAD 2>/dev/null || true
  git -C "$TEST_TMP/src" checkout -q -B s "$(git -C "$TEST_TMP/origin.git" rev-parse feature/sprint_16)"
  git -C "$TEST_TMP/src" merge -q --no-edit "$(git -C "$TEST_TMP/origin.git" rev-parse tmp)"
  git -C "$TEST_TMP/src" push -q "$(native "$TEST_TMP/origin.git")" s:feature/sprint_16
  cd "$PROJ/main"
}

snapshot() { git -C "$PROJ" worktree list --porcelain; git -C "$PROJ" branch --list; }

@test "default is a dry run that changes nothing" {
  before="$(snapshot)"
  gw "gwclean 16"
  [ "$status" -eq 0 ]
  [[ "$output" == *"dry run"* ]]
  [[ "$output" == *"would delete branch: wip/a"* ]]
  [[ "$output" == *"would delete branch: wip/b"* ]]
  [[ "$output" != *"wip/open"* ]]
  [ "$before" = "$(snapshot)" ]
}

@test "--dry-run is accepted and still changes nothing" {
  before="$(snapshot)"
  gw "gwclean 16 --dry-run"
  [ "$status" -eq 0 ]
  [ "$before" = "$(snapshot)" ]
}

@test "--apply removes clean merged worktrees (several: zsh split regression) and keeps unmerged" {
  git -C "$PROJ" branch -q --set-upstream-to=origin/feature/sprint_16 wip/a
  git -C "$PROJ" branch -q --set-upstream-to=origin/feature/sprint_16 wip/b
  gw "gwclean 16 --apply"
  [ "$status" -eq 0 ]
  [ ! -e "$PROJ/wip/a" ]
  [ ! -e "$PROJ/wip/b" ]
  [ -d "$PROJ/wip/open" ]
  ! git -C "$PROJ" show-ref --verify --quiet refs/heads/wip/a
  ! git -C "$PROJ" show-ref --verify --quiet refs/heads/wip/b
  git -C "$PROJ" show-ref --verify --quiet refs/heads/wip/open
}

@test "--apply keeps a branch that git branch -d refuses; --force deletes it" {
  gw "gwclean 16 --apply"
  [ "$status" -eq 0 ]
  [ ! -e "$PROJ/wip/a" ]
  git -C "$PROJ" show-ref --verify --quiet refs/heads/wip/a
  [[ "$output" == *"branch kept"* ]]
  gw "gwclean 16 --apply --force"
  [ "$status" -eq 0 ]
  ! git -C "$PROJ" show-ref --verify --quiet refs/heads/wip/a
}

@test "dirty worktree is skipped by --apply, removed by --apply --force" {
  echo dirt > "$PROJ/wip/a/file.txt"
  gw "gwclean 16 --apply"
  [ "$status" -eq 0 ]
  [ -f "$PROJ/wip/a/file.txt" ]
  [[ "$output" == *"uncommitted changes"* ]]
  gw "gwclean 16 --apply --force"
  [ "$status" -eq 0 ]
  [ ! -e "$PROJ/wip/a" ]
}

@test "the current worktree is never removed" {
  cd "$PROJ/wip/a"
  gw "gwclean 16 --apply --force"
  [ -d "$PROJ/wip/a" ]
  [[ "$output" == *"current worktree"* ]]
}

@test "base is required (no hardcoded sprint); GW_CLEAN_TARGET works; missing base errors" {
  gw "gwclean"
  [ "$status" -eq 1 ]
  [[ "$output" == *"usage: gwclean"* ]]
  gw "GW_CLEAN_TARGET=16 gwclean"
  [ "$status" -eq 0 ]
  [[ "$output" == *"would delete branch: wip/a"* ]]
  gw "gwclean 99"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not found"* ]]
  gw "gwclean 16 --bogus"
  [ "$status" -eq 1 ]
}

@test "without config nothing about sprints is assumed" {
  unset GW_BASE_PREFIX
  gw "gwclean 16"
  [ "$status" -eq 1 ]
  [[ "$output" == *"base '16' not found"* ]]
}
