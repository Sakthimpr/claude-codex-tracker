"""
Claude Pro Plan Usage Tracker v2 — macOS Menu Bar App
Calls claude.ai/api/organizations/{org}/usage directly from a headless
Playwright browser context — no page load, no visible window, no scraping.
"""

import rumps
import threading
import time
import re
import os
from datetime import datetime, timezone

REFRESH_INTERVAL = 300   # fetch every 5 minutes
REFRESH_AT_LIMIT  = 60   # fetch every 1 minute when at 100%
COOKIE_CACHE_TTL = 3600  # re-read Chrome cookies once per hour

ORG_ID = "b8418e36-3c7f-4302-a9c4-07bec8c1f471"
USAGE_API = f"https://claude.ai/api/organizations/{ORG_ID}/usage"


# ---------------------------------------------------------------------------
# Thread-safe shared data
# ---------------------------------------------------------------------------

class SharedData:
    def __init__(self):
        self._lock = threading.Lock()
        self.weekly_pct = "—"
        self.weekly_reset = "—"
        self.session_pct = "—"
        self.session_reset = "—"
        self.last_updated = "Never"
        self.status = "Starting..."
        self.on_update = None   # set by ClaudeTrackerApp to trigger immediate refresh

    def update(self, **kwargs):
        with self._lock:
            for k, v in kwargs.items():
                setattr(self, k, v)
        if self.on_update:
            self.on_update()

    def snapshot(self):
        with self._lock:
            return dict(
                weekly_pct=self.weekly_pct,
                weekly_reset=self.weekly_reset,
                session_pct=self.session_pct,
                session_reset=self.session_reset,
                last_updated=self.last_updated,
                status=self.status,
            )


shared = SharedData()


# ---------------------------------------------------------------------------
# Cookie cache — keychain accessed once per hour, not every 5 minutes
# ---------------------------------------------------------------------------

_cookie_cache = None
_cookie_cache_time = 0


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


# ---------------------------------------------------------------------------
# Format reset time as human-readable string
# ---------------------------------------------------------------------------

def format_reset(iso_str):
    """Convert ISO timestamp to 'Resets in Xhr Ymin' or 'Resets Tue 6:30 PM'."""
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
            if hours > 0:
                return f"Resets in {hours}hr {mins}min"
            return f"Resets in {mins}min"
        local_dt = dt.astimezone()
        return "Resets " + local_dt.strftime("%a %-I:%M %p")
    except Exception:
        return ""


# ---------------------------------------------------------------------------
# Scraper — headless Playwright API call, no browser window
# ---------------------------------------------------------------------------

