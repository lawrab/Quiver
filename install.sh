#!/usr/bin/env bash
# Symlinks the Quiver addon into the WoW TBC Anniversary AddOns directory.
# Edit ADDONS_DIR to point to your AddOns folder, then run once.

ADDONS_DIR="/home/lrabbets/.local/share/Steam/steamapps/compatdata/3579333542/pfx/drive_c/Program Files (x86)/World of Warcraft/_anniversary_/Interface/AddOns"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$ADDONS_DIR/Quiver"

if [ ! -d "$ADDONS_DIR" ]; then
    echo "Error: AddOns directory not found: $ADDONS_DIR"
    exit 1
fi

echo "Installing Quiver addon..."
rm -f "$DEST"
ln -s "$SCRIPT_DIR" "$DEST"
echo "Done: $DEST -> $SCRIPT_DIR"
echo ""
echo "Next steps:"
echo "  1. Launch WoW and enable Quiver on the character select screen"
echo "  2. Log in on a Hunter character"
echo "  3. Changes to the addon files take effect on /reload"
