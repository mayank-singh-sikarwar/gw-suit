#!/usr/bin/env bash
# scrub-check.sh — fail if tracked (index) content or commit metadata leaks personal details.
#   Scans the git index (what would be committed), not the working tree.
#   Generic patterns live here; personal terms live in an optional, never-tracked
#   .scrub-denylist (one fixed string per line, case-insensitive).
set -u

root="$(git rev-parse --show-toplevel)" || exit 2
cd "$root" || exit 2
fail=0
self=':(exclude)scripts/scrub-check.sh'

report() { printf 'scrub: %s\n' "$1" >&2; fail=1; }

# 1. Planning artifacts must never be tracked.
if git ls-files --cached | grep -Eq '^(SPEC\.md|tasks/|\.scrub-denylist$)'; then
  report "local-only file is tracked/staged:"
  git ls-files --cached | grep -E '^(SPEC\.md|tasks/|\.scrub-denylist$)' >&2
fi

# 2. Generic patterns: user home paths, email addresses, IPv4 addresses.
generic='([A-Za-z]:[\\/]+Users[\\/]|/c/Users/|/home/[a-z][a-z0-9_-]+|/Users/[A-Za-z][A-Za-z0-9_-]+/|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}|\b([0-9]{1,3}\.){3}[0-9]{1,3}\b)'
allow='(users\.noreply\.github\.com|noreply@github\.com|/home/runner|127\.0\.0\.1|0\.0\.0\.0)'
hits="$(git grep --cached -I -n -E "$generic" -- . "$self" 2>/dev/null | grep -Ev "$allow")"
[ -n "$hits" ] && { report "generic pattern match:"; printf '%s\n' "$hits" >&2; }

# 3. Personal denylist (local only).
if [ -s .scrub-denylist ]; then
  hits="$(git grep --cached -I -n -i -F -f .scrub-denylist -- . "$self" 2>/dev/null)"
  [ -n "$hits" ] && { report "denylist match:"; printf '%s\n' "$hits" >&2; }
fi

# 4. Commit metadata: every author/committer email must be a GitHub noreply address.
if git rev-parse --verify -q HEAD >/dev/null; then
  bad="$(git log --all --format='%an <%ae> | %cn <%ce>' | tr '|' '\n' |
         sed 's/^ *//' | grep -Ev '<([0-9]+\+)?[^@<>]+@users\.noreply\.github\.com>$|<noreply@github\.com>$' | sort -u)"
  [ -n "$bad" ] && { report "non-noreply identity in history:"; printf '%s\n' "$bad" >&2; }
fi

# 5. Identity that the next commit would use.
email="$(git config user.email || true)"
case "$email" in
  *@users.noreply.github.com) ;;
  *) report "git user.email is not a GitHub noreply address" ;;
esac

[ "$fail" -eq 0 ] && echo "scrub: clean"
exit "$fail"
