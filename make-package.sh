#!/usr/bin/env bash
#
# make-package.sh
# Builds a distributable zip of the Athenaeum update tools.
#
# Includes only the files an end user needs; omits internal docs,
# developer-only test scripts, and scratch utilities.
#
# Usage:  ./make-package.sh
# Output: athenaeum-update-<version>.zip in this folder.

set -euo pipefail

# Always work relative to this script's own directory.
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SRC"

# Derive the version from VERSION.txt (line "Version: X.Y.Z").
VERSION="$(awk -F': ' '/Version:/{gsub(/[[:space:]]/,"",$2); print $2}' VERSION.txt)"
if [ -z "$VERSION" ]; then
    echo "ERROR: could not read Version from VERSION.txt" >&2
    exit 1
fi

PKG="athenaeum-update-${VERSION}"
OUT="${SRC}/${PKG}.zip"

# Files to ship, relative to this folder. Edit this list to change the package.
FILES=(
    # Root scripts
    athenaeum-update.cmd
    update.cmd
    download_clone.cmd
    store-credentials.cmd
    clear-credentials.cmd
    list-databases.cmd
    # Config / templates
    config.json
    VERSION.txt
    # PowerShell helpers
    ps1/clear-fmcreds.ps1
    ps1/download_clone.ps1
    ps1/fmadmin-api.ps1
    ps1/get-config.ps1
    ps1/get-fmcreds.ps1
    ps1/store-fmcreds.ps1
    # End-user documentation
    doc/instructions.md
    doc/CREDENTIAL_SETUP.md
    # Selected test scripts
    test/test-credentials.cmd
    test/test-api.cmd
    test/test-api.ps1
)

# Stage into a clean temp tree so the zip has a single top-level folder.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

MISSING=0
for f in "${FILES[@]}"; do
    if [ ! -f "$f" ]; then
        echo "ERROR: missing file: $f" >&2
        MISSING=1
        continue
    fi
    mkdir -p "$STAGE/$PKG/$(dirname "$f")"
    cp "$f" "$STAGE/$PKG/$f"
done
[ "$MISSING" -eq 0 ] || { echo "Aborting: some files were missing." >&2; exit 1; }

# Build the zip (overwrite any existing one).
rm -f "$OUT"
( cd "$STAGE" && zip -r -X "$OUT" "$PKG" -x '*.DS_Store' >/dev/null )

echo "Created: $OUT"
unzip -l "$OUT" | tail -n +2
