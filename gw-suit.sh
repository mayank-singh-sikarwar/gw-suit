# gw-suit: git worktree helpers for the bare-repo layout.
# Source this file from ~/.bashrc or ~/.zshrc (the installer does it for you).
# Works in bash >= 4 and zsh >= 5.8. Defines functions only.
#
# Config (all optional):
#   GW_ROOT          parent folder for gwclone (default: $PROJECTS_ROOT, else $PWD)
#   GW_BASE_PREFIX   prefix for short base names, e.g. "feature/sprint_" (default: none)
#   GW_TASK_PREFIX   branch/folder prefix for gwtask/gwclean (default: "wip/")
#   GW_CLEAN_TARGET  default base for gwclean

# shellcheck disable=SC2034  # read by users and the installer
GW_SUIT_VERSION="1.0.0"

# ---------------------------------------------------------------- helpers ----

_gw_err() { printf '%s\n' "$*" >&2; }

# _gw_root [cmd] -> absolute root of the .bare project containing $PWD
_gw_root() {
  local cmd="${1:-gw}" common
  common="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" ||
    { _gw_err "$cmd: not inside a git project"; return 1; }
  case "$common" in
    */.bare) printf '%s\n' "${common%/.bare}" ;;
    *) _gw_err "$cmd: not a .bare worktree project ($common)"; return 1 ;;
  esac
}

# _gw_base_name <arg> -> branch name, applying GW_BASE_PREFIX once
#   origin/x -> x;  with GW_BASE_PREFIX=feature/sprint_:  16 | sprint_16 | feature/sprint_16 -> feature/sprint_16
_gw_base_name() {
  local arg="${1:-}" prefix="${GW_BASE_PREFIX:-}" seg
  case "$arg" in
    origin/*) printf '%s\n' "${arg#origin/}"; return 0 ;;
  esac
  if [ -n "$prefix" ]; then
    case "$arg" in
      "$prefix"*) ;;
      *)
        seg="${prefix##*/}"
        if [ -n "$seg" ] && [ "${arg#"$seg"}" != "$arg" ]; then
          arg="${arg#"$seg"}"
        fi
        arg="$prefix$arg"
        ;;
    esac
  fi
  printf '%s\n' "$arg"
}

# _gw_base_ref <root> <arg> -> origin/<name> if it exists, else local <name>; fails if neither
_gw_base_ref() {
  local root="$1" name
  name="$(_gw_base_name "${2:-}")"
  if git -C "$root" show-ref --verify --quiet "refs/remotes/origin/$name"; then
    printf 'origin/%s\n' "$name"
  elif git -C "$root" show-ref --verify --quiet "refs/heads/$name"; then
    printf '%s\n' "$name"
  else
    return 1
  fi
}

# _gw_has_branch <root> <name> -> true if a local or origin branch exists
_gw_has_branch() {
  git -C "$1" show-ref --verify --quiet "refs/heads/$2" ||
    git -C "$1" show-ref --verify --quiet "refs/remotes/origin/$2"
}

# _gw_wt_path <root> <branch> -> path of the worktree that has <branch> checked out (empty if none)
_gw_wt_path() {
  git -C "$1" worktree list --porcelain |
    awk -v ref="branch refs/heads/$2" '/^worktree /{p=substr($0,10)} $0==ref{print p; exit}'
}

# _gw_repo_name <url> -> last path segment without trailing "/" or ".git"
_gw_repo_name() {
  local s="${1%/}"
  s="${s##*/}"
  s="${s##*:}"
  printf '%s\n' "${s%.git}"
}

# --------------------------------------------------------------- commands ----

