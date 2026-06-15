# git helpers — multi-repo git tools

Small CLIs for working across a **directory of git repos** at once. Plain bash +
git, no other dependencies (`git-clone-all` also needs the GitHub CLI, `gh`).

Each tool scans the **immediate child directories** of a target directory
(default: the current directory), one level deep. Work is done in parallel, and
output is colored only when stdout is a TTY.

**Theme:** Tokyo Night, via 24-bit truecolor escapes — red `#f7768e`, green
`#9ece6a`, yellow `#e0af68`, dim/comment `#565f89`, bold-fg `#c0caf5`. Color is
suppressed when stdout isn't a TTY (piped or redirected) or when `NO_COLOR` is
set. The palette block is duplicated in each script on purpose, so any script
stays self-contained and usable on its own.

## Setup

**On `PATH`:** put the scripts on your `PATH` (clone and add the directory, or
symlink each into a directory already on `PATH`). Because they're named `git-*`,
each then works both as a plain command (`git-ahead`) and as a native `git`
subcommand (`git ahead`).

### Tab completion (zsh, optional)

- **Names** under `git <TAB>` — register the tools as git user-commands; each
  menu description is pulled from the script's **line-2 header comment**
  (`# git-NAME — desc`):
  ```zsh
  () {
      local -a cmds; local f name desc
      for f in /path/to/garage/scripts/git-*(N); do
          name=${f:t}; name=${name#git-}
          desc=$(sed -n '2p' "$f" | sed -E 's/^# *git-[a-z-]+ *[—-]+ *//; s/ *$//')
          cmds+=("${name}:${desc:-git helper}")
      done
      (( $#cmds )) && zstyle ':completion:*:*:git:*' user-commands $cmds
  }
  ```
- **Arguments** — define a `_git-<name>` function per tool (flags plus a `[DIR]`
  argument via `_directories`); `_git-each` can complete git subcommands from
  `git --list-cmds`. Naming them `_git-<name>` makes them serve both the
  `git-name` and `git name` forms (`compdef _git-<name> git-<name>`).

---

## git-ahead — ahead/behind table

How far each repo's **current branch** is from origin's default branch, plus
how fresh the latest local and remote commits are.

| Command              | Action                                              |
| -------------------- | --------------------------------------------------- |
| `git ahead [DIR]`    | Table for repos under DIR (fetches first, parallel) |
| `git-ahead -n [DIR]` | No fetch — cached refs (fast, offline)              |
| `git-ahead -h`       | Help                                                |

```
Repo               Branch             Ahead  Behind  D  Local  Remote  Status
webapp             add-feature-flags     11     25  ●     1h     30m  diverged
api                dependabot-config     10      0  ●     2d      2d  ahead
— 7 repos · 2 ahead · 1 behind · 3 dirty
```

