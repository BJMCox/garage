#!/usr/bin/env bash
# git-dependabot.test.sh — behavior tests using a fake `gh` stub on PATH.
# No network, no real GitHub. Run: bash tests/git-dependabot.test.sh
set -u
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/git-dependabot"
fails=0
ok()   { printf 'ok   - %s\n' "$1"; }
bad()  { printf 'FAIL - %s\n' "$1"; fails=$((fails+1)); }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1"; printf '       want: %s\n       got:  %s\n' "$3" "$2"; fi; }
contains(){ case "$2" in *"$3"*) ok "$1";; *) bad "$1"; printf '       missing %q in:\n%s\n' "$3" "$2";; esac; }

# --- fixture helpers -------------------------------------------------------
# A fake `gh` whose behavior is driven by files under $GH_FIXTURE.
# $GH_FIXTURE/<reponame>.prs  -> JSON array printed by `gh pr list`
# $GH_FIXTURE/log             -> appended: "<cmd> <reponame> <args...>"
make_fake_gh() {
    local bindir="$1"
    cat >"$bindir/gh" <<'EOF'
#!/usr/bin/env bash
# fake gh: resolves "repo" from cwd basename; reads fixtures from $GH_FIXTURE
set -u
repo="$(basename "$PWD")"
sub="$1"; shift
case "$sub" in
pr)
  action="$1"; shift
  case "$action" in
  list)
    f="$GH_FIXTURE/$repo.prs"
    if [ -f "$f" ]; then cat "$f"; else echo '[]'; fi
    ;;
  view)
    num="$1"
    # mergeable comes from $GH_FIXTURE/$repo.$num.mergeable (default MERGEABLE)
    mf="$GH_FIXTURE/$repo.$num.mergeable"
    mv="MERGEABLE"; [ -f "$mf" ] && mv="$(cat "$mf")"
    printf '{"mergeable":"%s","mergeStateStatus":"CLEAN"}\n' "$mv"
    ;;
  update-branch) echo "update-branch $repo $*" >>"$GH_FIXTURE/log" ;;
  merge)         echo "merge $repo $*"         >>"$GH_FIXTURE/log" ;;
  *) echo "fake gh: unknown pr action $action" >&2; exit 2 ;;
  esac
  ;;
*) echo "fake gh: unknown $sub" >&2; exit 2 ;;
esac
EOF
    chmod +x "$bindir/gh"
}

mkrepo() { mkdir -p "$1" && git -C "$1" init -q && git -C "$1" remote add origin "https://github.com/x/$(basename "$1").git"; }

# --- test: --help ----------------------------------------------------------
out="$("$SCRIPT" --help)"
contains "help shows usage" "$out" "git-dependabot"
contains "help shows --merge" "$out" "--merge"

# --- test: not a directory -------------------------------------------------
out="$("$SCRIPT" /no/such/dir 2>&1)"; rc=$?
check "missing dir exits 1" "$rc" "1"

# --- test: dir with no repos ----------------------------------------------
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
out="$("$SCRIPT" "$tmp" 2>&1)"; rc=$?
check "no repos exits 1" "$rc" "1"
contains "no repos message" "$out" "no git repositories"

echo "---"
[ "$fails" -eq 0 ] && { echo "all passed"; exit 0; } || { echo "$fails failed"; exit 1; }
