#!/usr/bin/env bash
# make-sums.sh [dir] — write SHA256SUMS for the files the installer downloads.
# Output format is fixed ("<hash>  <name>") so it is identical on Linux, macOS and Git Bash.
set -eu
dir="${1:-$(git rev-parse --show-toplevel)}"
cd "$dir"
sha() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
  else shasum -a 256 "$1" | cut -d' ' -f1; fi
}
: > SHA256SUMS
for f in gw-suit.sh uninstall.sh; do
  printf '%s  %s\n' "$(sha "$f")" "$f" >> SHA256SUMS
done
