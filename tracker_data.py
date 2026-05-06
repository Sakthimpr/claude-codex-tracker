"""
Unified Claude + Codex Usage Tracker — Background Data Fetcher

Fetches usage from:
- Claude API (existing flow via playwright request context)
- Codex API (chatgpt.com authenticated API calls)

Writes JSON to /tmp/claude_tracker_data.json for the Swift menu bar app.
"""

import json
import time
from datetime import datetime, timezone

import requests

REFRESH_INTERVAL = 300      # 5 minutes
REFRESH_AT_LIMIT = 60       # 1 minute when at 100%
COOKIE_CACHE_TTL = 3600     # re-read browser cookies once per hour
OUTPUT_FILE = "/tmp/claude_tracker_data.json"

CLAUDE_ORG_ID = "b8418e36-3c7f-4302-a9c4-07bec8c1f471"
CLAUDE_USAGE_API = f"https://claude.ai/api/organizations/{CLAUDE_ORG_ID}/usage"

CHATGPT_SESSION_API = "https://chatgpt.com/api/auth/session"
CODEX_USAGE_API = "https://chatgpt.com/backend-api/wham/usage"
CODEX_REFERER = "https://chatgpt.com/codex/cloud/settings/analytics#usage"

_claude_cookie_cache = None
_claude_cookie_cache_time = 0
_chatgpt_cookie_cache = None
_chatgpt_cookie_cache_time = 0


def now_str():
    return datetime.now().strftime("%d %b  %H:%M:%S")


def write_data(**kwargs):
    try:
        with open(OUTPUT_FILE, "w") as f:
            json.dump(kwargs, f)
    except Exception:
        pass


def safe_int(value, default=0):
    try:
        return int(value)
    except Exception:
        return default


def percent_str(value):
    if value is None:
        return "—"
    return f"{value}%"


def format_reset_iso(iso_str):
    try:
        dt = datetime.fromisoformat(iso_str.replace("Z", "+00:00"))
        now = datetime.now(timezone.utc)
        diff = dt - now
        total_secs = int(diff.total_seconds())
        if total_secs <= 0:
            return "Resetting soon"
        hours = total_secs // 3600
        mins = (total_secs % 3600) // 60
        if hours < 24:
            return f"Resets in {hours}hr {mins}min" if hours > 0 else f"Resets in {mins}min"
        return "Resets " + dt.astimezone().strftime("%a %-I:%M %p")
    except Exception:
        return "—"


def format_reset_epoch(epoch_seconds):
    try:
        dt = datetime.fromtimestamp(int(epoch_seconds), timezone.utc)
        now = datetime.now(timezone.utc)
        diff = dt - now
        total_secs = int(diff.total_seconds())
        if total_secs <= 0:
            return "Resetting soon"
        hours = total_secs // 3600
        mins = (total_secs % 3600) // 60
        if hours < 24:
            return f"Resets in {hours}hr {mins}min" if hours > 0 else f"Resets in {mins}min"
        return "Resets " + dt.astimezone().strftime("%a %-I:%M %p")
    except Exception:
        return "—"


def get_claude_cookies(force=False):
    global _claude_cookie_cache, _claude_cookie_cache_time
    now = time.time()
    if not force and _claude_cookie_cache and (now - _claude_cookie_cache_time) < COOKIE_CACHE_TTL:
        return _claude_cookie_cache

    try:
        import browser_cookie3
        jar = browser_cookie3.chrome(domain_name=".claude.ai")
    except Exception:
        return []

    cookies = []
    for c in jar:
        cookie = {
            "name": c.name,
            "value": c.value,
            "domain": c.domain if c.domain.startswith(".") else "." + c.domain,
            "path": c.path or "/",
            "secure": bool(c.secure),
            "httpOnly": False,
            "sameSite": "Lax",
        }
        if c.expires:
            cookie["expires"] = float(c.expires)
        cookies.append(cookie)

    _claude_cookie_cache = cookies
    _claude_cookie_cache_time = now
    return cookies


def get_chatgpt_cookies(force=False):
    global _chatgpt_cookie_cache, _chatgpt_cookie_cache_time
    now = time.time()
    if not force and _chatgpt_cookie_cache and (now - _chatgpt_cookie_cache_time) < COOKIE_CACHE_TTL:
        return _chatgpt_cookie_cache

    try:
        import browser_cookie3
        jar = browser_cookie3.chrome(domain_name=".chatgpt.com")
    except Exception:
        return None

    _chatgpt_cookie_cache = jar
    _chatgpt_cookie_cache_time = now
    return jar


def default_block(status):
    return {
        "status": status,
        "weekly_pct": "—",
        "session_pct": "—",
        "weekly_reset": "—",
        "session_reset": "—",
        "weekly_used_pct": None,
        "session_used_pct": None,
        "weekly_remaining_pct": None,
        "session_remaining_pct": None,
        "credits_balance": "—",
        "last_updated": now_str(),
    }


def build_payload(claude_block, codex_block):
    # Keep existing top-level keys for backward compatibility with current Swift UI.
    payload = {
        "status": claude_block["status"],
        "weekly_pct": claude_block["weekly_pct"],
        "session_pct": claude_block["session_pct"],
        "weekly_reset": claude_block["weekly_reset"],
        "session_reset": claude_block["session_reset"],
        "last_updated": now_str(),
        "claude": claude_block,
        "codex": codex_block,
    }
    return payload


