# Claude + Codex Tracker

## What `build.sh` does
- Verifies Python and required packages (`browser_cookie3`, `requests`)
- Compiles Swift menu binary from `native/Launcher.swift`
- Builds app icon from `assets/ClaudeCodexIcon1024.png`
- Installs binary to `~/.local/bin/claude-tracker`
- Installs fetcher to `~/.claude-tracker/tracker_data.py`
- Recreates launcher app at `/Applications/Claude_Codex_Tracker.app`
- Rewrites/loads LaunchAgent at `~/Library/LaunchAgents/com.sakthivel.claudetracker.plist`
- Launches the tracker

## Runtime Architecture
- UI layer: Swift (`native/Launcher.swift`)
- Data layer: Python (`tracker_data.py`)
- Shared data file: `~/.cache/claude-codex-tracker/data.json`

Flow:
1. Swift app starts as accessory app and renders menu bar UI.
2. Swift ensures Python fetcher is running.
3. Python fetches:
   - Claude usage from `claude.ai` APIs
   - Codex usage from `chatgpt.com` APIs
4. Python writes unified payload to `~/.cache/claude-codex-tracker/data.json`.
5. Swift polls and updates menu UI.

## Refresh/Polling Defaults
- Python normal refresh: 5 min
- Python at-limit refresh: 1 min
- Swift UI poll: 10 sec

## Accounts and Auth
User must be logged in on Chrome for:
- `claude.ai`
- `chatgpt.com`

Cookies are read via `browser_cookie3`.
Claude org is auto-discovered from your authenticated Claude account.
Optional override: set environment variable `CLAUDE_ORG_ID`.

## Prerequisites
```bash
pip3 install browser_cookie3 requests
```

Also needed:
- macOS (uses `launchctl`, app bundle install under `/Applications`, and menu bar UI)
- Python 3 (`python3` available in PATH)
- Xcode Command Line Tools (`xcrun swiftc`) for compiling `native/Launcher.swift`
- Chrome installed with active login sessions for:
  - `claude.ai`
  - `chatgpt.com`
