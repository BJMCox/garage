# format — one formatter front-end for many languages

A single `format` command that dispatches each file to the right formatter by
extension, with a `--as` flag to force a language. Plain bash — put it on your
`PATH`.

## Usage

| Command                    | Action                                               |
| -------------------------- | ---------------------------------------------------- |
| `format [PATH…]`           | Format files / recurse dirs (default: cwd), in place |
| `format --check [PATH…]`   | Report what would change; write nothing              |
| `format --as LANG [PATH…]` | Force LANG's formatter, ignore extensions            |
| `format --list`            | Print the extension → formatter table                |
| `format -h`                | Help                                                 |

Flags: `-c/--check`, `-a/--as LANG`, `-j/--jobs N`, `-l/--list`, `-h/--help`.

## Formatter map

Every formatter is optional: `format` invokes one only if it is on `PATH`, and
reports `– (needs <tool>)` otherwise. None ship with `garage` — install whichever
you need. The **Install** column shows **Homebrew as one option** (the project is
developed on macOS); any package manager works just as well — your distribution's
repos, the tool's own ecosystem (`pipx`/`npm`/`cargo`/`go`/`rustup`), or its
official installer. Run `format --list` to see which are detected on your system.

| Extensions                                                         | Formatter                    | Install (one option)              |
| ------------------------------------------------------------------ | ---------------------------- | --------------------------------- |
| `.py` `.ipynb`                                                     | `ruff` (notebooks too)       | `brew install ruff`               |
| `.jl`                                                              | `julia` + **JuliaFormatter** | `julia -e 'using Pkg; Pkg.add("JuliaFormatter")'` |
| `.json .jsonc .json5 .hs3`                                         | `prettier`                   | `brew install prettier`           |
| `.toml`                                                            | `taplo`                      | `brew install taplo`              |
| `.rs`                                                              | `rustfmt`                    | `rustup component add rustfmt`    |
| `.md .mdx .yaml/.yml .html .css/.scss/.less .js/.ts/.vue .graphql` | `prettier`                   | `brew install prettier`           |
| `.tex`                                                             | `tex-fmt`                    | `brew install tex-fmt`            |
| `.bib`                                                             | `bibtex-tidy`                | `brew install bibtex-tidy`        |
| `.sh .bash`                                                        | `shfmt`                      | `brew install shfmt`              |
| `CMakeLists.txt .cmake`                                            | `gersemi`                    | `brew install gersemi`            |
| `.c .cpp .h .cu .cuh .cc .cxx .hpp …`                              | `clang-format`               | `brew install clang-format`       |
| `.f90 .f95 .f03 .f08 .f .for`                                      | `fprettify`                  | `brew install fprettify`          |
| `.R .r`                                                            | `air` (Posit's R formatter)  | `brew install air`                |
| `.sql`                                                             | `sqlfluff` (dialect `ansi`)  | `brew install sqlfluff`           |
| `.typ`                                                             | `typstyle`                   | `brew install typstyle`           |
| `.nix`                                                             | `nixfmt`                     | `brew install nixfmt`             |
| `.proto`                                                           | `buf`                        | `brew install buf`                |
| `.go`                                                              | `gofumpt`                    | `brew install gofumpt`            |
| `.lua`                                                             | `stylua`                     | `brew install stylua`             |
| `.zig`                                                             | `zig fmt`                    | `brew install zig`                |
| `.swift`                                                           | `swift-format`               | `brew install swift-format`       |
| `.java`                                                            | `google-java-format`         | `brew install google-java-format` |
| `.kt .kts`                                                         | `ktlint`                     | `brew install ktlint`             |
| `.hs`                                                              | `ormolu`                     | `brew install ormolu`             |
| `.pl .pm`                                                          | `perltidy`                   | `brew install perltidy`           |
| `.xml`                                                             | `xmllint --format`           | libxml2 (usually preinstalled)    |
| `.tf .tfvars`                                                      | `tofu fmt` (OpenTofu)        | `brew install opentofu`           |
| `.v .sv .svh`                                                      | `verible-verilog-format`     | [chipsalliance/verible releases]  |
| `.rb`                                                              | `rufo`                       | `gem install rufo`                |

Notes:

- Markdown is handled by `prettier`; there is no separate Markdown formatter, to
  avoid two tools disagreeing on style.
- `CMakeLists.txt` is matched by **name** (it has no extension).
- `air` is Posit's R formatter — not the Go live-reload tool of the same name.
- `.hs3` is treated as JSON (a project-specific alias; see *Extension aliases*).

**Extensionless files** are dispatched by their **shebang**: a file with no
extension whose first line is e.g. `#!/usr/bin/env bash` is treated as `sh`
(also `python`→`py`, `perl`→`pl`, `ruby`→`rb`, `node`→`js`). So `format src/`
formats scripts that have no `.sh`/`.py` suffix without needing `--as`.

### Adding a formatter

Two one-line edits, no other changes (check mode and `--as` are generic):

1. `formatter_for()` — map the extension(s) → the binary name (for the
   PATH check + "needs X" message).
2. `run_writer()` — the single **in-place** command for that extension.

### Extension aliases

Non-standard extensions that mean an existing type are normalized **once** by
`canon_ext()` before any dispatch, so an alias is a single line and nothing
downstream changes. Current aliases: `.hs3 → json`. The normalization applies to
both extension dispatch and `--as` (so `--as hs3` works too). To add one, add a
case to `canon_ext()`:

```sh
canon_ext() {
    case "$1" in
        hs3) echo json ;;   # .hs3 = JSON
        *)   echo "$1" ;;
    esac
}
```

## Output

Per-file: `✓` formatted (green) · `·` unchanged (dim) · `✗` error (red) ·
`–` no formatter / missing tool. **Explicitly named** files always report;
files discovered by **recursing a directory** stay silent unless a formatter
applies — no noise for unknown types. Directory recursion descends **up to 5
levels deep**, **follows symlinked directories** (`find -L`; symlink loops are
detected and skipped), and skips hidden directories (dot-prefixed, e.g.
`.git/`, `.venv/`) plus common build/dep dirs (`node_modules`, `target`,
`build`, `dist`, `vendor`, `__pycache__`, `venv`). Tokyo Night themed;
honors `NO_COLOR` and non-TTY (no color when piped).

```
$ format src/
✓ src/api.py
· src/config.toml
✓ src/README.md
— 2 formatted · 1 unchanged · 0 errors · 0 skipped
```

## How check mode and `--as` work

Each tool exposes a single command — its in-place writer (`run_writer`). Both
modes reuse it generically, so no tool needs its own `--check` flag:

- **`--check`**: copy the file to a temp named with the same extension, run the
  writer on the copy, byte-compare (`cmp`) to the original → `ok` / `would
format`. Writes nothing.
- **`--as LANG`**: same temp-copy, but the temp is named `f.<LANG>` so
  extension-keyed tools (clang-format, prettier, …) treat it as that language;
  the result is written back to the original only if it differs (and not in
  check mode). So `format --as json notes.txt` and `format --as py ./script`
  both work. (prettier additionally gets an explicit `--parser`.)

## Exit codes

`0` success · `1` if any file errored, a named path doesn't exist, or (in
`--check`) anything would change. Suitable for a pre-commit / CI gate:
`format --check .`

## Notes

- **`.jl` needs JuliaFormatter**, which isn't in the base julia env. Install:
  `julia -e 'import Pkg; Pkg.add("JuliaFormatter")'`. Until then `.jl` files
  report `– (needs JuliaFormatter)`. The probe runs at most once per invocation
  (julia startup is slow).
- **bash 3.2-safe** (macOS system bash) — no associative arrays / `wait -n`.
- **Tab completion** (zsh, optional): a `_format` compdef can complete flags,
  the `--as` language list, and file paths.
- Parallel by default: files are formatted by a bounded worker pool (`-j`,
  defaults to the CPU count; `-j1` forces the old sequential path). Each tool
  rewrites only its own file, so workers never conflict; output order and the
  per-file status are preserved by collecting results per index. On a large tree
  this is ~5–6× faster than sequential.

## See also

- `lint.md` — the read-only linter sibling of this tool
- `git-helpers.md` — the multi-repo git tools in this collection

[chipsalliance/verible releases]: https://github.com/chipsalliance/verible/releases
