# Skills Needed — Codex Tracker App

## 1) Authenticated API Retrieval
- Read ChatGPT session token from /api/auth/session.
- Call /backend-api/wham/usage with Bearer token.
- Handle 401/403/token refresh safely.

## 2) Usage Data Normalization
- Map API response to UI-ready fields.
- Convert epoch reset times to local timezone.
- Expose both used % and remaining %.

## 3) Menu Bar UX
- Compact top bar text (weekly/session indicators).
- Detailed dropdown with resets, status, updated time, credits.
- Error states: auth expired, forbidden, network, parse error.

## 4) Lightweight Polling
- 5-second refresh cycle (configurable).
- Backoff/retry strategy for failures.
- Minimal CPU and network overhead.

## 5) Integration Strategy
- Single menu app for both Claude and Codex sections.
- Shared local JSON contract for UI polling.
- Unified launch/startup behavior.
