# Contributing to gw-suit

Thanks for helping. Bug reports, fixes and small improvements are all welcome.

## How changes get in

- `main` is protected: nobody pushes to it directly, including the maintainer. Every change is a **pull request**.
- A PR can be merged once **all CI checks pass** (shellcheck plus the test suite on Linux, macOS and Windows, in bash and zsh) and it has been reviewed.
- For anything bigger than a small fix, please open an issue first so we can agree on the approach before you write code.

Steps:

1. Fork the repo and create a branch from `main`.
2. Make your change, with tests (see below).
3. Run the checks locally.
4. Open a PR describing *what* changed and *why*. Link the issue if there is one.

## Licence of contributions

gw-suit is licensed under [PolyForm Noncommercial 1.0.0](LICENSE). By opening a pull request you agree that your contribution is licensed under the same terms, and that you have the right to contribute it.

## Repository layout

```
gw-suit.sh            the commands; sourced by the user's shell (bash and zsh)
install.sh            one-line installer (bash 3.2+)
uninstall.sh          uninstaller (bash 3.2+)
SHA256SUMS            checksums the installer verifies; generated, never hand-edited
scripts/make-sums.sh  regenerates SHA256SUMS
scripts/scrub-check.sh  checks for personal paths, e-mail addresses and identities
tests/                bats tests; helpers.bash builds throwaway repos, no network needed
.github/workflows/    CI
```

## Development setup

You need `git`, `bash`, [`bats-core`](https://github.com/bats-core/bats-core) and [`shellcheck`](https://www.shellcheck.net/). `zsh` is optional locally (CI runs it).

```bash
npm install -g bats            # or: brew install bats-core / apt install bats
brew install shellcheck        # or: apt install shellcheck / scoop install shellcheck
```

## Running the checks

```bash
shellcheck -s bash gw-suit.sh install.sh uninstall.sh scripts/*.sh tests/helpers.bash
bats tests/                    # bash
GW_TEST_SHELL=zsh bats tests/  # the same tests with the commands running in zsh
scripts/make-sums.sh && git diff --exit-code SHA256SUMS
scripts/scrub-check.sh
```

- **If you change `gw-suit.sh` or `uninstall.sh`, run `scripts/make-sums.sh` and commit the updated `SHA256SUMS`.** CI fails otherwise, because the installer would reject the files.
- `scrub-check.sh` fails if tracked files contain home-directory paths, e-mail addresses or IP addresses, or if a commit uses a non-noreply e-mail. Use [your GitHub noreply address](https://docs.github.com/en/account-and-profile/setting-up-and-managing-your-personal-account-on-github/managing-email-preferences/setting-your-commit-email-address) for commits to this repo: `git config user.email <id>+<user>@users.noreply.github.com`.

## Code conventions

**`gw-suit.sh`** is sourced into people's interactive shells, so:

- it must work in **bash 4+ and zsh 5.8+**: no arrays, `mapfile`, `${var^^}` or `[[ =~ ]]`; iterate lines with `while IFS= read -r`, never an unquoted `for x in $list` (zsh doesn't word-split);
- defining functions is its only side effect: no exported variables, no output on load;
- every variable inside a function is `local`; never name one `path` (zsh ties it to `PATH`);
- errors go to stderr as `<command>: <message>` followed by `return 1`, **never `exit`** (that would close the user's shell);
- public commands are `gw<verb>`; private helpers are `_gw_<name>`; shared logic goes in a helper, not copied between commands.

**`install.sh` / `uninstall.sh`** run via `curl | bash`, often on macOS's bash 3.2:

- no bash 4 features (no `${var,,}`, no associative arrays, no negative array indexes);
- all real work happens inside the function called on the last line, so a truncated download does nothing;
- never edit anything in an rc file outside the `# >>> gw-suit >>>` block; back up before every change;
- no `rm -rf` on a variable.

**Safety behaviour is part of the contract.** Changes that make a command more destructive (e.g. removing the dry-run default in `gwclean`, deleting unmerged branches, discarding uncommitted changes without `--force`) won't be accepted.

**Style:** two-space indent, a header comment on each function with its usage line, LF line endings (enforced by `.gitattributes`).

## Tests

- Each command has its own `tests/<command>.bats`; installer behaviour is in `install.bats` and `uninstall.bats`.
- Use the fixtures in `tests/helpers.bash` (`make_origin`, `clone_project`, `gw`, `make_release`, …). Tests use a throwaway `$HOME` and local repos only, so they never touch your real config or the network.
- Run commands through `gw "<shell code>"` so the same test covers bash and zsh.
- A bug fix should come with a test that fails without the fix.

## Releasing (maintainer)

1. Update `CHANGELOG.md` and `GW_SUIT_VERSION` in `gw-suit.sh`; bump `GWI_DEFAULT_REF` in `install.sh` and the version in the README install line.
2. `scripts/make-sums.sh`, then merge the PR.
3. Tag `vX.Y.Z` on `main`, push the tag, and create a GitHub release.