# gwclone <url> [dest]
#   Clone <url> into the bare layout <dest>/{.bare,.git,<default-branch>/}.
#   dest: a name (placed under $GW_ROOT, else $PROJECTS_ROOT, else $PWD) or any path containing "/".
gwclone() {
  local url="${1:-}" dest="${2:-}" name parent def
  [ -n "$url" ] || { _gw_err "usage: gwclone <url> [dest]"; return 1; }
  name="$(_gw_repo_name "$url")"
  [ -n "$name" ] || { _gw_err "gwclone: cannot derive a project name from: $url"; return 1; }
  parent="${GW_ROOT:-${PROJECTS_ROOT:-$PWD}}"
  case "$dest" in
    "") dest="$parent/$name" ;;
    */*) ;;
    *) dest="$parent/$dest" ;;
  esac
  [ -e "$dest" ] && { _gw_err "gwclone: destination exists: $dest"; return 1; }
  mkdir -p "$dest" && dest="$(cd "$dest" && pwd)" || return 1

  if ! git clone --bare --quiet "$url" "$dest/.bare"; then
    rmdir "$dest" 2>/dev/null
    return 1
  fi
  printf 'gitdir: ./.bare\n' > "$dest/.git"
  git -C "$dest" config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
  git -C "$dest" config worktree.useRelativePaths true   # ignored before git 2.48
  git -C "$dest" fetch --quiet origin || return 1
  git -C "$dest" remote set-head origin --auto >/dev/null 2>&1

  def="$(git -C "$dest" symbolic-ref --quiet --short refs/remotes/origin/HEAD)"
  def="${def#origin/}"
  [ -n "$def" ] || { _gw_err "gwclone: could not determine the default branch"; return 1; }
  git -C "$dest" worktree add --quiet "$dest/$def" "$def" || return 1
  git -C "$dest" branch --quiet --set-upstream-to="origin/$def" "$def"
  cd "$dest/$def" || return 1
  echo "Ready: $dest/$def"
}

# gwadd <branch> [base]
#   New sibling worktree <root>/<branch>. Checks out <branch> if it exists locally or on origin,
#   otherwise creates it from [base] (default: origin's default branch).
gwadd() {
  local branch="${1:-}" base="${2:-}" root
  [ -n "$branch" ] || { _gw_err "usage: gwadd <branch> [base]"; return 1; }
  root="$(_gw_root gwadd)" || return 1
  [ -e "$root/$branch" ] && { _gw_err "gwadd: folder exists: $root/$branch"; return 1; }
  if [ -z "$base" ]; then
    base="$(git -C "$root" symbolic-ref --quiet --short refs/remotes/origin/HEAD)"
    base="${base#origin/}"
  fi
  if _gw_has_branch "$root" "$branch"; then
    git -C "$root" worktree add --quiet "$root/$branch" "$branch" || return 1
  else
    git -C "$root" worktree add --quiet -b "$branch" "$root/$branch" "$base" || return 1
  fi
  cd "$root/$branch" || return 1
  echo "Ready: $root/$branch"
}

# gwfeature <base>
#   Check out the base branch (see GW_BASE_PREFIX) as a worktree at <root>/<branch>,
#   or cd into it if it already exists.
gwfeature() {
  local arg="${1:-}" root name dir
  [ -n "$arg" ] || { _gw_err "usage: gwfeature <base>"; return 1; }
  root="$(_gw_root gwfeature)" || return 1
  name="$(_gw_base_name "$arg")"
  dir="$root/$name"
  if [ -e "$dir" ]; then
    echo "Worktree already exists: $dir"
    cd "$dir" || return 1
    return 0
  fi
  git -C "$root" fetch --quiet origin || return 1
  if git -C "$root" show-ref --verify --quiet "refs/heads/$name"; then
    git -C "$root" worktree add --quiet "$dir" "$name" || return 1
  elif git -C "$root" show-ref --verify --quiet "refs/remotes/origin/$name"; then
    git -C "$root" worktree add --quiet --track -b "$name" "$dir" "origin/$name" || return 1
  else
    _gw_err "gwfeature: branch '$name' not found locally or on origin"; return 1
  fi
  cd "$dir" || return 1
  echo "Ready: $dir"
  echo "Branch: $(git status -sb | head -1 | sed 's/^## //')"
}

# gwtask <base> <slug> [--push]
#   New ${GW_TASK_PREFIX:-wip/}<slug> branch + worktree from the base (origin preferred).
#   --push also creates the branch on origin now.
gwtask() {
  local arg="${1:-}" slug="${2:-}" push="${3:-}" root b dir base
  if [ -z "$arg" ] || [ -z "$slug" ] || { [ -n "$push" ] && [ "$push" != "--push" ]; }; then
    _gw_err "usage: gwtask <base> <slug> [--push]"; return 1
  fi
  root="$(_gw_root gwtask)" || return 1
  b="${GW_TASK_PREFIX:-wip/}$slug"
  dir="$root/$b"
  git check-ref-format --branch "$b" >/dev/null 2>&1 ||
    { _gw_err "gwtask: invalid branch name: $b"; return 1; }
  git -C "$root" show-ref --verify --quiet "refs/heads/$b" &&
    { _gw_err "gwtask: branch $b already exists (git worktree list to find it)"; return 1; }
  [ -e "$dir" ] && { _gw_err "gwtask: folder exists: $dir"; return 1; }

  git -C "$root" fetch --quiet origin || return 1
  base="$(_gw_base_ref "$root" "$arg")" ||
    { _gw_err "gwtask: base '$(_gw_base_name "$arg")' not found on origin or locally"; return 1; }

  git -C "$root" worktree add --quiet --no-track -b "$b" "$dir" "$base" || return 1
  cd "$dir" || return 1
  if [ "$push" = "--push" ]; then
    git push --quiet -u origin "$b" || return 1
  fi
  echo "Ready: $dir (from $base)"
  echo "Branch: $(git status -sb | head -1 | sed 's/^## //')"
  [ "$push" = "--push" ] || echo "First push: git push -u origin $b"
}

# gwclean [base] [--apply] [--force]
#   Clean up ${GW_TASK_PREFIX:-wip/}* branches merged into the base (default: $GW_CLEAN_TARGET).
#   Dry run unless --apply. Skips dirty worktrees and branches `git branch -d` refuses,
#   unless --force. Never removes the worktree you are standing in.
gwclean() {
  local arg="" apply=0 force=0 opt root cur base taskp list b dir out
  local removed=0 skipped=0 failed=0
  for opt in "$@"; do
    case "$opt" in
      --apply) apply=1 ;;
      --force) force=1 ;;
      --dry-run) ;;
      -*) _gw_err "usage: gwclean [base] [--apply] [--force]"; return 1 ;;
      *)
        [ -z "$arg" ] || { _gw_err "usage: gwclean [base] [--apply] [--force]"; return 1; }
        arg="$opt"
        ;;
    esac
  done
  [ -n "$arg" ] || arg="${GW_CLEAN_TARGET:-}"
  [ -n "$arg" ] || { _gw_err "usage: gwclean [base] [--apply] [--force]  (or set GW_CLEAN_TARGET)"; return 1; }

  root="$(_gw_root gwclean)" || return 1
  cur="$(git rev-parse --path-format=absolute --show-toplevel 2>/dev/null)"
  cd "$root" || return 1   # avoid holding a worktree open (Windows file locks)

  git -C "$root" fetch --quiet --prune origin || return 1
  base="$(_gw_base_ref "$root" "$arg")" ||
    { _gw_err "gwclean: base '$(_gw_base_name "$arg")' not found"; return 1; }
  taskp="${GW_TASK_PREFIX:-wip/}"

  [ "$apply" -eq 1 ] || echo "gwclean: dry run, nothing will change (pass --apply to act)"
  echo "Checking ${taskp}* branches merged into $base..."
  list="$(git -C "$root" for-each-ref --format='%(refname:short)' --merged "$base" refs/heads/)"

  while IFS= read -r b; do
    case "$b" in
      "$taskp"*) ;;
      *) continue ;;
    esac
    dir="$(_gw_wt_path "$root" "$b" </dev/null)"
    if [ -n "$dir" ]; then
      if [ "$dir" = "$cur" ]; then
        echo "skip  $b: it is the current worktree"; skipped=$((skipped + 1)); continue
      fi
      if [ "$force" -eq 0 ] && [ -n "$(git -C "$dir" status --porcelain </dev/null 2>/dev/null)" ]; then
        echo "skip  $b: uncommitted changes in $dir (--force to discard)"; skipped=$((skipped + 1)); continue
      fi
    fi
    if [ "$apply" -eq 0 ]; then
      [ -n "$dir" ] && echo "[dry-run] would remove worktree: $dir"
      echo "[dry-run] would delete branch: $b"; removed=$((removed + 1))
      continue
    fi
    if [ -n "$dir" ]; then
      if [ "$force" -eq 1 ]; then
        out="$(git -C "$root" worktree remove --force "$dir" </dev/null 2>&1)"
      else
        out="$(git -C "$root" worktree remove "$dir" </dev/null 2>&1)"
      fi || { echo "FAIL  $b: could not remove $dir: $out"; failed=$((failed + 1)); continue; }
      echo "removed worktree: $dir"
    fi
    if git -C "$root" branch -d "$b" </dev/null >/dev/null 2>&1; then
      echo "deleted branch: $b"; removed=$((removed + 1))
    elif [ "$force" -eq 1 ] && git -C "$root" branch -D "$b" </dev/null >/dev/null 2>&1; then
      echo "deleted branch (forced, merged into $base): $b"; removed=$((removed + 1))
    else
      echo "skip  $b: branch kept, git branch -d refused (not merged into HEAD/upstream; --force to delete)"
      skipped=$((skipped + 1))
    fi
  done <<EOF_GW
$list
EOF_GW

  [ "$apply" -eq 1 ] && git -C "$root" worktree prune
  echo "gwclean: $([ "$apply" -eq 1 ] && echo removed || echo would-remove) $removed, skipped $skipped, failed $failed"
  [ "$failed" -eq 0 ]
}
