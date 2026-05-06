# Project Memory — Codex Tracker App

## Project
- Name: codex_tracker_app
- Path: /Users/sakthivelramasamy/Documents/Codex/codex_tracker_app
- Purpose: macOS menu bar tracker for Codex usage limits and resets.

## User Rules
- Do not write or modify code before explicit user approval.
- Use screenshot and validated API fields as source of truth for usage mapping.

## Source of Truth
- Page: https://chatgpt.com/codex/cloud/settings/analytics#usage
- API: GET /backend-api/wham/usage (Bearer token from GET /api/auth/session)
- Key fields:
  - rate_limit.primary_window.used_percent
  - rate_limit.primary_window.reset_at
  - rate_limit.secondary_window.used_percent
  - rate_limit.secondary_window.reset_at
  - credits.balance

## Current Mapping
- Session used % = rate_limit.primary_window.used_percent
- Weekly used % = rate_limit.secondary_window.used_percent
- Session remaining % = 100 - session used
- Weekly remaining % = 100 - weekly used
