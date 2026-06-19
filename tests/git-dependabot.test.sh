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
    # detect --template flag: if present, emit TSV number\tmergeable\ttitle per PR
    use_template=0
    for arg in "$@"; do
      case "$arg" in --template) use_template=1 ;; esac
    done
    if [ "$use_template" -eq 1 ]; then
      if [ -f "$f" ]; then
        # parse simple one-object-per-array JSON with awk (no jq needed in test stub)
        awk 'BEGIN{RS="},";FS=","} {
          num=""; mg=""; ti=""
          for(i=1;i<=NF;i++){
            if($i ~ /"number":/){gsub(/.*"number":/,"",$i); gsub(/[^0-9]/,"",$i); num=$i}
            if($i ~ /"mergeable":/){gsub(/.*"mergeable":"/,"",$i); gsub(/".*$/,"",$i); mg=$i}
            if($i ~ /"title":/){gsub(/.*"title":"/,"",$i); gsub(/".*$/,"",$i); ti=$i}
          }
          if(num!="") printf "%s\t%s\t%s\n", num, mg, ti
        }' "$f"
      fi
    else
      if [ -f "$f" ]; then cat "$f"; else echo '[]'; fi
    fi
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

# --- test: classification (dry-run) ---------------------------------------
tmp2="$(mktemp -d)"; bindir="$tmp2/bin"; mkdir -p "$bindir"
make_fake_gh "$bindir"
export GH_FIXTURE="$tmp2/fx"; mkdir -p "$GH_FIXTURE"
PATH="$bindir:$PATH"; export PATH

mkrepo "$tmp2/repos/alpha"   # MERGEABLE PR
mkrepo "$tmp2/repos/beta"    # CONFLICTING PR
mkrepo "$tmp2/repos/gamma"   # no dependabot PRs
printf '[{"number":7,"title":"bump lodash","mergeable":"MERGEABLE","mergeStateStatus":"CLEAN"}]\n' >"$GH_FIXTURE/alpha.prs"
printf '[{"number":9,"title":"bump axios","mergeable":"CONFLICTING","mergeStateStatus":"DIRTY"}]\n'  >"$GH_FIXTURE/beta.prs"
printf '[]\n' >"$GH_FIXTURE/gamma.prs"

out="$("$SCRIPT" "$tmp2/repos")"
contains "alpha would-merge"  "$out" "would merge #7 bump lodash"
contains "beta conflict"      "$out" "conflict #9 bump axios"
contains "gamma none"         "$out" "no dependabot PRs"
contains "dry-run no merge log" "$([ -f "$GH_FIXTURE/log" ] && cat "$GH_FIXTURE/log" || echo NONE)" "NONE"

echo "---"
[ "$fails" -eq 0 ] && { echo "all passed"; exit 0; } || { echo "$fails failed"; exit 1; }
