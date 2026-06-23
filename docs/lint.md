# lint — one linter front-end for many languages

The read-only sibling of [`format`](format.md): `lint` dispatches each file to
the right linter **by extension** and reports problems. It never writes —
`format` fixes style, `lint` finds issues. Plain bash — put it on your `PATH`.

## Usage

| Command                  | Action                                              |
| ------------------------ | --------------------------------------------------- |
| `lint [PATH…]`           | Lint files / recurse dirs (default: cwd)            |
| `lint --as LANG [PATH…]` | Force LANG's linter, ignore extensions              |
| `lint --list`            | Print the extension → linter table + install status |
| `lint -h`                | Help                                                |

Flags: `-a/--as LANG`, `-l/--list`, `-h/--help`.

## Linter map

Every linter is optional and installed separately. The **Install** column shows
**Homebrew as one option** (the project is developed on macOS); any package
manager works — your distribution's repos, the tool's own ecosystem, or its
official installer. Run `lint --list` to see which are detected.

| Extensions                 | Linter          | Install (one option)            |
| -------------------------- | --------------- | ------------------------------- |
| `.py`                      | `ruff check`    | `brew install ruff`             |
| `.sh .bash`                | `shellcheck`    | `brew install shellcheck`       |
| `.toml`                    | `taplo lint`    | `brew install taplo`            |
| `.yaml .yml`               | `yamllint`      | `brew install yamllint`         |
| `.json .jsonc .json5 .hs3` | `jq` (validity) | `brew install jq`               |
| `.lua`                     | `luacheck`      | `brew install luacheck`         |
| `Dockerfile`               | `hadolint`      | `brew install hadolint`         |
| `.md .markdown`            | `markdownlint`  | `brew install markdownlint-cli` |

A linter is only invoked if its tool is on `PATH`; an uninstalled one degrades to
`– (needs <tool>)` and is skipped (run `lint --list` to see status).
`Dockerfile` is matched by **name**. Extensionless files are dispatched by their
**shebang** (`#!/usr/bin/env bash` → shell, `python` → py). `.hs3` is normalized
to `json` (matching `format`).

## Output

Per-file: `·` clean (dim) · `✗` issues (red, with the linter's diagnostics
indented beneath) · `–` no linter / missing tool. Explicitly named files always
report; files discovered by **recursing a directory** stay silent unless a
linter applies. Recursion descends up to 5 levels, follows symlinked dirs, and
ignores `.git/`. Tokyo Night themed; honors `NO_COLOR` and non-TTY.

```
$ lint scripts/
· scripts/format
✗ scripts/oops
    In scripts/oops line 12:
    echo $undefined
         ^-- SC2154: undefined is referenced but not assigned.
— 7 clean · 1 with issues · 0 skipped
```

## Exit codes

`0` if everything clean · `1` if any file has issues or a named path doesn't
exist. Suitable for a pre-commit / CI gate: `lint .`

## See also

- `format.md` — the formatter front-end this mirrors
- `git-helpers.md` — the multi-repo git tools in this collection
