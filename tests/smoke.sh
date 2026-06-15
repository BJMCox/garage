#!/usr/bin/env bash
# smoke.sh — self-contained behavior tests for the garage tools.
#
# Needs only `git`. Formatter-dependent checks self-skip when the tool is
# absent, so this runs anywhere (CI on Linux, dev on macOS). Exits non-zero if
# any assertion fails.
set -u

root="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$root/scripts:$PATH"
export NO_COLOR=1 # deterministic, color-free output for matching

pass=0
fail=0
ok() {
    pass=$((pass + 1))
    printf 'ok   %s\n' "$1"
}
no() {
    fail=$((fail + 1))
    printf 'FAIL %s\n' "$1"
}

# assert a command's exit status. usage: want_rc <expected> "<desc>" cmd...
want_rc() {
    local want="$1" desc="$2"
    shift 2
    "$@" >/dev/null 2>&1
    local got=$?
    if [ "$got" -eq "$want" ]; then ok "$desc"; else no "$desc (exit $got, want $want)"; fi
}

# assert command output contains a substring. usage: want_out "<substr>" "<desc>" cmd...
want_out() {
    local sub="$1" desc="$2"
    shift 2
    if "$@" 2>/dev/null | grep -qF "$sub"; then ok "$desc"; else no "$desc (missing: $sub)"; fi
}

