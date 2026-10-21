#!/bin/sh
# Applies the lean overlay from this branch to a clean upstream sing-box-extended checkout,
# so every upstream release can be rebuilt without merging upstream history.
# Usage: sh lean/apply.sh <upstream-checkout>
set -e
SRC=$(cd "$(dirname "$0")/.." && pwd)
DST=$1
[ -f "$DST/include/registry.go" ] && [ -d "$DST/cmd/sing-box" ] ||
    { echo "not a sing-box-extended checkout: $DST" >&2; exit 1; }

cp "$SRC/include/registry_lean.go" "$DST/include/registry_lean.go"
cp "$SRC/cmd/sing-box/lean_memlimit.go" "$DST/cmd/sing-box/lean_memlimit.go"
cp "$SRC/build-lean.sh" "$DST/build-lean.sh"

# Adds "!lean" to a file's //go:build constraint (or a new one), so the lean tag skips the file.
# Constraints may follow other comments but must come before the package clause.
exclude_from_lean() {
    awk '
        !done && /^\/\/go:build / {
            cond = substr($0, 12)
            if (cond !~ /^!lean( |$)/) $0 = "//go:build !lean && (" cond ")"
            done = 1
        }
        !done && /^package / { print "//go:build !lean\n"; done = 1 }
        { print }
    ' "$1" > "$1.lean-tmp"
    mv "$1.lean-tmp" "$1"
}

exclude_from_lean "$DST/include/registry.go"
for f in "$DST"/cmd/sing-box/cmd_api*.go; do
    exclude_from_lean "$f"
done
echo "lean overlay applied to $DST"
