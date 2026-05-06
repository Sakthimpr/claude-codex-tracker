# Codex Usage Menu Bar (macOS)

Native macOS menu-bar app that reads your Codex usage from:

`https://chatgpt.com/codex/cloud/settings/analytics#usage`

It refreshes every 5 seconds and shows:
- `W:x%` (weekly usage)
- `S:y%` (current session usage)
- reset/status/updated details in the dropdown menu

## How to run

1. Open Terminal in this folder:

```bash
cd /Users/sakthivelramasamy/Documents/Codex/CodexUsageMenuBar
```

2. Build:

```bash
swift build
```

3. Run:

```bash
swift run CodexUsageMenuBar
```

## First-time login

If menu status shows `Auth required`:
- Click the menu bar app.
- Click `Open Codex Usage Page (Login)`.
- Log in to ChatGPT in that window.
- Keep the app running; it will start scraping automatically.

## Notes

- The parser is resilient but still depends on page text structure.
- If OpenAI changes labels/layout, update parsing rules in:
  - `Sources/CodexUsageParser.swift`

