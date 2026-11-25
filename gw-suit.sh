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
