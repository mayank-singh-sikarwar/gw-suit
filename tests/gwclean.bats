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
  o="$(native "$TEST_TMP/origin.git")"
  git -C "$TEST_TMP/src" fetch -q "$o" '+refs/heads/*:refs/remotes/o/*'
  git -C "$TEST_TMP/src" checkout -q -B s o/feature/sprint_16
  git -C "$TEST_TMP/src" merge -q --no-edit o/tmp
  git -C "$TEST_TMP/src" push -q "$o" s:feature/sprint_16
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

@test "--apply removes clean merged worktrees and branches (several: zsh split regression), keeps unmerged" {
  gw "gwclean 16 --apply"
  [ "$status" -eq 0 ]
  [ ! -e "$PROJ/wip/a" ]
  [ ! -e "$PROJ/wip/b" ]
  [ -d "$PROJ/wip/open" ]
  ! git -C "$PROJ" show-ref --verify --quiet refs/heads/wip/a
  ! git -C "$PROJ" show-ref --verify --quiet refs/heads/wip/b
  git -C "$PROJ" show-ref --verify --quiet refs/heads/wip/open
}

@test "--apply deletes merged branches with no upstream or a deleted upstream (no --force needed)" {
  # wip/a: pushed, then remote branch deleted (GitHub auto-delete after PR merge)
  git -C "$PROJ/wip/a" push -q -u origin wip/a
  git -C "$TEST_TMP/origin.git" branch -q -D wip/a
  # wip/b: never pushed (no upstream); neither is merged into main/HEAD
  gw "gwclean 16 --apply"
  [ "$status" -eq 0 ]
  ! git -C "$PROJ" show-ref --verify --quiet refs/heads/wip/a
  ! git -C "$PROJ" show-ref --verify --quiet refs/heads/wip/b
  [[ "$output" != *"--force"* ]]
}

@test "--apply prints a restore command that brings the branch back" {
  sha="$(git -C "$PROJ" rev-parse --short wip/a)"
  gw "gwclean 16 --apply"
  [[ "$output" == *"deleted branch: wip/a (was $sha; restore: git branch wip/a $sha)"* ]]
  git -C "$PROJ" branch wip/a "$sha"
  [ "$(git -C "$PROJ" rev-parse --short wip/a)" = "$sha" ]
}

@test "dry run lists the commit id of each branch" {
  sha="$(git -C "$PROJ" rev-parse --short wip/b)"
  gw "gwclean 16"
  [[ "$output" == *"would delete branch: wip/b ($sha)"* ]]
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
