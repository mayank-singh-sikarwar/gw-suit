#!/usr/bin/env bats
load helpers

setup() { setup_common; }

@test "sources cleanly with set -u and defines only gw functions" {
  if [ "$GW_TEST_SHELL" = zsh ]; then
    run zsh -fc 'set -u; b=(${(k)functions}); . "$1"; print -l ${(k)functions:|b}' _ "$GW_SRC"
  else
    run bash --norc -c 'set -u; b="$(compgen -A function)"; . "$1"; compgen -A function | grep -vxF "$b" || true' _ "$GW_SRC"
  fi
  [ "$status" -eq 0 ]
  for f in $output; do
    case "$f" in gw*|_gw_*) ;; *) echo "unexpected function: $f"; false ;; esac
  done
}

@test "GW_SUIT_VERSION is set and PROJECTS_ROOT is not exported" {
  gw 'echo "$GW_SUIT_VERSION"; env | grep -c "^PROJECTS_ROOT=" || true'
  [ "${lines[0]}" = "1.1.0" ]
  [ "${lines[1]}" = "0" ]
}

@test "_gw_base_name without prefix" {
  gw '_gw_base_name main; _gw_base_name origin/dev; _gw_base_name 16'
  [ "${lines[0]}" = "main" ]
  [ "${lines[1]}" = "dev" ]
  [ "${lines[2]}" = "16" ]
}

@test "_gw_base_name with sprint prefix resolves all forms once" {
  gw 'GW_BASE_PREFIX=feature/sprint_; _gw_base_name 16; _gw_base_name sprint_16; _gw_base_name feature/sprint_16; _gw_base_name origin/x'
  [ "${lines[0]}" = "feature/sprint_16" ]
  [ "${lines[1]}" = "feature/sprint_16" ]
  [ "${lines[2]}" = "feature/sprint_16" ]
  [ "${lines[3]}" = "x" ]
}

@test "_gw_root fails outside git and outside a .bare project" {
  cd "$TEST_TMP"
  gw '_gw_root t'
  [ "$status" -eq 1 ]
  [[ "$output" == *"not inside a git project"* ]]
  git init -q plain && cd plain
  gw '_gw_root t'
  [ "$status" -eq 1 ]
  [[ "$output" == *"not a .bare worktree project"* ]]
}

@test "_gw_repo_name handles urls, scp form, trailing slash and .git" {
  gw '_gw_repo_name https://h/o/r.git; _gw_repo_name git@h:o/r.git; _gw_repo_name git@h:r; _gw_repo_name /x/r/'
  [ "${lines[0]}" = "r" ]
  [ "${lines[1]}" = "r" ]
  [ "${lines[2]}" = "r" ]
  [ "${lines[3]}" = "r" ]
}
