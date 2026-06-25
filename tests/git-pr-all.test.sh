#!/usr/bin/env bash
# git-pr-all.test.sh — behavior tests using a fake `gh` stub.
# No network, no real GitHub. Run: bash tests/git-pr-all.test.sh
set -u
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/git-pr-all"
fails=0
ok()       { printf 'ok   - %s\n' "$1"; }
bad()      { printf 'FAIL - %s\n' "$1"; fails=$((fails + 1)); }
check()    { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1"; printf '       want: %s\n       got:  %s\n' "$3" "$2"; fi; }
contains() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1"; printf '       missing: %s\n' "$3"; ;; esac; }
not_contains() { case "$2" in *"$3"*) bad "$1"; printf '       unexpectedly found: %s\n' "$3"; ;; *) ok "$1"; ;; esac; }

# Require jq (real dependency of the script under test).
command -v jq >/dev/null || { printf 'skip: jq not installed\n'; exit 0; }

# --- fake gh ---------------------------------------------------------------
# Driven by $GH_FIXTURE:
#   $GH_FIXTURE/<reponame>.prs  JSON array for gh pr list
#   $GH_FIXTURE/log             appended line per gh pr list call: "pr list <all-args>"
make_fake_gh() {
    local bindir="$1"
    cat >"$bindir/gh" <<'EOF'
#!/usr/bin/env bash
set -u
sub="$1"; shift
case "$sub" in
repo)
    # gh repo view --json nameWithOwner --jq .nameWithOwner
    printf 'myorg/%s\n' "$(basename "$PWD")"
    ;;
pr)
    action="$1"; shift
    case "$action" in
    list)
        printf 'pr list %s\n' "$*" >>"$GH_FIXTURE/log"
        repo_arg=""
        while [ $# -gt 0 ]; do
            case "$1" in -R) shift; repo_arg="$1" ;; esac
            shift
        done
        reponame="${repo_arg#*/}"
        f="$GH_FIXTURE/${reponame}.prs"
        if [ -f "$f" ]; then cat "$f"; else printf '[]\n'; fi
        ;;
    *) printf 'fake gh: unknown pr %s\n' "$action" >&2; exit 2 ;;
    esac
    ;;
*) printf 'fake gh: unknown %s\n' "$sub" >&2; exit 2 ;;
esac
EOF
    chmod +x "$bindir/gh"
}

mkrepo() { mkdir -p "$1" && git -C "$1" init -q && git -C "$1" remote add origin "https://github.com/myorg/$(basename "$1").git"; }

# --- test: --help ----------------------------------------------------------
out=$("$SCRIPT" --help 2>&1)
contains "help shows script name" "$out" "git-pr-all"
contains "help shows --mine"      "$out" "--mine"
contains "help shows --review"    "$out" "--review"

# --- test: bad dir ---------------------------------------------------------
out=$("$SCRIPT" /no/such/dir 2>&1); rc=$?
check    "bad dir exits 1"      "$rc" "1"
contains "bad dir message"      "$out" "not a directory"

# --- test: no repos --------------------------------------------------------
empty="$(mktemp -d)"
trap 'rm -rf "$empty"' EXIT
out=$("$SCRIPT" "$empty" 2>&1); rc=$?
check    "no repos exits 1"     "$rc" "1"
contains "no repos message"     "$out" "no git repositories"

# --- test: mutual exclusion ------------------------------------------------
out=$("$SCRIPT" --mine --review "$empty" 2>&1); rc=$?
check    "--mine --review exits 2"  "$rc" "2"
contains "--mine --review message"  "$out" "mutually exclusive"

# --- test: unknown flag ----------------------------------------------------
out=$("$SCRIPT" --bogus 2>&1); rc=$?
check    "unknown flag exits 2"  "$rc" "2"
contains "unknown flag message"  "$out" "unknown option"

# --- fixture workspace -----------------------------------------------------
ws="$(mktemp -d)"
trap 'rm -rf "$ws" "$empty"' EXIT
bindir="$ws/bin"
mkdir -p "$bindir"
make_fake_gh "$bindir"
export GH_FIXTURE="$ws/fx"
mkdir -p "$GH_FIXTURE"
PATH="$bindir:$PATH"
export PATH

mkrepo "$ws/repos/api"
mkrepo "$ws/repos/frontend"
mkrepo "$ws/repos/worker"

# api: one draft PR; frontend: one normal PR; worker: no PRs (no fixture → [])
cat >"$GH_FIXTURE/api.prs" <<'FIXTURE'
[{"number":42,"title":"Fix memory leak in auth","author":{"login":"alice"},"createdAt":"2026-06-01T00:00:00Z","isDraft":true}]
FIXTURE
cat >"$GH_FIXTURE/frontend.prs" <<'FIXTURE'
[{"number":7,"title":"Migrate to React 18","author":{"login":"bob"},"createdAt":"2026-06-20T00:00:00Z","isDraft":false}]
FIXTURE

out=$(NO_COLOR=1 "$SCRIPT" "$ws/repos" 2>&1); rc=$?
check    "successful run exits 0"        "$rc" "0"
contains "shows api repo"               "$out" "api"
contains "shows frontend repo"          "$out" "frontend"
contains "shows worker repo"            "$out" "worker"
contains "shows PR number"              "$out" "#42"
contains "shows PR title"               "$out" "Fix memory leak in auth"
contains "shows author"                 "$out" "alice"
contains "shows DRAFT badge"            "$out" "[DRAFT]"
contains "shows worker no PRs line"     "$out" "(no open PRs)"
contains "shows React PR"               "$out" "Migrate to React 18"
not_contains "no DRAFT on normal PR"    "$out" "#7$(printf '\t').*DRAFT"

# --- test: title truncation ------------------------------------------------
cat >"$GH_FIXTURE/api.prs" <<'FIXTURE'
[{"number":1,"title":"This title is way too long and must be truncated by the formatting code at fifty chars","author":{"login":"x"},"createdAt":"2026-06-20T00:00:00Z","isDraft":false}]
FIXTURE
out=$(NO_COLOR=1 "$SCRIPT" "$ws/repos/api" 2>&1)
not_contains "long title truncated" "$out" "This title is way too long and must be truncated by the formatting code at fifty chars"
contains     "truncated title has ellipsis" "$out" "…"

# Reset api fixture
cat >"$GH_FIXTURE/api.prs" <<'FIXTURE'
[{"number":42,"title":"Fix memory leak in auth","author":{"login":"alice"},"createdAt":"2026-06-01T00:00:00Z","isDraft":true}]
FIXTURE

# --- test: --mine passes --author @me --------------------------------------
rm -f "$GH_FIXTURE/log"
NO_COLOR=1 "$SCRIPT" --mine "$ws/repos" >/dev/null 2>&1
log="$(cat "$GH_FIXTURE/log" 2>/dev/null)"
contains "--mine sends --author @me" "$log" "@me"

# --- test: --review passes review-requested:@me ----------------------------
rm -f "$GH_FIXTURE/log"
NO_COLOR=1 "$SCRIPT" --review "$ws/repos" >/dev/null 2>&1
log="$(cat "$GH_FIXTURE/log" 2>/dev/null)"
contains "--review sends review-requested" "$log" "review-requested"

# --- summary ---------------------------------------------------------------
if [ "$fails" -eq 0 ]; then
    printf 'ok - all tests passed\n'
else
    printf 'FAIL - %d test(s) failed\n' "$fails"
    exit 1
fi
