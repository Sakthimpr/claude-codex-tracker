# Claude & Codex Tracker

A macOS menu bar app that shows your real-time usage for **Claude** (Anthropic) and **Codex** (OpenAI) — session limits, weekly limits, reset countdowns, and threshold warnings.

Runs silently in the background. No Dock icon. Just a menu bar item you click when you need it.

---

## Prerequisites

| Requirement | Notes |
|---|---|
| macOS 13 or later | Uses Cocoa menu bar and launchctl |
| Google Chrome | Must be logged in to `claude.ai` and `chatgpt.com` |
| Python 3 | `python3` must be available in PATH |
| Xcode Command Line Tools | For compiling the Swift binary |

**Install Xcode Command Line Tools** (if not already done):
```bash
xcode-select --install
```

**Install required Python packages:**
```bash
pip3 install browser_cookie3 requests
```

---

## Install

```bash
git clone https://github.com/Sakthimpr/claude-codex-tracker.git
cd claude-codex-tracker
bash build.sh
```

The tracker starts automatically and appears in your menu bar. It also registers a LaunchAgent so it restarts on every login — no manual steps needed.

---

## Verify it's working

Click the menu bar icon. You should see usage dials for Claude and Codex load within a few seconds.

If you see an error or dashes instead of numbers, make sure you are logged in to `claude.ai` and `chatgpt.com` in Chrome, then click **Refresh now**.

---

## Using the app

| Action | How |
|---|---|
| View usage | Click the menu bar icon |
| Switch used ↔ remaining % | Click **Show Remaining %** or press `⌘M` |
| Open Claude usage page | Click **Open Claude Analytics** |
| Open Codex usage page | Click **Open Codex Analytics** |
| Force a refresh | Click **Refresh now** |
| Quit | Click **Quit** |

---

## Troubleshooting

**"Session expired" or auth errors**
Log in again on Chrome for `claude.ai` and `chatgpt.com`, then click Refresh now.

**"Claude org not found"**
Set the environment variable `CLAUDE_ORG_ID` to your org UUID (visible in the `claude.ai` URL when browsing your account settings).

**App not appearing after a reboot**
Run `bash build.sh` again to reinstall and reload the LaunchAgent.

**macOS blocked the app (Gatekeeper)**
If you received a pre-built binary rather than building from source, right-click the app → Open → Open anyway. This is a one-time step.

---

## Uninstall

```bash
launchctl unload ~/Library/LaunchAgents/com.sakthivel.claudetracker.plist
rm ~/Library/LaunchAgents/com.sakthivel.claudetracker.plist
rm ~/.local/bin/claude-tracker
rm -rf ~/.claude-tracker
rm -rf /Applications/Claude_Codex_Tracker.app
```

---

## How it works

| Layer | File | Role |
|---|---|---|
| UI | `src/native/Launcher.swift` | Menu bar app — dials, colors, warning banners |
| Data | `src/python/tracker_data.py` | Background daemon — fetches usage from APIs |
| Shared state | `~/.cache/claude-codex-tracker/data.json` | Written by Python, read by Swift every 10s |

**Auth:** Claude's API accepts cookie-authenticated requests directly. Codex requires a Bearer token, which the fetcher obtains from `chatgpt.com/api/auth/session` using your Chrome session.

**Refresh intervals:** Every 5 minutes normally, every 1 minute when at the usage limit.

---

## Privacy

This app reads Chrome cookies for `claude.ai` and `chatgpt.com` only. All data stays on your machine — nothing is sent anywhere other than the official Claude and Codex usage APIs.
