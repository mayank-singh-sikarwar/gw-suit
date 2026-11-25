#!/usr/bin/env bash
# make-sums.sh [dir] — regenerate the release checksums.
#   1. Embeds the SHA-256 of gw-suit.sh and uninstall.sh into install.sh (GWI_SUMS block),
#      so a verified install.sh vouches for everything it downloads.
#   2. Writes SHA256SUMS for gw-suit.sh, uninstall.sh and install.sh (for manual checks).
# Output format is fixed ("<hash>  <name>") so it is identical on Linux, macOS and Git Bash.
set -eu
dir="${1:-$(git rev-parse --show-toplevel)}"
cd "$dir"

sha() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
  else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

sums="$(printf '%s  %s\n%s  %s' "$(sha gw-suit.sh)" gw-suit.sh "$(sha uninstall.sh)" uninstall.sh)"

if [ -f install.sh ]; then
  grep -q '^# >>> sums >>>' install.sh || { echo "make-sums: no sums block in install.sh" >&2; exit 1; }
  # passed via the environment: BSD awk rejects newlines in -v values
  GW_SUMS="$sums" awk '
    /^# >>> sums >>>/ { print; print "GWI_SUMS='\''" ENVIRON["GW_SUMS"] "'\''"; skip = 1; next }
    /^# <<< sums <<</ { skip = 0 }
    !skip { print }' install.sh > install.sh.tmp
  cat install.sh.tmp > install.sh   # keep file mode
  rm -f install.sh.tmp
fi

: > SHA256SUMS
for f in gw-suit.sh uninstall.sh install.sh; do
  if [ -f "$f" ]; then
    printf '%s  %s\n' "$(sha "$f")" "$f" >> SHA256SUMS
  fi
done
