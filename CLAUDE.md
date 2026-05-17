# Claude Codex Tracker — Project Instructions

## Project Overview
Menu bar app (Swift + Python) that shows Claude and Codex usage side-by-side.
- `src/native/Launcher.swift` — macOS menu bar app (SwiftUI/AppKit)
- `src/python/tracker_data.py` — background daemon: fetches usage, writes JSON, pushes to Supabase
- `web/index.html` — hosted web page for mobile view (reads from Supabase)
- `scripts/build.sh` — build, package, and install script
- `web/config.js` — local Supabase credentials for the web page (gitignored, never commit)
- `~/.claude-tracker/supabase.json` — Supabase service_role key for the Mac daemon (chmod 600)

## Task → Section Map
| Task area | File | Key symbol |
|---|---|---|
| Usage fetch logic | `src/python/tracker_data.py` | `fetch_claude_usage`, `fetch_codex_usage` |
| Supabase push | `src/python/tracker_data.py` | `push_to_supabase` |
| Menu bar UI | `src/native/Launcher.swift` | `lbHeader`, `updateUI`, `loadData` |
| Web mobile view | `web/index.html` | `loadData()` (JS), `render()` |
| Build/install | `scripts/build.sh` | Step 3: Install |

---

## Security & Vulnerability Notes
> All five findings below were identified in a security review (May 2026) and have been fixed.
> Document here so they are never re-introduced.

### VULN-01 (Critical) — Hardcoded Supabase key in web/index.html
**What happened:** `SUPABASE_URL` and `SUPABASE_ANON_KEY` were hardcoded directly in `web/index.html` lines 274–275, committing real credentials to git and exposing them publicly.

**Fix applied:** Removed hardcoded values. `index.html` now loads `<script src="config.js"></script>`. `config.js` is gitignored. `config.js.example` holds the template.

**Rule:** Never hardcode any key in `index.html`. Always load from `config.js`. Verify `.gitignore` covers `web/config.js` before every push.

---

### VULN-02 (Critical) — Public anon write path to Supabase allowed data tampering
**What happened:** README recommended RLS policies that gave anonymous users full insert/update access to `tracker_snapshot`. Anyone with the deployed URL could overwrite row id=1 and inject false metrics.

**Fix applied:**
- RLS is now anon read-only (`select`).
- Insert/update require `auth.role() = 'service_role'`.
- `push_to_supabase` in `tracker_data.py` now reads `service_role_key` from `~/.claude-tracker/supabase.json` (chmod 600), never the anon key.

**Rule:** The Mac daemon uses `service_role_key` for writes. The browser uses `anon` key for reads only. Never swap these. Never put `service_role_key` in `config.js`.

---

### VULN-03 (High) — Silent exception swallowing hid failures and caused stale state
**What happened:** `write_data` and `push_to_supabase` both used bare `except Exception: pass`, so any failure was invisible — the UI showed stale data with no indication of the cause.

**Fix applied:** Both functions now log errors with timestamps to `/tmp/claude-tracker-fetcher.log` using Python `logging`. The log file is append-only and survives daemon restarts.

**Rule:** Never use `except Exception: pass` in this project. Always log with `_log.error(...)`. If a failure is truly non-fatal, it still needs a log entry.

---

### VULN-04 (Medium) — No retry/backoff on transient network errors
**What happened:** All API calls in `fetch_claude_usage` and `fetch_codex_usage` used bare `requests.Session()` with no retry strategy. A single dropped packet caused a visible fetch failure.

**Fix applied:** `_make_session_with_retry()` helper creates sessions with `urllib3.Retry(total=3, backoff_factor=0.5, status_forcelist=[429,500,502,503,504])`. Both fetch functions use this instead of `requests.Session()`.

**Rule:** All outbound HTTP sessions in this project must use `_make_session_with_retry()`. Never use `requests.Session()` directly for API calls.

---

### VULN-05 (Medium) — Broad pkill -f patterns in build.sh could kill unrelated processes
**What happened:** `pkill -f "tracker_data.py"` matches any process whose full command line contains that string — including scripts in other projects with the same filename.

**Fix applied:** Replaced with:
- `pkill -x "${BINARY_NAME}"` — exact binary name match only
- `kill "$(pgrep -f "python.*${INSTALL_DIR}/tracker_data\.py")"` — anchored to the exact installed path
- `pkill -x "ClaudeTracker"` — exact match

**Rule:** Never use `pkill -f <partial-name>` in build scripts. Always anchor to exact path or use `-x` for exact name match.

---

### VULN-06 (Low) — Silent parse failure in Launcher.swift loadData() gave no diagnostic
**What happened:** If `data.json` was corrupt or partially written, `JSONSerialization` would fail and `loadData()` returned silently — the UI showed stale data with no error state.

**Fix applied:** On parse failure, `loadData()` now:
1. Appends a timestamped entry to `/tmp/claude-tracker-fetcher.log`
2. Sets `lbHeader` to a red "● Data parse error" label pointing to the log file

**Rule:** Any data load failure in Swift must update `lbHeader` to a visible error state. Never return silently from `loadData()` on a parse failure.

---

## Anti-Patterns (Never Repeat)
- Do not hardcode Supabase URLs or keys anywhere in committed files
- Do not use `except Exception: pass` — always log
- Do not use `requests.Session()` directly — always `_make_session_with_retry()`
- Do not use `pkill -f <partial-name>` in build scripts
- Do not return silently from `loadData()` on any error path
