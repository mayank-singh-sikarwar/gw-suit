# Changelog

All notable changes to this project are documented here. Versions follow [Semantic Versioning](https://semver.org/).

## [1.0.0] - unreleased

First public release, packaging a set of personal worktree helpers.

### Added
- `gwclone`, `gwadd`, `gwfeature`, `gwtask`, `gwclean` for the bare-repo worktree layout, in bash and zsh.
- One-line installer: checks downloads against `SHA256SUMS`, backs up rc files, manages a single marked block, re-runs safely, and runs nothing if the download is truncated.
- Uninstaller that restores rc files byte for byte.
- Configuration: `GW_ROOT`, `GW_BASE_PREFIX`, `GW_TASK_PREFIX`, `GW_CLEAN_TARGET`.
- Test suite (bats) on Linux, macOS and Windows (Git Bash), in bash and zsh.

### Changed (compared with the original helpers)
- `gwclean` is a **dry run by default**; `--apply` makes changes. It only deletes branches whose commits are all in the base, prints a restore command for each, skips worktrees with uncommitted changes unless `--force`, and never removes the current worktree. The built-in default sprint number is gone: pass a base or set `GW_CLEAN_TARGET`.
- Sprint naming is no longer built in: `gwtask`, `gwfeature` and `gwclean` take any base branch, and `GW_BASE_PREFIX` restores short sprint numbers.
- `gwclone` was rewritten. It clones into the current folder (or `GW_ROOT`) instead of a fixed `~/worktrees`, accepts a destination path, and cleans up if the clone fails.
- `gwfeature` creates a local tracking branch for a remote-only branch instead of leaving the worktree in detached HEAD.
- `gwadd` now refuses to run outside a bare-layout project.
- `PROJECTS_ROOT` is no longer exported (it's still read if you set it).
