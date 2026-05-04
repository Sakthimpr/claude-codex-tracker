"""
Claude Pro Plan Usage Tracker — Background Data Fetcher
Fetches usage from claude.ai API every 5 minutes and writes JSON to
/tmp/claude_tracker_data.json for the Swift menu bar app to poll.
No UI — pure background data writer.
"""

import json
import time
from datetime import datetime, timezone

REFRESH_INTERVAL = 300     # 5 minutes
REFRESH_AT_LIMIT = 60      # 1 minute when at 100%
COOKIE_CACHE_TTL = 3600    # re-read Chrome cookies once per hour
OUTPUT_FILE = "/tmp/claude_tracker_data.json"

ORG_ID    = "b8418e36-3c7f-4302-a9c4-07bec8c1f471"
USAGE_API = f"https://claude.ai/api/organizations/{ORG_ID}/usage"

_cookie_cache = None
_cookie_cache_time = 0


def write_data(**kwargs):
    try:
        with open(OUTPUT_FILE, "w") as f:
            json.dump(kwargs, f)
    except Exception:
        pass


def get_claude_cookies(force=False):
    global _cookie_cache, _cookie_cache_time
    now = time.time()
    if not force and _cookie_cache and (now - _cookie_cache_time) < COOKIE_CACHE_TTL:
        return _cookie_cache

    import browser_cookie3
    jar = browser_cookie3.chrome(domain_name=".claude.ai")
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

    _cookie_cache = cookies
    _cookie_cache_time = now
    return cookies


def format_reset(iso_str):
    try:
        dt = datetime.fromisoformat(iso_str.replace("Z", "+00:00"))
        now = datetime.now(timezone.utc)
        diff = dt - now
        total_secs = int(diff.total_seconds())
        if total_secs <= 0:
            return "Resetting soon"
        hours = total_secs // 3600
        mins  = (total_secs % 3600) // 60
        if hours < 24:
            return f"Resets in {hours}hr {mins}min" if hours > 0 else f"Resets in {mins}min"
        return "Resets " + dt.astimezone().strftime("%a %-I:%M %p")
    except Exception:
        return ""


def main():
    write_data(status="Starting...", weekly_pct="—", session_pct="—",
               weekly_reset="—", session_reset="—", last_updated="Never")

    from playwright.sync_api import sync_playwright

    consecutive_failures = 0

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)

        while True:
            ctx = None
            at_limit = False
            try:
                cookies = get_claude_cookies(force=(consecutive_failures >= 2))

                if not cookies:
                    write_data(status="Log in to claude.ai in Chrome first",
                               weekly_pct="—", session_pct="—",
                               weekly_reset="—", session_reset="—",
                               last_updated=datetime.now().strftime("%d %b  %H:%M:%S"))
                    time.sleep(60)
                    continue

                ctx = browser.new_context(user_agent=(
                    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                    "AppleWebKit/537.36 (KHTML, like Gecko) "
                    "Chrome/124.0.0.0 Safari/537.36"
                ))
                ctx.add_cookies(cookies)

                resp = ctx.request.get(
                    USAGE_API,
                    headers={"anthropic-client-platform": "web_claude_ai"},
                    timeout=20000,
                )

                if resp.status != 200:
                    consecutive_failures += 1
                    write_data(status="Session expired — open claude.ai in Chrome",
                               weekly_pct="—", session_pct="—",
                               weekly_reset="—", session_reset="—",
                               last_updated=datetime.now().strftime("%d %b  %H:%M:%S"))
                    ctx.close()
                    time.sleep(60)
                    continue

                data    = resp.json()
                session = data.get("five_hour", {}) or {}
                weekly  = data.get("seven_day",  {}) or {}

                s_pct    = int(session.get("utilization") or 0)
                w_pct    = int(weekly.get("utilization")  or 0)
                at_limit = s_pct >= 100 or w_pct >= 100

                write_data(
                    status="Live",
                    last_updated=datetime.now().strftime("%d %b  %H:%M:%S"),
                    session_pct=f"{s_pct}%",
                    session_reset=format_reset(session.get("resets_at", "")),
                    weekly_pct=f"{w_pct}%",
                    weekly_reset=format_reset(weekly.get("resets_at", "")),
                )
                consecutive_failures = 0
                ctx.close()

            except Exception as e:
                consecutive_failures += 1
                write_data(status=f"Error: {str(e)[:60]}",
                           weekly_pct="—", session_pct="—",
                           weekly_reset="—", session_reset="—",
                           last_updated=datetime.now().strftime("%d %b  %H:%M:%S"))
                if ctx:
                    try:
                        ctx.close()
                    except Exception:
                        pass

                if consecutive_failures >= 5:
                    try:
                        browser.close()
                    except Exception:
                        pass
                    browser = p.chromium.launch(headless=True)
                    consecutive_failures = 0

            time.sleep(REFRESH_AT_LIMIT if at_limit else REFRESH_INTERVAL)


if __name__ == "__main__":
    main()
