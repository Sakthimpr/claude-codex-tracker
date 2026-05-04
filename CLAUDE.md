# Claude Tracker — macOS Menu Bar App

## Build Rule (Non-Negotiable)
After **every code change**, run the full build before marking done:
```bash
cd /Users/sakthivelramasamy/Documents/Claude/claude_tracker-app
bash build.sh
```
This compiles Swift, installs the binary to `~/.local/bin/`, copies tracker_data.py to `~/.claude-tracker/`, and launches.

## Verification Rule
**Never use Playwright** to verify UI changes. Sakthivel verifies the app himself by looking at the running macOS menu bar. Do not invoke any screenshot or browser tool.

## Stack
- Data layer: Python (`tracker_data.py`) — fetches Claude usage API via Playwright + Chrome cookies, writes JSON to `/tmp/claude_tracker_data.json`
- Native binary: Swift (`native/Launcher.swift`) — plain binary (NOT a .app bundle), menu bar only
- Install locations: `~/.local/bin/claude-tracker` (binary), `~/.claude-tracker/tracker_data.py` (Python script)
- Auto-launch: `~/Library/LaunchAgents/com.sakthivel.claudetracker.plist`

## Critical Architecture Note
**Do NOT use a .app bundle.** macOS 16 blocks unsigned/ad-hoc signed `.app` bundles from registering NSStatusItems — the item never appears in the menu bar or Ice layout. Running as a plain binary (outside any bundle) works perfectly. This was confirmed through extensive debugging on 2026-04-29.

## How It Works
1. Binary launches, sets `NSApp.setActivationPolicy(.accessory)`, creates status item
2. Python (`tracker_data.py`) is launched from `~/.claude-tracker/`
3. Python fetches `https://claude.ai/api/organizations/{ORG_ID}/usage` using Chrome cookies
4. Python writes JSON to `/tmp/claude_tracker_data.json` every 5 minutes
5. Swift reads JSON every 10 seconds and updates menu bar

## Menu Bar Display
- Title: `🟢🟢  W:23%  S:10%`  (weekly dot + session dot + percentages)
- Dropdown: session progress bar, weekly progress bar, reset times, status, last updated
- Dots: 🟢 <50% | 🟡 50–70% | 🔴 >70%

## Prerequisites
```bash
pip3 install playwright browser_cookie3
playwright install chromium
```
Must be logged in to claude.ai in Chrome before launching.

## ORG_ID
Sakthivel's org ID is hardcoded in `tracker_data.py`. If it changes, update `ORG_ID` there.
