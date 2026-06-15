#!/usr/bin/env bash
# install.sh — symlink the garage scripts onto your PATH.
#
# Usage:
#   ./install.sh [TARGET_DIR]    # default: ~/.local/bin
#
# Creates TARGET_DIR if needed and symlinks every executable in scripts/ into
# it. Re-runnable (idempotent — overwrites its own symlinks). The git-* tools
# then work as `git-ahead` and as native subcommands `git ahead`.
set -eu

src="$(cd "$(dirname "$0")/scripts" && pwd)"
dest="${1:-$HOME/.local/bin}"
mkdir -p "$dest"

n=0
for f in "$src"/*; do
    if [ ! -f "$f" ] || [ ! -x "$f" ]; then continue; fi
    name="$(basename "$f")"
    link="$dest/$name"
    if [ -L "$link" ] && [ "$(readlink "$link")" = "$f" ]; then
        echo "  up to date $name"
    else
        ln -sf "$f" "$link"
        echo "  linked $name"
    fi
    n=$((n + 1))
done

echo "Linked $n tool(s) into $dest"
case ":$PATH:" in
*":$dest:"*) ;;
*)
    echo "NOTE: $dest is not on your PATH — add it:"
    echo "      export PATH=\"$dest:\$PATH\""
    ;;
esac
