# gw-suit

Small shell commands for working with **git worktrees** in the *bare-repo layout*: one folder per project, one sub-folder per branch, all sharing a single clone.

```
my-project/
  .bare/            ← the git database (a bare clone)
  .git              ← a one-line file pointing at .bare
  main/             ← worktree for the default branch
  wip/fix-login/    ← worktree for a task branch
  feature/payments/ ← worktree for another branch
```

Each folder is a normal working copy with its own checked-out branch, so you can switch tasks with `cd` instead of `git stash` + `git checkout`.

Works in **bash** (Linux, Git Bash on Windows) and **zsh** (macOS). Needs `git` (2.38 or newer recommended) and `curl`.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/mayank-singh-sikarwar/gw-suit/v1.0.0/install.sh | bash
```

Then open a new terminal and check: `type gwclone`.

What the installer does:

- downloads `gw-suit.sh` and `uninstall.sh` into `~/.local/share/gw-suit/` (or `$XDG_DATA_HOME/gw-suit/`) after checking them against `SHA256SUMS`;
- backs up your rc file (`~/.zshrc` on macOS / zsh, `~/.bashrc` for bash), then adds this block:

  ```bash
  # >>> gw-suit >>>  (managed by the gw-suit installer; remove with uninstall.sh)
  if [ -f "$HOME/.local/share/gw-suit/gw-suit.sh" ]; then . "$HOME/.local/share/gw-suit/gw-suit.sh"; fi
  # <<< gw-suit <<<
  ```

Nothing else in your rc file is touched. Running the installer again updates the files and leaves a single block.

Installer options (environment variables):

| Variable | Effect |
|---|---|
| `GW_SUIT_DRY_RUN=1` | show what would change, write nothing |
| `GW_SUIT_RC=~/.bashrc` | choose the rc file(s) to edit; separate several with `:` |
| `GW_SUIT_REF=v1.0.0` | install a specific tag |

Example: `curl -fsSL …/install.sh | GW_SUIT_DRY_RUN=1 bash`

### Update

Run the install command again with the newer tag.

### Uninstall

```bash
~/.local/share/gw-suit/uninstall.sh
```

It removes only the marked block (after another backup) and the install folder. Your rc file ends up byte-for-byte as it was before installing. Lines you added outside the block are kept.

## Commands

| Command | What it does |
|---|---|
| `gwclone <url> [dest]` | Clone a repo into the bare layout and check out its default branch |
| `gwadd <branch> [base]` | Add a worktree for a branch (create it from `base`, default: origin's default branch, if it doesn't exist) |
| `gwfeature <base>` | Check out a shared branch (e.g. a feature or sprint branch) as its own worktree, or `cd` to it |
| `gwtask <base> <slug> [--push]` | Start a task: new branch `wip/<slug>` from `base`, in its own worktree |
| `gwclean [base] [--apply] [--force]` | Remove task worktrees and branches that are merged into `base` |

Every command except `gwclone` works from anywhere inside a project: it finds the project root itself.

### gwclone

```bash
cd ~/code
gwclone git@github.com:someone/my-project.git        # -> ~/code/my-project/main
gwclone https://github.com/someone/lib.git mylib     # -> ~/code/mylib/main
gwclone https://github.com/someone/lib.git ~/x/lib   # anything with a "/" is used as a path
```

The project goes into the current folder, unless you set `GW_ROOT`. If you keep code in several places (say, personal and work), just `cd` to the right place first, or pass the full path.

### gwadd

```bash
gwadd experiment          # new branch "experiment" from the default branch -> <project>/experiment
gwadd hotfix release-2.1  # new branch "hotfix" from release-2.1
gwadd release-2.1         # existing branch: just check it out
```

### gwfeature

```bash
gwfeature release-2.1     # <project>/release-2.1, tracking origin/release-2.1
```

### gwtask

```bash
gwtask main fix-login           # wip/fix-login from origin/main -> <project>/wip/fix-login
gwtask main fix-login --push    # same, and create the branch on origin right away
```

Task branches are created without an upstream, so a stray `git push` can't send them somewhere unexpected; the first push sets it (`git push -u origin wip/fix-login`).

### gwclean

`gwclean` tidies up task branches (`wip/*`) whose work is already merged into a base branch.

```bash
gwclean main             # dry run: lists what would be removed, changes nothing
gwclean main --apply     # actually remove them
```

How it decides, and what it protects:

- **Dry run by default.** Nothing changes without `--apply`.
- **Only merged branches.** A branch is a candidate only if every commit on it is already in the base. Deleting it loses no commits, and each deletion prints a restore command:
  `deleted branch: wip/fix-login (was 3f2a1c9; restore: git branch wip/fix-login 3f2a1c9)`
- **Uncommitted changes are kept.** A worktree with uncommitted or untracked files is skipped. Add `--force` only if you really want those changes gone (they cannot be recovered).
- **Your current worktree is never removed.**
- **Merge commits and fast-forwards are detected; squash and rebase merges are not.** If your team squash-merges, the branches won't show up as merged.

## Configuration

Set these in your rc file, **below** the gw-suit block.

| Variable | Default | Used by | Meaning |
|---|---|---|---|
| `GW_ROOT` | current folder | `gwclone` | Where new projects go (`PROJECTS_ROOT` is also honoured) |
| `GW_BASE_PREFIX` | *(none)* | `gwtask`, `gwfeature`, `gwclean` | Prefix added to short base names (see below) |
| `GW_TASK_PREFIX` | `wip/` | `gwtask`, `gwclean` | Branch and folder prefix for task branches |
| `GW_CLEAN_TARGET` | *(none)* | `gwclean` | Base to use when you run `gwclean` with no argument |

### Example: a sprint workflow

Some teams cut a branch per sprint (`feature/sprint_16`) and merge task branches into it. Tell gw-suit about the naming once:

```bash
export GW_BASE_PREFIX=feature/sprint_
```

Then short names work everywhere:

```bash
gwfeature 16              # worktree for feature/sprint_16
gwtask 16 fix-login       # wip/fix-login from origin/feature/sprint_16
gwtask sprint_16 report   # "sprint_16" and "feature/sprint_16" work too
gwclean 16                # what's merged into the sprint branch?
gwclean 16 --apply
```

Without `GW_BASE_PREFIX`, `16` just means a branch literally called `16`.

## Safety notes

- **Install integrity.** The install command is pinned to a release tag, and the installer checks every file against `SHA256SUMS` from the same tag before writing anything. That catches broken, truncated or mixed-version downloads. It does not protect against a compromised GitHub account; if that matters to you, read `install.sh` first (it's short) or run it with `GW_SUIT_DRY_RUN=1`.
- **Truncated downloads.** The installer's work happens in a function called on its last line, so a download cut off half way runs nothing.
- **Your rc files.** Every change is preceded by a timestamped backup next to the file (`~/.bashrc.gw-suit.bak.<time>`).

## Troubleshooting

- **`gw…: not a .bare worktree project`**: the command was run inside a normal clone. gw-suit's commands (other than `gwclone`) work only in projects created with `gwclone` or set up the same way.
- **Commands missing in Git Bash**: make sure `~/.bash_profile` loads `~/.bashrc` (the installer warns if it doesn't): `[ -f ~/.bashrc ] && . ~/.bashrc`.
- **An older copy of these helpers is also sourced**: whichever file your rc file loads last wins. Remove the old line when you're ready.
- **Relative worktree paths**: `gwclone` sets `worktree.useRelativePaths` (git 2.48+) so a project folder can be moved. A few tools don't understand relative worktree paths yet; turn it off per project with `git config worktree.useRelativePaths false` and run `git worktree repair`.

## Contributing

Suggestions and fixes are welcome as pull requests. `main` is protected, so every change goes through a PR with passing CI. See [CONTRIBUTING.md](CONTRIBUTING.md) for how to run the tests and what reviewers look for.

## Credits

The bare-repo layout and the ideas behind these commands come from:

**Official documentation**
- [git-worktree manual](https://git-scm.com/docs/git-worktree) (git-scm.com): all worktree subcommands, bare-repo behaviour, `worktree.useRelativePaths`, branch auto-tracking on `worktree add`
- [VS Code: Branches, Stashes & Worktrees](https://code.visualstudio.com/docs/sourcecontrol/branches-worktrees): worktree detection, `git.detectWorktrees`, `git.worktreeIncludeFiles`, create/open/delete from the UI

**Blog posts and write-ups (bare repo + `.git` file layout)**
- [How to use git worktree and in a clean way](https://morgan.cugerone.com/blog/how-to-use-git-worktree-and-in-a-clean-way/), Morgan Cugerone: `.bare` folder + `gitdir:` pointer file, per-worktree dependencies
- [Git Worktrees Step-By-Step](https://infrequently.org/2021/07/worktrees-step-by-step/), Alex Russell: step-by-step recipe, push `--set-upstream`, Git LFS note
- [Sliced bread: git-worktree and bare repo](https://blog.cryptomilk.org/?p=782), Andreas Schneider: fetch refspec fix, git aliases
- [PSModule: Git Worktrees](https://psmodule.io/docs/Ways-of-Working/Git-Worktrees/): team convention, clean default-branch worktree, upstream setup

**Scripts and tools**
- [Setup Git Worktree gist](https://gist.github.com/peterneave/3f9514f66de59599f9a8cdfc74a4a443), Peter Neave: the bare-clone idea behind `gwclone` (gw-suit's version is an independent implementation)
- [git-trees](https://github.com/brightdigit/git-trees): CLI automating the bare + worktree layout
- [worktree-manager](https://github.com/jarredkenny/worktree-manager): CLI including in-place conversion of an existing clone

**Known issues**
- [Relative worktree paths issue](https://claudeissues.com/issue/24188-session-resume-picker-fails-with-git-worktree-relative-paths): tool incompatibility with `worktree.useRelativePaths` and how to revert it

## License

[PolyForm Noncommercial 1.0.0](LICENSE). Free for personal, research, educational and other noncommercial use. Commercial use needs separate permission from the author.
