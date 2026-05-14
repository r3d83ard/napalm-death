# napalm-death

## Cowork alarm watcher

A background macOS service that watches for failure signals from Cowork scheduled tasks and plays an alarm (You Suffer by Napalm Death, ~1.3s) at max volume, then restores your previous volume.

## How it works

```
Cowork scheduled task fails (inside a sandboxed project workspace)
  └─> Claude writes a sentinel file (workspace-relative):
        <workspace-root>/cowork-alarm/triggers/<timestamp>.trigger
        e.g.  ~/Documents/Claude/Projects/Heimdall/cowork-alarm/triggers/...
  └─> LaunchAgent watcher runs every 2 min, scans all known trigger dirs:
        - ~/cowork-alarm/triggers/                       (manual triggers / fallback)
        - ~/Documents/Claude/Projects/*/cowork-alarm/triggers/  (each project workspace)
  └─> If any trigger found:
        ├─> saves current system volume and current Spotify state
        ├─> sets volume to 100%
        ├─> tells Spotify to play You Suffer (interrupts whatever was playing)
        ├─> waits 3 seconds for the alarm song
        ├─> restores Spotify to the previous track and seek position
        └─> moves the trigger into ~/cowork-alarm/fired/ (prefixed with a
            6-char hash of the source dir so triggers from different projects
            don't collide)
```

Polling cadence: every 2 minutes. Worst case you hear about a failure 2 minutes after it happens.

## Adding a new project workspace

If a scheduled task runs in a workspace at a path that isn't already covered (i.e. not under `~/Documents/Claude/Projects/*/`), edit the `TRIGGER_PATHS` array at the top of `~/cowork-alarm/watcher.sh` and add the new path. No reload needed — the LaunchAgent re-reads the script on every fire.

## Install

```bash
cd /path/to/this/folder
chmod +x install.sh
./install.sh
```

That's it. The installer:
- creates `~/cowork-alarm/{triggers,fired}/`
- copies `watcher.sh` into `~/cowork-alarm/`
- copies the LaunchAgent plist into `~/Library/LaunchAgents/`
- runs `launchctl load` so it starts immediately and on every login from here on

## Test it manually

```bash
touch ~/cowork-alarm/triggers/test.trigger
```

Within 2 minutes, your volume should crank, Spotify should launch and play You Suffer, and your volume should return to its previous level. Confirm the trigger file moved into `~/cowork-alarm/fired/`.

You can also run the watcher immediately without waiting for the next poll:

```bash
~/cowork-alarm/watcher.sh
```

## Wiring it up to Cowork

For Claude to drop trigger files during scheduled tasks, you need to connect `~/cowork-alarm/` (or its parent) as a Cowork directory so sessions can write into it. Then, in your scheduled task prompts, add an error-handling instruction like:

> If you hit an unrecoverable error, before exiting, write a file at `~/cowork-alarm/triggers/<UTC-timestamp>.trigger` containing a one-line description of the error. This triggers a local alarm on my Mac.

The contents of the trigger file aren't strictly necessary for the alarm to fire, but they're useful for debugging — you can `cat ~/cowork-alarm/fired/*.trigger` to see what failed.

## Files

- `watcher.sh` — the script that actually fires the alarm
- `com.cowork.alarm-watcher.plist` — LaunchAgent definition, runs watcher every 120s
- `install.sh` — one-shot installer

## Stopping it

```bash
launchctl unload ~/Library/LaunchAgents/com.cowork.alarm-watcher.plist
```

To remove entirely:

```bash
launchctl unload ~/Library/LaunchAgents/com.cowork.alarm-watcher.plist
rm ~/Library/LaunchAgents/com.cowork.alarm-watcher.plist
rm -rf ~/cowork-alarm
```

## Troubleshooting

- **Nothing happens after creating a test trigger.** Check `~/cowork-alarm/watcher.log` and `~/cowork-alarm/launchd.err.log`. Most common cause: `watcher.sh` not executable (`chmod +x ~/cowork-alarm/watcher.sh`).
- **Spotify doesn't play.** Make sure the Spotify desktop app is installed. Try `open spotify:track:5oD2Z1OOx1Tmcu2mc9sLY2` in Terminal — if that doesn't work, Spotify isn't installed or the URI handler isn't registered.
- **Volume doesn't change.** macOS may need permission for `osascript` to control system volume. System Settings → Privacy & Security → Accessibility — make sure your terminal / shell has access.
- **Watcher running but not finding triggers.** Verify the path Claude writes to matches `~/cowork-alarm/triggers/`. Resolves to `/Users/<you>/cowork-alarm/triggers/`.