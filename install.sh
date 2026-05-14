#!/bin/bash
# One-shot installer for the Cowork alarm watcher.
# Run this once. It copies files into place and loads the LaunchAgent.

set -e

ROOT="$HOME/cowork-alarm"
PLIST_DEST="$HOME/Library/LaunchAgents/com.cowork.alarm-watcher.plist"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing Cowork alarm watcher..."

# 1. Create the alarm folder structure
mkdir -p "$ROOT/triggers" "$ROOT/fired"
echo "  ✓ created $ROOT/{triggers,fired}"

# 2. Copy the watcher script and make it executable
cp "$SCRIPT_DIR/watcher.sh" "$ROOT/watcher.sh"
chmod +x "$ROOT/watcher.sh"
echo "  ✓ installed watcher.sh"

# 3. Install the LaunchAgent plist
mkdir -p "$HOME/Library/LaunchAgents"
cp "$SCRIPT_DIR/com.cowork.alarm-watcher.plist" "$PLIST_DEST"
echo "  ✓ installed LaunchAgent plist"

# 4. Unload first (in case it's already loaded), then load
launchctl unload "$PLIST_DEST" 2>/dev/null || true
launchctl load "$PLIST_DEST"
echo "  ✓ loaded LaunchAgent (running now)"

echo ""
echo "Done. The watcher is live and polling every 2 minutes."
echo ""
echo "To test it manually right now:"
echo "  touch $ROOT/triggers/test.trigger"
echo "  # Wait up to 2 minutes — you should hear You Suffer at max volume."
echo ""
echo "Logs: tail -f $ROOT/watcher.log"
echo "To stop: launchctl unload $PLIST_DEST"