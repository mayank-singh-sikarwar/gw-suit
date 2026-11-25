# Changelog

All notable changes to this project are listed here. Versions follow [Semantic Versioning](https://semver.org/).

## [1.0.0] - 2026-11-25

First public release. It packages a set of personal git worktree helpers.

### Added
- Commands for the bare-repo worktree layout: `gwclone`, `gwadd`, `gwfeature`, `gwtask` and `gwclean`. They work in bash and zsh.
- A one-line installer. It checks each download against a SHA-256 checksum, backs up your rc file and adds one marked block to it. You can run it again safely. If the download is cut short, it does nothing.
- An uninstaller. It removes the block and leaves your rc file exactly as it was before.
- Settings: `GW_ROOT`, `GW_BASE_PREFIX`, `GW_TASK_PREFIX` and `GW_CLEAN_TARGET`.
- Release files are signed with build provenance. The README explains how to verify them before you install.
- Tests (bats) on Linux, macOS and Windows (Git Bash), in bash and zsh.

### Changed from the original helpers
- `gwclean` only shows what it would do. Add `--apply` to make the changes.
- `gwclean` only deletes branches whose commits are all in the base branch. It prints a command to restore each one.
- `gwclean` skips worktrees with uncommitted changes unless you add `--force`. It never removes the worktree you are in.
- `gwclean` has no built-in sprint number. Pass a base branch or set `GW_CLEAN_TARGET`.
- Sprint names are no longer built in. `gwtask`, `gwfeature` and `gwclean` take any base branch. Set `GW_BASE_PREFIX` to use short sprint numbers.
- `gwclone` was rewritten. It clones into the current folder (or `GW_ROOT`) instead of `~/worktrees`. It accepts a destination path, and it cleans up if the clone fails.
- `gwfeature` creates a local tracking branch for a branch that exists only on the remote. Before, the worktree was left on a detached HEAD.
- `gwadd` now refuses to run outside a bare-layout project.
- `PROJECTS_ROOT` is no longer exported. It is still read if you set it.