def fetch_claude_usage(browser, consecutive_failures):
    ctx = None
    try:
        cookies = get_claude_cookies(force=(consecutive_failures >= 2))
        if not cookies:
            return default_block("Log in to claude.ai in Chrome first"), False, consecutive_failures + 1, browser

        ctx = browser.new_context(user_agent=(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
            "AppleWebKit/537.36 (KHTML, like Gecko) "
            "Chrome/124.0.0.0 Safari/537.36"
        ))
        ctx.add_cookies(cookies)

        resp = ctx.request.get(
            CLAUDE_USAGE_API,
            headers={"anthropic-client-platform": "web_claude_ai"},
            timeout=20000,
        )

        if resp.status != 200:
            return default_block("Session expired — open claude.ai in Chrome"), False, consecutive_failures + 1, browser

        data = resp.json()
        session = data.get("five_hour", {}) or {}
        weekly = data.get("seven_day", {}) or {}

        session_used = safe_int(session.get("utilization"), 0)
        weekly_used = safe_int(weekly.get("utilization"), 0)
        session_remaining = max(0, 100 - session_used)
        weekly_remaining = max(0, 100 - weekly_used)

        block = {
            "status": "Live",
            "session_pct": percent_str(session_used),
            "weekly_pct": percent_str(weekly_used),
            "session_reset": format_reset_iso(session.get("resets_at", "")),
            "weekly_reset": format_reset_iso(weekly.get("resets_at", "")),
            "session_used_pct": session_used,
            "weekly_used_pct": weekly_used,
            "session_remaining_pct": session_remaining,
            "weekly_remaining_pct": weekly_remaining,
            "credits_balance": "—",
            "last_updated": now_str(),
        }
        at_limit = session_used >= 100 or weekly_used >= 100
        return block, at_limit, 0, browser

    except Exception as e:
        failures = consecutive_failures + 1
        return default_block(f"Error: {str(e)[:60]}"), False, failures, browser
    finally:
        if ctx:
            try:
                ctx.close()
            except Exception:
                pass


def fetch_codex_usage(consecutive_failures):
    try:
        cookies = get_chatgpt_cookies(force=(consecutive_failures >= 2))
        if not cookies:
            return default_block("Log in to chatgpt.com in Chrome first"), False, consecutive_failures + 1

        session = requests.Session()
        session.cookies = cookies

        session_resp = session.get(
            CHATGPT_SESSION_API,
            headers={"accept": "application/json, text/plain, */*"},
            timeout=20,
        )
        if session_resp.status_code != 200:
            return default_block("Auth expired — open chatgpt.com in Chrome"), False, consecutive_failures + 1

        token = (session_resp.json() or {}).get("accessToken")
        if not token:
            return default_block("Auth token missing — open chatgpt.com"), False, consecutive_failures + 1

        usage_resp = session.get(
            CODEX_USAGE_API,
            headers={
                "accept": "application/json, text/plain, */*",
                "authorization": f"Bearer {token}",
                "origin": "https://chatgpt.com",
                "referer": CODEX_REFERER,
                "user-agent": (
                    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                    "AppleWebKit/537.36 (KHTML, like Gecko) "
                    "Chrome/124.0.0.0 Safari/537.36"
                ),
            },
            timeout=20,
        )

        if usage_resp.status_code == 401:
            return default_block("Unauthorized — refresh ChatGPT login"), False, consecutive_failures + 1
        if usage_resp.status_code == 403:
            return default_block("Forbidden — Codex analytics access required"), False, consecutive_failures + 1
        if usage_resp.status_code != 200:
            return default_block(f"Codex API error: {usage_resp.status_code}"), False, consecutive_failures + 1

        data = usage_resp.json() or {}
        rate_limit = data.get("rate_limit", {}) or {}
        primary = rate_limit.get("primary_window", {}) or {}
        secondary = rate_limit.get("secondary_window", {}) or {}
        credits = data.get("credits", {}) or {}

        session_used = safe_int(primary.get("used_percent"), 0)
        weekly_used = safe_int(secondary.get("used_percent"), 0)
        session_remaining = max(0, 100 - session_used)
        weekly_remaining = max(0, 100 - weekly_used)

        block = {
            "status": "Live",
            "session_pct": percent_str(session_used),
            "weekly_pct": percent_str(weekly_used),
            "session_reset": format_reset_epoch(primary.get("reset_at")),
            "weekly_reset": format_reset_epoch(secondary.get("reset_at")),
            "session_used_pct": session_used,
            "weekly_used_pct": weekly_used,
            "session_remaining_pct": session_remaining,
            "weekly_remaining_pct": weekly_remaining,
            "credits_balance": str(credits.get("balance", "0")),
            "last_updated": now_str(),
        }
        at_limit = session_used >= 100 or weekly_used >= 100
        return block, at_limit, 0

    except Exception as e:
        return default_block(f"Error: {str(e)[:60]}"), False, consecutive_failures + 1


def main():
    from playwright.sync_api import sync_playwright

    claude_block = default_block("Starting...")
    codex_block = default_block("Starting...")
    write_data(**build_payload(claude_block, codex_block))

    claude_failures = 0
    codex_failures = 0

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)

        while True:
            claude_block, claude_at_limit, claude_failures, browser = fetch_claude_usage(
                browser, claude_failures
            )
            codex_block, codex_at_limit, codex_failures = fetch_codex_usage(codex_failures)

            if claude_failures >= 5:
                try:
                    browser.close()
                except Exception:
                    pass
                browser = p.chromium.launch(headless=True)
                claude_failures = 0

            write_data(**build_payload(claude_block, codex_block))
            time.sleep(REFRESH_AT_LIMIT if (claude_at_limit or codex_at_limit) else REFRESH_INTERVAL)


if __name__ == "__main__":
    main()