# --- static checks --------------------------------------------------------
for f in "$root"/scripts/* "$root"/install.sh; do
    want_rc 0 "syntax: $(basename "$f")" bash -n "$f"
done
if command -v shellcheck >/dev/null 2>&1; then
    want_rc 0 "shellcheck: all scripts" shellcheck --severity=warning "$root"/scripts/* "$root"/install.sh
else
    printf 'skip shellcheck (not installed)\n'
fi

# --- fixture: a directory of git repos ------------------------------------
ws="$(mktemp -d)"
trap 'rm -rf "$ws"' EXIT
gc() { git -c user.name=t -c user.email=t@t -c init.defaultBranch=main "$@"; }
mkdir -p "$ws/repos"
for r in clean dirty; do
    gc init -q "$ws/repos/$r"
    gc -C "$ws/repos/$r" commit -q --allow-empty -m init
done
printf 'change\n' >"$ws/repos/dirty/file.txt" # untracked → dirty

# --- git tools ------------------------------------------------------------
want_rc 0 "git-status-all runs" git-status-all "$ws/repos"
want_out "clean" "git-status-all shows clean repo" git-status-all "$ws/repos"
want_out "dirty" "git-status-all shows dirty repo" git-status-all "$ws/repos"
want_rc 0 "git-ahead -n runs" git-ahead -n "$ws/repos"
want_out "Repo" "git-ahead prints a table header" git-ahead -n "$ws/repos"
want_rc 0 "git-sync-all runs (no origin → skips)" git-sync-all "$ws/repos"
want_rc 0 "git-tidy dry-run runs" git-tidy "$ws/repos"
want_out "dry run" "git-tidy is dry by default" git-tidy "$ws/repos"
want_rc 0 "git-each success → exit 0" git-each -d "$ws/repos" rev-parse --abbrev-ref HEAD
want_rc 1 "git-each failure → exit 1" git-each -d "$ws/repos" -s "exit 1"
# marker collision: command output starting with @@RC must not break the count
want_rc 0 "git-each @@RC-in-output is harmless" git-each -d "$ws/repos" -s 'echo "@@RC 9"'

# --- format ---------------------------------------------------------------
want_rc 0 "format --list runs" format --list
want_rc 1 "format nonexistent path → exit 1" format "$ws/no/such/path"
want_rc 1 "format --as with no LANG → exit 1" format --as
# graceful skip: a known ext whose tool is absent must not error the run
printf 'unformatted\n' >"$ws/x.rb" # rufo almost never present
want_rc 0 "format skips a missing-tool file (no error)" format "$ws/x.rb"
# shebang detection routes an extensionless bash script to shfmt (if present)
printf '#!/usr/bin/env bash\necho   hi\n' >"$ws/script"
if command -v shfmt >/dev/null 2>&1; then
    format "$ws/script" >/dev/null 2>&1
    want_out "echo hi" "shebang: extensionless bash formatted via shfmt" cat "$ws/script"
else
    printf 'skip shebang/shfmt test (shfmt not installed)\n'
fi
# real formatting round-trip via ruff (if present)
if command -v ruff >/dev/null 2>&1; then
    printf 'def  f( x ):\n  return  x\n' >"$ws/a.py"
    want_rc 1 "format --check flags unformatted .py" format --check "$ws/a.py"
    format "$ws/a.py" >/dev/null 2>&1
    want_rc 0 "format --check passes after formatting" format --check "$ws/a.py"
else
    printf 'skip ruff round-trip test (ruff not installed)\n'
fi
# --as is case-insensitive: an UPPERCASE lang must still dispatch (regression)
if command -v shfmt >/dev/null 2>&1; then
    printf '#!/usr/bin/env bash\necho   hi\n' >"$ws/up.txt"
    format --as SH "$ws/up.txt" >/dev/null 2>&1
    if grep -qx 'echo hi' "$ws/up.txt"; then
        ok "format --as is case-insensitive (SH → shfmt)"
    else
        no "format --as is case-insensitive (SH → shfmt)"
    fi
fi

# --- lint -----------------------------------------------------------------
want_rc 0 "lint --list runs" lint --list
want_rc 1 "lint nonexistent path → exit 1" lint "$ws/no/such/path"
if command -v shellcheck >/dev/null 2>&1; then
    printf '#!/usr/bin/env bash\necho ok\n' >"$ws/good.sh"
    want_rc 0 "lint passes a clean shell script" lint "$ws/good.sh"
    # shellcheck disable=SC2016  # literal unexpanded $var is the fixture under test
    printf '#!/usr/bin/env bash\necho $undef_var_here\n' >"$ws/bad.sh"
    want_rc 1 "lint flags a shellcheck issue" lint "$ws/bad.sh"
fi

# --- git-clone-all (no network; arg handling only) ------------------------
want_rc 0 "git-clone-all -h runs" git-clone-all -h
want_rc 1 "git-clone-all without owner → exit 1" git-clone-all

# --- git-wip --------------------------------------------------------------
want_rc 0 "git-wip -h runs" git-wip -h
# fresh fixture: one clean repo, one dirty repo
wipws="$ws/wip"
mkdir -p "$wipws"
for r in clean dirty; do
    gc init -q "$wipws/$r"
    # persist a git identity in the repo: git-wip calls bare `git commit-tree`,
    # which needs user.name/email (CI runners have no global identity)
    git -C "$wipws/$r" config user.name t
    git -C "$wipws/$r" config user.email t@t
    gc -C "$wipws/$r" commit -q --allow-empty -m init
done
printf 'tracked\n' >"$wipws/dirty/tracked.txt"
gc -C "$wipws/dirty" add tracked.txt
gc -C "$wipws/dirty" commit -q -m add
printf 'changed\n' >>"$wipws/dirty/tracked.txt" # unstaged modification
printf 'new\n' >"$wipws/dirty/untracked.txt"    # untracked file
want_rc 0 "git-wip runs over a repo dir" git-wip "$wipws"
if gc -C "$wipws/dirty" branch --list 'wip/*' | grep -q .; then
    ok "git-wip created a wip/* branch in the dirty repo"
else
    no "git-wip created a wip/* branch in the dirty repo"
fi
if gc -C "$wipws/clean" branch --list 'wip/*' | grep -q .; then
    no "git-wip left the clean repo alone (no wip branch)"
else
    ok "git-wip left the clean repo alone (no wip branch)"
fi
if [ -n "$(gc -C "$wipws/dirty" status --porcelain)" ] &&
    [ -f "$wipws/dirty/untracked.txt" ]; then
    ok "git-wip leaves the working tree untouched"
else
    no "git-wip leaves the working tree untouched"
fi
wipbr="$(gc -C "$wipws/dirty" branch --list 'wip/*' | tr -d ' *')"
if gc -C "$wipws/dirty" ls-tree -r --name-only "$wipbr" | grep -qx untracked.txt; then
    ok "git-wip snapshot includes untracked files"
else
    no "git-wip snapshot includes untracked files"
fi
# --list shows the snapshot just made
want_rc 0 "git-wip --list runs" git-wip --list "$wipws"
want_out "wip/" "git-wip --list shows the snapshot branch" git-wip --list "$wipws"
# --prune removes it
want_rc 0 "git-wip --prune runs" git-wip --prune "$wipws"
if gc -C "$wipws/dirty" branch --list 'wip/*' | grep -q .; then
    no "git-wip --prune removed the wip branch"
else
    ok "git-wip --prune removed the wip branch"
fi

# --- summary --------------------------------------------------------------
printf -- '----\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
