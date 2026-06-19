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
    num="$1"; shift
    # mergeable comes from $GH_FIXTURE/$repo.$num.mergeable (default MERGEABLE)
    mf="$GH_FIXTURE/$repo.$num.mergeable"
    mv="MERGEABLE"; [ -f "$mf" ] && mv="$(cat "$mf")"
    # detect --template flag: if present, emit just the value
    use_template=0
    for arg in "$@"; do
      case "$arg" in --template) use_template=1 ;; esac
    done
    if [ "$use_template" -eq 1 ]; then
      printf '%s' "$mv"
    else
      printf '{"mergeable":"%s","mergeStateStatus":"CLEAN"}\n' "$mv"
    fi
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

# --- test: --merge acts on MERGEABLE PRs ----------------------------------
tmp3="$(mktemp -d)"; bindir3="$tmp3/bin"; mkdir -p "$bindir3"
make_fake_gh "$bindir3"
GH_FIXTURE="$tmp3/fx"; export GH_FIXTURE; mkdir -p "$GH_FIXTURE"
PATH="$bindir3:$PATH"; export PATH
GD_POLL_TRIES=2 GD_POLL_SLEEP=0; export GD_POLL_TRIES GD_POLL_SLEEP

mkrepo "$tmp3/repos/alpha"
mkrepo "$tmp3/repos/beta"
printf '[{"number":7,"title":"bump lodash","mergeable":"MERGEABLE","mergeStateStatus":"CLEAN"}]\n' >"$GH_FIXTURE/alpha.prs"
printf '[{"number":9,"title":"bump axios","mergeable":"CONFLICTING","mergeStateStatus":"DIRTY"}]\n'  >"$GH_FIXTURE/beta.prs"

out="$("$SCRIPT" --merge "$tmp3/repos")"
contains "alpha merged line"   "$out" "merged #7"
log="$(cat "$GH_FIXTURE/log")"
contains "alpha update-branch ran" "$log" "update-branch alpha 7"
contains "alpha squash merge ran"  "$log" "merge alpha 7 --squash --delete-branch"
case "$log" in *"merge beta"*) bad "beta must NOT merge (conflict)";; *) ok "beta not merged";; esac

# --- test: footer tally + ordering + exit status --------------------------
out="$("$SCRIPT" "$tmp2/repos")"   # reuse Task-2 fixture: alpha/beta/gamma
contains "footer repos count" "$out" "3 repos"
contains "footer would-merge" "$out" "1 would-merge"
contains "footer conflict"    "$out" "1 conflict"
# ordering: alpha before beta before gamma (directory order)
a=$(printf '%s\n' "$out" | grep -n 'alpha' | head -1 | cut -d: -f1)
b=$(printf '%s\n' "$out" | grep -n 'beta'  | head -1 | cut -d: -f1)
g=$(printf '%s\n' "$out" | grep -n 'gamma' | head -1 | cut -d: -f1)
if [ -n "$a" ] && [ -n "$b" ] && [ -n "$g" ] && [ "$a" -lt "$b" ] && [ "$b" -lt "$g" ]; then
    ok "ordered output"
else
    bad "ordered output (a=$a b=$b g=$g)"
fi

# exit status: a forced merge failure -> nonzero
# Build a fresh fake gh that makes `gh pr merge` exit 1 — no sed needed.
tmp4="$(mktemp -d)"; bindir4="$tmp4/bin"; mkdir -p "$bindir4"
cat >"$bindir4/gh" <<'GHEOF'
#!/usr/bin/env bash
set -u
repo="$(basename "$PWD")"
sub="$1"; shift
case "$sub" in
pr)
  action="$1"; shift
  case "$action" in
  list)
    f="$GH_FIXTURE/$repo.prs"
    use_template=0
    for arg in "$@"; do
      case "$arg" in --template) use_template=1 ;; esac
    done
    if [ "$use_template" -eq 1 ]; then
      if [ -f "$f" ]; then
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
    num="$1"; shift
    mf="$GH_FIXTURE/$repo.$num.mergeable"
    mv="MERGEABLE"; [ -f "$mf" ] && mv="$(cat "$mf")"
    use_template=0
    for arg in "$@"; do
      case "$arg" in --template) use_template=1 ;; esac
    done
    if [ "$use_template" -eq 1 ]; then
      printf '%s' "$mv"
    else
      printf '{"mergeable":"%s","mergeStateStatus":"CLEAN"}\n' "$mv"
    fi
    ;;
  update-branch) echo "update-branch $repo $*" >>"$GH_FIXTURE/log" ;;
  merge)
    echo "merge $repo $*" >>"$GH_FIXTURE/log"
    exit 1
    ;;
  *) echo "fake gh: unknown pr action $action" >&2; exit 2 ;;
  esac
  ;;
*) echo "fake gh: unknown $sub" >&2; exit 2 ;;
esac
GHEOF
chmod +x "$bindir4/gh"

GH_FIXTURE="$tmp4/fx"; export GH_FIXTURE; mkdir -p "$GH_FIXTURE"
PATH="$bindir4:$PATH"; export PATH
GD_POLL_TRIES=1 GD_POLL_SLEEP=0; export GD_POLL_TRIES GD_POLL_SLEEP
mkrepo "$tmp4/repos/delta"
printf '[{"number":3,"title":"bump pkg","mergeable":"MERGEABLE","mergeStateStatus":"CLEAN"}]\n' >"$GH_FIXTURE/delta.prs"
"$SCRIPT" --merge "$tmp4/repos" >/dev/null 2>&1; rc=$?
check "merge failure exits nonzero" "$rc" "1"

echo "---"
[ "$fails" -eq 0 ] && { echo "all passed"; exit 0; } || { echo "$fails failed"; exit 1; }
