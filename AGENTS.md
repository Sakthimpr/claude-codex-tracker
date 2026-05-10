# Claude + Codex Tracker — Project AGENTS Guide

## Project Root
- `/Users/sakthivelramasamy/Documents/Codex/claude_codex_tracker`

## Primary Build Rule
After any code change, run:
```bash
cd /Users/sakthivelramasamy/Documents/Codex/claude_codex_tracker
./build.sh
```

## What `build.sh` does
1. Verifies Python and required packages (`playwright`, `browser_cookie3`, `requests`)
2. Compiles Swift menu binary from `native/Launcher.swift`
3. Builds app icon from `assets/ClaudeCodexIcon1024.png`
4. Installs binary to `~/.local/bin/claude-tracker`
5. Installs fetcher to `~/.claude-tracker/tracker_data.py`
6. Recreates launcher app at `/Applications/Claude_Codex_Tracker.app`
7. Rewrites/loads LaunchAgent at `~/Library/LaunchAgents/com.sakthivel.claudetracker.plist`
8. Launches the tracker

## Runtime Architecture
- UI layer: Swift (`native/Launcher.swift`)
- Data layer: Python (`tracker_data.py`)
- Shared data file: `/tmp/claude_tracker_data.json`

Flow:
1. Swift app starts as accessory app and renders menu bar UI.
2. Swift ensures Python fetcher is running.
3. Python fetches:
   - Claude usage from `claude.ai` APIs
   - Codex usage from `chatgpt.com` APIs
4. Python writes unified payload to `/tmp/claude_tracker_data.json`.
5. Swift polls and updates menu UI.

## Refresh/Polling Defaults
- Python normal refresh: 5 min
- Python at-limit refresh: 1 min
- Swift UI poll: 10 sec

## Current Install/Launch Paths
- Binary: `~/.local/bin/claude-tracker`
- Python script: `~/.claude-tracker/tracker_data.py`
- LaunchAgent: `~/Library/LaunchAgents/com.sakthivel.claudetracker.plist`
- macOS app launcher: `/Applications/Claude_Codex_Tracker.app`

## Accounts and Auth
- User must be logged in on Chrome for:
  - `claude.ai`
  - `chatgpt.com`
- Cookies are read via `browser_cookie3`.

## Prerequisites
```bash
pip3 install playwright browser_cookie3 requests
playwright install chromium
```

## UI/Product Notes
- Menu header currently shows:
  - `Claude & Codex_Live Tracker`
  - `Updated_HH:MM`
- Session/Weekly rows are color-coded by usage threshold:
  - `>= 90` red
  - `>= 50` amber
  - else green
- Menu bar indicator dots follow the same threshold logic.

## Working Rules for This Project
- Prefer local code + screenshots for UI iteration.
- Do not use web search for local UI styling/debugging unless explicitly requested.
- Keep changes scoped and avoid unrelated refactors.

## Error Prevention Rules (Mandatory)
- If a mistake is identified by user feedback or self-review, update this `AGENTS.md` immediately with:
  1. what went wrong,
  2. root cause,
  3. concrete prevention rule.
- Apply the prevention rule in the same session before continuing.
- Never repeat a known mistake without first checking this file.
- Hard guardrail for this project: do not call the `web` tool at all unless the user explicitly asks for web lookup in that same prompt.

## Mistake Learning Log
### 2026-05-07 — Unnecessary web search during local UI work
- What went wrong:
  - Web search/tool was used while working on purely local tracker UI changes.
- Root cause:
  - Tool-selection discipline was not followed for a local-only task.
- Prevention rule:
  - For this tracker project, use only local files, local commands, and user screenshots unless the user explicitly asks for web lookup.

### 2026-05-07 — Repeat: accidental web tool usage during local UI task
- What went wrong:
  - `web` tool was triggered again even though task was local UI tuning.
- Root cause:
  - Execution flow did not enforce the no-web guardrail strongly enough.
- Prevention rule:
  - Before any action on this project, verify: "Is this solvable via local code/screenshots?" If yes, prohibit `web` tool calls.
  - Only allow `web` tool if user message explicitly asks to browse/search web.
