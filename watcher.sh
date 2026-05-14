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
FIRED_DIR="$ROOT/fired"
LOG_FILE="$ROOT/watcher.log"
SPOTIFY_URI="spotify:track:5oD2Z1OOx1Tmcu2mc9sLY2"

# All directories the watcher will scan for *.trigger files. Sandboxed Cowork
# tasks usually can only write inside their own project workspace, so we look
# for a "cowork-alarm/triggers/" subfolder inside each project workspace as
# well as the global home-level folder.
#
# To add new project locations, just add more entries to this array.
TRIGGER_PATHS=(
  "$HOME/cowork-alarm/triggers"
  "$HOME/Documents/Claude/Projects/"*"/cowork-alarm/triggers"
)

mkdir -p "$FIRED_DIR" "$HOME/cowork-alarm/triggers"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Collect trigger files across every known path.
shopt -s nullglob
triggers=()
for dir in "${TRIGGER_PATHS[@]}"; do
  if [ -d "$dir" ]; then
    for f in "$dir"/*.trigger; do
      triggers+=("$f")
    done
  fi
done

if [ ${#triggers[@]} -eq 0 ]; then
  exit 0
fi

log "found ${#triggers[@]} trigger(s) — firing alarm"

# Save current output volume (0-100)
ORIGINAL_VOLUME=$(osascript -e "output volume of (get volume settings)" 2>/dev/null || echo "50")
log "saved original volume: $ORIGINAL_VOLUME"

# Save what Spotify is currently playing so we can restore it after the alarm.
# These will be empty strings if Spotify isn't running, which we handle below.
PREV_TRACK=$(osascript -e 'tell application "Spotify" to spotify url of current track' 2>/dev/null || true)
PREV_POSITION=$(osascript -e 'tell application "Spotify" to player position' 2>/dev/null || true)
PREV_STATE=$(osascript -e 'tell application "Spotify" to player state as string' 2>/dev/null || true)
log "saved spotify state: track=${PREV_TRACK:-none} pos=${PREV_POSITION:-0} state=${PREV_STATE:-none}"

# Make sure system audio isn't muted, then crank to max
osascript -e "set volume output muted false" >/dev/null 2>&1
osascript -e "set volume output volume 100" >/dev/null 2>&1

# Make sure Spotify is open, then force it to play our alarm track.
# `tell ... to play track` interrupts whatever's currently playing — `open spotify:track:...` does not.
osascript <<EOF >/dev/null 2>&1
tell application "Spotify"
    if it is not running then
        activate
        delay 1.5
    end if
    play track "$SPOTIFY_URI"
end tell
EOF
log "fired alarm track"

# Let the alarm play. You Suffer is ~1.3s; 3s gives margin without bleeding far into the next track.
sleep 3

# Restore previous Spotify state, if there was one.
if [ -n "${PREV_TRACK:-}" ]; then
  osascript <<EOF >/dev/null 2>&1
tell application "Spotify"
    play track "$PREV_TRACK"
    delay 0.3
    set player position to ${PREV_POSITION:-0}
end tell
EOF
  # If they had Spotify paused before, pause it again instead of resuming.
  if [ "${PREV_STATE:-}" = "paused" ] || [ "${PREV_STATE:-}" = "stopped" ]; then
    osascript -e 'tell application "Spotify" to pause' >/dev/null 2>&1
  fi
  log "restored spotify to ${PREV_TRACK} at ${PREV_POSITION:-0}"
else
  # Nothing was playing before — just pause so we don't bleed into the next album track
  osascript -e 'tell application "Spotify" to pause' >/dev/null 2>&1
  log "no previous spotify state; paused after alarm"
fi

# Restore system volume
osascript -e "set volume output volume $ORIGINAL_VOLUME" >/dev/null 2>&1
log "restored volume to $ORIGINAL_VOLUME"

# Move processed triggers into the central fired/ directory.
# Prefix with a short hash of the source dir so triggers from different
# projects don't collide on the same filename.
for t in "${triggers[@]}"; do
  if [ -f "$t" ]; then
    source_tag=$(dirname "$t" | shasum | awk '{print substr($1, 1, 6)}')
    basename_t=$(basename "$t")
    mv "$t" "$FIRED_DIR/${source_tag}-${basename_t}" 2>/dev/null && log "moved $t -> fired/${source_tag}-${basename_t}"
  fi
done

log "alarm complete"