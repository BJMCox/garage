<p align="center">
  <img src="https://capsule-render.vercel.app/api?type=waving&color=0:1a1b26,25:7aa2f7,50:7dcfff,75:bb9af7,100:9ece6a&height=170&section=header&text=garage&fontColor=c0caf5&fontSize=72&desc=command-line%20tools&descAlignY=70&descSize=20" alt="garage"/>
</p>

# garage

[![CI](https://github.com/BJMCox/garage/actions/workflows/ci.yml/badge.svg)](https://github.com/BJMCox/garage/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![Shell: bash](https://img.shields.io/badge/shell-bash-4EAA25?logo=gnubash&logoColor=white)
![ShellCheck](https://img.shields.io/badge/shellcheck-clean-brightgreen)
![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-555)
![Tokyo Night](https://img.shields.io/badge/theme-Tokyo_Night-7aa2f7?labelColor=1a1b26)
![Works on my Mac](https://img.shields.io/badge/works_on-my_Mac-555)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-bb9af7)](https://github.com/BJMCox/garage/pulls)
![Made with Bash](https://img.shields.io/badge/made_with-bash-4EAA25?logo=gnubash&logoColor=white)
![0 deps](https://img.shields.io/badge/dependencies-0-9ece6a)
![bash 3.2-safe](https://img.shields.io/badge/bash-3.2--safe-4EAA25)
![Vibes](https://img.shields.io/badge/vibes-immaculate-bb9af7)
![Made with Love](https://img.shields.io/badge/made_with-%E2%99%A5-f7768e)
[![Ask Me Anything](https://img.shields.io/badge/ask_me-anything-7dcfff)](https://github.com/BJMCox/garage/issues)
![Maintained](https://img.shields.io/badge/maintained-yes-9ece6a)
[![Contributions Welcome](https://img.shields.io/badge/contributions-welcome-bb9af7)](https://github.com/BJMCox/garage/issues)
![Conventional Commits](https://img.shields.io/badge/commits-conventional-fe5196?logo=conventionalcommits&logoColor=white)
![Awesome](https://img.shields.io/badge/awesome-yes-ff69b4)
![Hergestellt in Deutschland](https://img.shields.io/badge/hergestellt_in-Deutschland%20%F0%9F%87%A9%F0%9F%87%AA-DD0000?labelColor=000000)
![Scope creep](https://img.shields.io/badge/scope_creep-uncontained-f7768e)
![Badges](https://img.shields.io/badge/badges-too_many-bb9af7)
![README](https://img.shields.io/badge/README-mostly_badges-e0af68)
![Started as](https://img.shields.io/badge/started_as-an_lf_question-7dcfff)
![Bikeshedding](https://img.shields.io/badge/bikeshedding-world_class-f7768e)
![Overengineered](https://img.shields.io/badge/overengineered-lovingly-bb9af7)
![History](https://img.shields.io/badge/git_history-squashed_9x-f7768e)
![Reviewed by](https://img.shields.io/badge/reviewed_by-a_committee_of_AIs-7dcfff)
![This badge](https://img.shields.io/badge/this_badge-intentionally_meta-7aa2f7)
![Self-awareness](https://img.shields.io/badge/self--awareness-100%25-9ece6a)
![Yak shaving](https://img.shields.io/badge/yak_shaving-complete-9ece6a)
![Ship it](https://img.shields.io/badge/status-ship_it-7dcfff)
![Works 60% of the time](https://img.shields.io/badge/works-60%25_of_the_time-f7768e)
![May contain bugs](https://img.shields.io/badge/may_contain-features-bb9af7)
![Dark mode only](https://img.shields.io/badge/dark_mode-only-1a1b26)
![Star if you like it](https://img.shields.io/badge/%E2%AD%90-if_you_like_it-e0af68)
![Last commit](https://img.shields.io/github/last-commit/BJMCox/garage)
![Commit activity](https://img.shields.io/github/commit-activity/m/BJMCox/garage)
![Repo size](https://img.shields.io/github/repo-size/BJMCox/garage)
![Code size](https://img.shields.io/github/languages/code-size/BJMCox/garage)
![Top language](https://img.shields.io/github/languages/top/BJMCox/garage)
![Trans Rights](https://pride-badges.pony.workers.dev/static/v1?label=trans%20rights&stripeWidth=8&stripeColors=5BCEFA,F5A9B8,FFFFFF,F5A9B8,5BCEFA)

My garage of little command-line tools. I keep a lot of git repos in one folder,
and I got tired of `cd`-ing into each to see what's ahead, what's dirty, what
needs syncing — so these do it across the whole folder at once. The other two,
`format` and `lint`, are front-ends that look at a file's extension and run the
right formatter/linter, so I don't have to remember which tool goes with which
language. It started as a question about my file manager and got pleasantly out
of hand.

Plain `bash`, no runtime deps beyond `git` (and whatever formatters you've got).
macOS-first, Tokyo Night themed, color off when piped or under `NO_COLOR`.

> **Platform:** developed and primarily tested on **macOS** (system bash 3.2,
> BSD userland). **Linux is best-effort** — exercised by CI on `ubuntu-latest`
> (ShellCheck + smoke tests), but macOS is the reference. Please report Linux
> issues.

![](https://capsule-render.vercel.app/api?type=rect&color=0:7aa2f7,25:7dcfff,50:bb9af7,75:9ece6a,100:e0af68&height=3)

## Tools

### Multi-repo git helpers

Each operates on the **immediate child directories** of a target dir (default:
cwd), in parallel. Works as either `git-foo` or, since they're on `PATH` named
`git-*`, as a native subcommand `git foo`.

| Tool             | What it does                                                                                                                            |
| ---------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| `git-ahead`      | Table of how far each repo's branch is ahead/behind origin's default branch, plus commit ages. `-n` to skip fetching.                   |
| `git-sync-all`   | Fast-forward every clean repo that's behind its upstream. Never merges, rebases, or touches dirty/diverged repos.                       |
| `git-status-all` | Working-tree summary across repos: staged / modified / untracked / conflicted counts + stash depth. `-d` for dirty-only.                |
| `git-tidy`       | Prune stale remote-tracking refs and delete local branches already merged into origin's default. **Dry-run by default**; `-f` to apply. |
| `git-each`       | Run a git subcommand (or, with `-s`, a shell command) in every repo.                                                                    |
| `git-clone-all`  | Clone every repo of a GitHub org/user into a directory (via `gh`), in parallel. Skips already-cloned repos — the bootstrap step.         |
| `git-wip`        | Snapshot uncommitted work (tracked + untracked) across repos onto `wip/<ts>` branches, without touching your working tree. An escape hatch before risky ops. |

### format

One formatter front-end for ~30 languages. Dispatches each file to the right
formatter **by extension**; recurses directories.

```
format [PATH...]          # format in place (default: cwd)
format --check [PATH...]  # report changes, write nothing (exit 1 if any) — CI gate
format --as LANG [PATH..] # force a language (e.g. JSON content in a .txt file)
format --list             # show the extension → formatter map + install status
```

Covers Python (+ Jupyter), Julia, Rust, Go, C/C++/CUDA, Fortran, JSON, TOML,
YAML, SQL, LaTeX/BibTeX, Typst, Nix, Shell, CMake, Lua, Zig, Swift, Java,
Kotlin, Haskell, Perl, R, Protobuf, XML, Terraform, Markdown/HTML/CSS/JS/TS, …
A formatter is only invoked if its tool is on `PATH`; missing ones **skip
cleanly** (`– needs <tool>`) rather than failing the run. `format --list` shows
what's installed. Full reference: [docs/format.md](docs/format.md).

### lint

The read-only sibling of `format`: dispatches each file **by extension** to the
right *linter* and reports problems (it never writes). Same machinery as
`format` — `--as`, `--list`, graceful skip, shebang detection, dir recursion.
Exits non-zero if any file has issues, so it works as a CI gate.

```
lint [PATH...]        # lint files / recurse dirs (default: cwd)
lint --as LANG …      # force a language
lint --list           # show the extension → linter map + install status
```

Linters: `ruff` (Python), `shellcheck` (shell), `taplo` (TOML), `yamllint`
(YAML), `jq` (JSON validity), `luacheck` (Lua), `hadolint` (Dockerfile),
`markdownlint` (Markdown). Missing ones skip cleanly. Full reference:
[docs/lint.md](docs/lint.md).

![](https://capsule-render.vercel.app/api?type=rect&color=0:7aa2f7,25:7dcfff,50:bb9af7,75:9ece6a,100:e0af68&height=3)

## Layout

```
scripts/   the tools
docs/      per-tool documentation
tests/     smoke.sh — behavior tests (run by CI)
install.sh symlink the tools onto your PATH
```

![](https://capsule-render.vercel.app/api?type=rect&color=0:7aa2f7,25:7dcfff,50:bb9af7,75:9ece6a,100:e0af68&height=3)

## Install

```sh
git clone https://github.com/BJMCox/garage.git
cd garage
./install.sh                 # symlinks scripts/* into ~/.local/bin
./install.sh /custom/bin     # …or a directory of your choice
```

Ensure the target dir is on your `PATH`. The `git-*` tools then work both as
`git-ahead` and as native subcommands `git ahead`, `git tidy`, etc.

### Shell completion (optional)

zsh users can enable `git <TAB>` completion for the `git-*` tools (names and
per-command arguments). See [docs/git-helpers.md](docs/git-helpers.md) for the
snippets.

![](https://capsule-render.vercel.app/api?type=rect&color=0:7aa2f7,25:7dcfff,50:bb9af7,75:9ece6a,100:e0af68&height=3)

## Requirements

- `bash`, `git` — for everything.
- `format` — optional per-language formatters (`ruff`, `prettier`, `rustfmt`,
  `clang-format`, …), each installed however you like; `format --list` shows
  status. All are optional and skip gracefully when absent.

![](https://capsule-render.vercel.app/api?type=rect&color=0:7aa2f7,25:7dcfff,50:bb9af7,75:9ece6a,100:e0af68&height=3)

## License

MIT — see [LICENSE](LICENSE).

<p align="center">
  <img src="https://capsule-render.vercel.app/api?type=waving&color=0:1a1b26,25:7aa2f7,50:7dcfff,75:bb9af7,100:9ece6a&height=120&section=footer" alt=""/>
</p>