def scrape_loop():
    from playwright.sync_api import sync_playwright
    shared.update(status="Initialising...")
    consecutive_failures = 0

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)

        while True:
            ctx = None
            at_limit = False
            try:
                force = consecutive_failures >= 2
                cookies = get_claude_cookies(force=force)

                if not cookies:
                    shared.update(status="Log in to claude.ai in Chrome first")
                    time.sleep(60)
                    continue

                ctx = browser.new_context(
                    user_agent=(
                        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                        "AppleWebKit/537.36 (KHTML, like Gecko) "
                        "Chrome/124.0.0.0 Safari/537.36"
                    )
                )
                ctx.add_cookies(cookies)

                shared.update(status="Fetching...")
                resp = ctx.request.get(
                    USAGE_API,
                    headers={"anthropic-client-platform": "web_claude_ai"},
                    timeout=20000,
                )

                if resp.status != 200:
                    consecutive_failures += 1
                    shared.update(status=f"Session expired — open claude.ai in Chrome")
                    ctx.close()
                    time.sleep(60)
                    continue

                data = resp.json()
                session = data.get("five_hour", {}) or {}
                weekly  = data.get("seven_day", {}) or {}

                # `or 0` guards against explicit null from the API (int(None) crashes)
                s_pct = int(session.get("utilization") or 0)
                w_pct = int(weekly.get("utilization")  or 0)
                at_limit = s_pct >= 100 or w_pct >= 100

                shared.update(
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
                shared.update(status=f"Error: {str(e)[:50]}")
                if ctx:
                    try:
                        ctx.close()
                    except Exception:
                        pass

                # Restart the browser after 5 back-to-back failures
                if consecutive_failures >= 5:
                    try:
                        browser.close()
                    except Exception:
                        pass
                    browser = p.chromium.launch(headless=True)
                    consecutive_failures = 0

            # Poll faster while at the limit so we catch the reset quickly
            time.sleep(REFRESH_AT_LIMIT if at_limit else REFRESH_INTERVAL)


# ---------------------------------------------------------------------------
# Menu bar app — visual helpers
# ---------------------------------------------------------------------------

def color_dot(pct_str):
    """🟢 green <50%  |  🟡 yellow 50–70%  |  🔴 red >70%"""
    try:
        pct = int(pct_str.replace("%", ""))
        if pct > 70:
            return "🔴"
        elif pct >= 50:
            return "🟡"
        else:
            return "🟢"
    except Exception:
        return "⚪"


def progress_bar(pct_str, width=10):
    """Render a Unicode block progress bar, e.g. ██████░░░░"""
    try:
        pct = int(pct_str.replace("%", ""))
        filled = round(pct / 100 * width)
        return "█" * filled + "░" * (width - filled)
    except Exception:
        return "░" * width


def bar_title_dot(pct_str):
    """Return colored dot for the menu bar title indicator."""
    try:
        pct = int(pct_str.replace("%", ""))
        if pct > 70:
            return "🔴"
        elif pct >= 50:
            return "🟡"
        else:
            return "🟢"
    except Exception:
        return "🟢"


class ClaudeTrackerApp(rumps.App):
    def __init__(self):
        super().__init__(
            "● ...",
            menu=[
                rumps.MenuItem("m_header"),
                None,
                rumps.MenuItem("m_session_label"),
                rumps.MenuItem("m_session_bar"),
                rumps.MenuItem("m_session_reset"),
                None,
                rumps.MenuItem("m_weekly_label"),
                rumps.MenuItem("m_weekly_bar"),
                rumps.MenuItem("m_weekly_reset"),
                None,
                rumps.MenuItem("m_status"),
                rumps.MenuItem("m_updated"),
                None,
                rumps.MenuItem("Refresh Now", callback=self.manual_refresh),
            ],
            quit_button="Quit",
        )

        for key in [
            "m_header",
            "m_session_label", "m_session_bar", "m_session_reset",
            "m_weekly_label", "m_weekly_bar", "m_weekly_reset",
            "m_status", "m_updated",
        ]:
            self.menu[key].set_callback(lambda _: None)

        shared.on_update = self.refresh_display   # callback for background thread

        t = threading.Thread(target=scrape_loop, daemon=True)
        t.start()

        self.refresh_display()

    def refresh_display(self):
        d = shared.snapshot()
        w = d["weekly_pct"]
        s = d["session_pct"]

        w_dot = bar_title_dot(w) if w != "—" else "⚪"
        s_dot = bar_title_dot(s) if s != "—" else "⚪"
        self.title = f"{w_dot}{s_dot}  W:{w}  S:{s}"

        self.menu["m_header"].title       = "  ◎  Claude Pro — Live Usage"
        self.menu["m_session_label"].title = f"  ⏱   Current Session (5hr window)"
        self.menu["m_session_bar"].title   = f"     {color_dot(s)}  {progress_bar(s)}  {s} used"
        self.menu["m_session_reset"].title = f"     ↻  {d['session_reset']}"
        self.menu["m_weekly_label"].title  = f"  📅  Weekly (All Models)"
        self.menu["m_weekly_bar"].title    = f"     {color_dot(w)}  {progress_bar(w)}  {w} used"
        self.menu["m_weekly_reset"].title  = f"     ↻  {d['weekly_reset']}"
        self.menu["m_status"].title        = f"  ●  Status: {d['status']}"
        self.menu["m_updated"].title       = f"  🕐  Updated: {d['last_updated']}"

    @rumps.timer(30)
    def auto_refresh_display(self, _):
        self.refresh_display()

    def manual_refresh(self, _):
        self.refresh_display()


if __name__ == "__main__":
    ClaudeTrackerApp().run()
