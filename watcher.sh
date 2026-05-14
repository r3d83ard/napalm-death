#!/bin/bash
# Cowork alarm watcher
# Polls ~/cowork-alarm/triggers/ for *.trigger files. When found:
#   1. saves current output volume
#   2. cranks volume to 100%
#   3. plays the Spotify alarm track via the desktop app
#   4. restores original volume
#   5. moves the trigger into ~/cowork-alarm/fired/ so it doesn't replay

set -u

ROOT="$HOME/cowork-alarm"
TRIGGER_DIR="$ROOT/triggers"
FIRED_DIR="$ROOT/fired"
LOG_FILE="$ROOT/watcher.log"
SPOTIFY_URI="spotify:track:5oD2Z1OOx1Tmcu2mc9sLY2"

mkdir -p "$TRIGGER_DIR" "$FIRED_DIR"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Collect any trigger files (newline-separated). Exit quietly if none.
shopt -s nullglob
triggers=("$TRIGGER_DIR"/*.trigger)
if [ ${#triggers[@]} -eq 0 ]; then
  exit 0
fi

log "found ${#triggers[@]} trigger(s) — firing alarm"

# Save current output volume (0-100)
ORIGINAL_VOLUME=$(osascript -e "output volume of (get volume settings)" 2>/dev/null || echo "50")
log "saved original volume: $ORIGINAL_VOLUME"

# Make sure it's not muted, then crank to max
osascript -e "set volume output muted false" >/dev/null 2>&1
osascript -e "set volume output volume 100" >/dev/null 2>&1

# Launch Spotify (if not running) and play the track
open "$SPOTIFY_URI"

# Give the desktop app time to open and play (You Suffer is ~1.3s; pad for app launch)
sleep 5

# Restore original volume
osascript -e "set volume output volume $ORIGINAL_VOLUME" >/dev/null 2>&1
log "restored volume to $ORIGINAL_VOLUME"

# Move processed triggers into fired/
for t in "${triggers[@]}"; do
  if [ -f "$t" ]; then
    mv "$t" "$FIRED_DIR/" 2>/dev/null && log "moved $(basename "$t") to fired/"
  fi
done

log "alarm complete"