Columns: Repo · Branch · Ahead (green >0) · Behind (red >0) · D = dirty (`●`) ·
**Local** (age of latest commit on the current branch) · **Remote** (age of
latest commit on origin's default branch) · Status
(`synced`/`ahead`/`behind`/`diverged`/`empty`/`no-remote`/`no-default`).
(`empty` = a repo with no commits yet.)
Counts via `git rev-list --left-right --count <origin-default>...HEAD`; ages are
compact relative times (`5m 3h 2d 4w 6mo 1y`) from `git log -1 --format=%ct`.

---

## git-sync-all — fast-forward what's safe

Fetches origin, then `merge --ff-only` each repo's current branch from its
tracking upstream (`@{u}`) — **only** when the tree is clean and the branch is
strictly behind. Never merges, rebases, or touches dirty/diverged repos.

| Command              | Action                                |
| -------------------- | ------------------------------------- |
| `git sync-all [DIR]` | Fast-forward eligible repos under DIR |
| `git-sync-all -h`    | Help                                  |

```
julia-mcp  up to date
webapp     pulled 4
api        skip (dirty)
worker     skip (diverged: +2 -5)
— 4 repos · 1 fast-forwarded · 3 skipped · 0 failed
```

Skip reasons (exit 0): `dirty`, `diverged`, `no upstream`, `detached HEAD`. A
genuine `ff failed` is counted as a **failure**, not a skip, and makes the tool
**exit 1** (so it's CI-detectable). Safe to run anytime — a pure fast-forward
can't lose work.

---

## git-tidy — prune merged branches & stale refs

Across a dir of repos: list (and with `-f`, delete) local branches already
merged into origin's default branch, plus prune stale remote-tracking refs.
**Dry-run by default.**

| Command             | Action                                       |
| ------------------- | -------------------------------------------- |
| `git tidy [DIR]`    | Show what would be removed (no changes)      |
| `git-tidy -f [DIR]` | Actually prune refs + delete merged branches |
| `git-tidy -h`       | Help                                         |

```
$ git tidy ~/projects
(dry run — nothing deleted; pass -f to apply)
webapp  (branch: main, default: main)
  prune ref origin/old-feature
  would del feature/done
— 1 branches + 1 refs would be removed · run with -f to apply
```

Guards: never deletes the **current** branch or the **default** branch; only
deletes branches fully merged into origin default (uses `git branch -d`, which
itself refuses unmerged branches).

---

## git-status-all — working-tree summary

What's left **uncommitted** across every repo: counts of staged / modified /
untracked / conflicted paths plus stash depth. Where `git-ahead`'s `D` column is
just a dirty _flag_, this breaks down _what_ is dirty. No fetch — purely local,
fast.

| Command                   | Action                                    |
| ------------------------- | ----------------------------------------- |
| `git status-all [DIR]`    | Summary table for repos under DIR         |
| `git-status-all -d [DIR]` | Only repos that are dirty or have a stash |
| `git-status-all -h`       | Help                                      |

```
Repo   Branch  Staged   Modif   Untrk   Confl  Stash  Status
clean  main         0       0       0       0      0  clean
messy  main         2       2       1       0      1  dirty
— 2 shown · 1 dirty · 0 with conflicts · 1 with stashes
```

Columns: Staged (green, index changes) · Modif (yellow, worktree changes) ·
Untrk (blue, untracked) · Confl (red, unmerged) · Stash (magenta, depth) ·
Status (`clean`/`dirty`/`conflicts`). Counts parsed from one
`git status --porcelain=v2` per repo; stash depth from `git stash list`.

---

## git-each — run a command in every repo

The workhorse for "do X across all repos". Runs a git subcommand (or, with
`-s`, a shell command) in each repo **in parallel**, output grouped per repo and
printed in directory order. Exits non-zero if any repo's command failed.

| Command                   | Action                                   |
| ------------------------- | ---------------------------------------- |
| `git each <git-args…>`    | Run `git <args>` in each repo            |
| `git-each -s '<cmd>'`     | Run a shell command in each repo instead |
| `git-each -d DIR <args…>` | Scan repos under DIR (default: cwd)      |
| `git-each -h`             | Help                                     |

```
$ git-each gc --auto
$ git-each switch main
$ git-each -s 'wc -l *.md | tail -1'
```

```
==> webapp
main

==> api
dev
— 7 repos · 0 failed
```

**Non-interactive commands only** — parallel output is captured to temp files,
so anything needing a TTY (editor, pager, prompts) will misbehave. A failing
repo prints a red `[exit N]` and is tallied in the footer.

> **`-s` runs an arbitrary shell command in every repo** — only pass commands
> you trust, and pass the command as a single quoted argument
> (`git-each -s 'rm -f *.tmp'`).

---

## git-clone-all — bootstrap a directory of repos

Clone every repo owned by a GitHub org/user into a directory, in **parallel**.
The bootstrap step the other tools assume: `git clone-all` a directory full of
repos, then `git ahead` / `sync-all` / `status-all` / `tidy` across them.
Requires the GitHub CLI (`gh`), authenticated.

| Command                          | Action                                       |
| -------------------------------- | -------------------------------------------- |
| `git clone-all OWNER [DIR]`      | Clone OWNER's repos into DIR (default: cwd)  |
| `git-clone-all --ssh OWNER`      | Use SSH clone URLs instead of HTTPS          |
| `git-clone-all --limit N OWNER`  | Cap the number of repos (default: 1000)      |
| `git-clone-all -h`               | Help                                         |

```
$ git clone-all acme ~/src
cloning 42 repos from acme into ~/src...
✓ cloned webapp
· skip api (exists)
✗ failed private-thing
— 40 cloned · 1 skipped (exists) · 1 failed
```

Each repo goes to `DIR/<name>`. An existing `DIR/<name>` is **left untouched**
(reported `skip (exists)`), so re-running only picks up new repos. Exits 1 if
any clone failed.

---

## git-wip — snapshot uncommitted work

An escape hatch: before a risky operation (a force-y `git tidy -f`, a rebase, a
sweeping `git-each`), snapshot whatever is uncommitted across every repo so
nothing can be lost. For each repo with changes (tracked **or** untracked),
`git-wip` records a commit of the full working tree and points a `wip/<timestamp>`
branch at it — **without touching your working tree, index, or current branch**
(the tree is built in a temporary index). Clean repos are skipped.

| Command                | Action                                       |
| ---------------------- | -------------------------------------------- |
| `git wip [DIR]`        | Snapshot repos with changes under DIR        |
| `git-wip -m MSG [DIR]` | Use a custom snapshot commit message         |
| `git-wip --list [DIR]` | List existing `wip/<ts>` branches across repos |
| `git-wip --prune [DIR]`| Delete every `wip/<ts>` branch across repos  |
| `git-wip -h`           | Help                                         |

```
$ git wip ~/src
✓ webapp  → wip/20260615-143022 (5 changes)
· api
✗ worker  (commit failed — set git user.name/email?)
— 1 snapshotted · 1 clean · 1 failed
  recover with: git checkout wip/20260615-143022
```

All snapshotted repos in one run share the `wip/<ts>` branch name, so a run is
easy to find or clean up. The branch is unmerged, so `git-tidy` will not delete
it. Recover with `git checkout wip/<ts>` (inspect), `git checkout wip/<ts> -- .`
(restore files into the working tree), or discard with `git branch -D wip/<ts>`.
Exits 1 if any snapshot failed (e.g. a repo with no configured git identity).

To manage accumulated snapshots, `git wip --list` shows every `wip/<ts>` branch
across the repos (with relative age), and `git wip --prune` deletes them all.

---

## Performance

All of these are **parallel**: repos are independent, so per-repo analysis runs
concurrently (background jobs, batches of 8) and writes to index-named temp
files that the main loop reads back in directory order — output and counts are
identical to a serial run. Fetch is parallel too (`xargs -P 16 --no-tags`).

Measured on 7 repos:

| Tool                                      | Before | After               |
| ----------------------------------------- | ------ | ------------------- |
| `git-ahead -n` (no fetch)                 | 0.38s  | 0.12s               |
| `git-tidy` (dry run)                      | 3.4s   | 0.6s                |
| `git-ahead` / `git-sync-all` (with fetch) | ~1s    | ~1s (network floor) |

`git-tidy` won most because its `git remote prune --dry-run` makes a network
call per repo — those now run concurrently instead of serially. With-fetch
runs are floored by the slowest single repo's network fetch, which shell
parallelism can't beat. Bash 3.2-safe (no `wait -n`).

`git-ahead` also **consolidates git invocations** per repo: a single
`git status --porcelain=v2 --branch` yields both the current branch and the
dirty flag (replacing separate `symbolic-ref HEAD` + `status --porcelain`
calls), and `git config --get remote.origin.url` replaces a piped
`git remote | grep` (drops the grep subprocess). Ahead/behind still uses
`rev-list` against origin's _default_ branch — not `branch.ab`, which is
measured against the configured upstream and so differs when you're on a
non-default branch. A compiled rewrite was considered and rejected: the tools
shell out to `git` regardless, so the remaining cost is process-spawn + network,
neither of which a language change removes (only a libgit2 rewrite would, for
~90 ms on an already-imperceptible path).

---

## See also

- `format.md` — the by-extension formatter front-end
- `lint.md` — the by-extension linter front-end
