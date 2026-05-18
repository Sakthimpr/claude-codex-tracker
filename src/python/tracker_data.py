"""
Unified Claude + Codex Usage Tracker — Background Data Fetcher

Fetches usage from:
- Claude API (direct authenticated requests via Chrome cookies)
- Codex API (chatgpt.com authenticated API calls)

Writes JSON to ~/.cache/claude-codex-tracker/data.json for the Swift menu bar app.
"""

import json
import logging
import os
import time
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from tempfile import NamedTemporaryFile

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

logging.basicConfig(
    filename="/tmp/claude-tracker-fetcher.log",
    level=logging.ERROR,
    format="%(asctime)s %(levelname)s %(message)s",
)
_log = logging.getLogger(__name__)

REFRESH_INTERVAL = 300      # 5 minutes
REFRESH_AT_LIMIT = 60       # 1 minute when at 100%
COOKIE_CACHE_TTL = 3600     # re-read browser cookies once per hour
OUTPUT_FILE = os.path.expanduser("~/.cache/claude-codex-tracker/data.json")

CLAUDE_ORGS_API = "https://claude.ai/api/organizations"
SUPABASE_CONFIG_PATH = os.path.expanduser("~/.claude-tracker/supabase.json")
CLAUDE_ORG_ID = os.getenv("CLAUDE_ORG_ID", "").strip()

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
        out_dir = os.path.dirname(OUTPUT_FILE) or "."
        os.makedirs(out_dir, mode=0o700, exist_ok=True)
        with NamedTemporaryFile(
            mode="w",
            dir=out_dir,
            delete=False,
            encoding="utf-8",
        ) as f:
            json.dump(kwargs, f)
            tmp_name = f.name

        # Restrict to current user and atomically replace to avoid partial reads.
        try:
            os.chmod(tmp_name, 0o600)
        except Exception:
            pass
        os.replace(tmp_name, OUTPUT_FILE)
        try:
            os.chmod(OUTPUT_FILE, 0o600)
        except Exception:
            pass
    except Exception as e:
        _log.error("write_data failed: %s", e)


def safe_int(value, default=0):
    try:
        return int(value)
    except Exception:
        return default


def percent_str(value):
    if value is None:
        return "—"
    return f"{value}%"


def format_reset_datetime(dt):
    try:
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


def format_reset_iso(iso_str):
    try:
        dt = datetime.fromisoformat(iso_str.replace("Z", "+00:00"))
        return format_reset_datetime(dt)
    except Exception:
        return "—"


def format_reset_epoch(epoch_seconds):
    try:
        dt = datetime.fromtimestamp(int(epoch_seconds), timezone.utc)
        return format_reset_datetime(dt)
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
        return None

    _claude_cookie_cache = jar
    _claude_cookie_cache_time = now
    return jar


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
        "plan_label": "—",
        "weekly_pct": "—",
        "session_pct": "—",
        "weekly_reset": "—",
        "session_reset": "—",
        "weekly_used_pct": None,
        "session_used_pct": None,
        "weekly_remaining_pct": None,
        "session_remaining_pct": None,
        "credits_balance": "—",
        "design_weekly_pct": "—",
        "design_weekly_reset": "—",
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


def normalize_claude_plan(org_data):
    if not isinstance(org_data, dict):
        return "CLAUDE"
    caps = org_data.get("capabilities") or []
    cap_text = " ".join(caps).lower() if isinstance(caps, list) else str(caps).lower()
    if "claude_max" in cap_text or "max" in cap_text:
        return "MAX"
    if "claude_pro" in cap_text or "pro" in cap_text:
        return "PRO"
    if "free" in cap_text:
        return "FREE"
    return "CLAUDE"


def normalize_codex_plan(plan_type):
    raw = str(plan_type or "").strip().lower()
    if not raw:
        return "CODEX"
    if "max" in raw:
        return "MAX"
    if "plus" in raw:
        return "PLUS"
    if "pro" in raw:
        return "PRO"
    if "team" in raw:
        return "TEAM"
    if "enterprise" in raw:
        return "ENTERPRISE"
    if "free" in raw:
        return "FREE"
    return raw.upper()


def _extract_org_id(payload):
    if isinstance(payload, dict):
        for key in ("id", "uuid", "organization_id", "org_id"):
            v = payload.get(key)
            if isinstance(v, str) and v.strip():
                return v.strip()

        for key in ("organization", "org", "active_organization", "current_organization"):
            nested = payload.get(key)
            found = _extract_org_id(nested)
            if found:
                return found

        for key in ("organizations", "items", "results", "memberships", "data"):
            nested = payload.get(key)
            found = _extract_org_id(nested)
            if found:
                return found

    if isinstance(payload, list):
        for item in payload:
            found = _extract_org_id(item)
            if found:
                return found

    return None


def resolve_claude_org_id(session):
    if CLAUDE_ORG_ID:
        return CLAUDE_ORG_ID

    resp = session.get(
        CLAUDE_ORGS_API,
        headers={
            "accept": "application/json, text/plain, */*",
            "anthropic-client-platform": "web_claude_ai",
            "origin": "https://claude.ai",
            "referer": "https://claude.ai/",
        },
        timeout=20,
    )
    if resp.status_code != 200:
        return None

    try:
        payload = resp.json()
    except Exception:
        return None
    return _extract_org_id(payload)


def _make_session_with_retry():
    session = requests.Session()
    retry = Retry(total=3, backoff_factor=0.5, status_forcelist=[429, 500, 502, 503, 504])
    session.mount("https://", HTTPAdapter(max_retries=retry))
    return session


def fetch_claude_usage(consecutive_failures):
    try:
        cookies = get_claude_cookies(force=(consecutive_failures >= 2))
        if not cookies:
            return default_block("Log in to claude.ai in Chrome first"), False, consecutive_failures + 1

        session = _make_session_with_retry()
        session.cookies = cookies

        org_id = resolve_claude_org_id(session)
        if not org_id:
            return default_block("Claude org not found — set CLAUDE_ORG_ID"), False, consecutive_failures + 1

        claude_usage_api = f"https://claude.ai/api/organizations/{org_id}/usage"
        claude_org_api = f"https://claude.ai/api/organizations/{org_id}"

        resp = session.get(
            claude_usage_api,
            headers={
                "accept": "application/json, text/plain, */*",
                "anthropic-client-platform": "web_claude_ai",
                "origin": "https://claude.ai",
                "referer": "https://claude.ai/",
                "user-agent": (
                    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                    "AppleWebKit/537.36 (KHTML, like Gecko) "
                    "Chrome/124.0.0.0 Safari/537.36"
                ),
            },
            timeout=20,
        )

        if resp.status_code != 200:
            return default_block("Session expired — open claude.ai in Chrome"), False, consecutive_failures + 1

        data = resp.json()
        org_resp = session.get(
            claude_org_api,
            headers={
                "accept": "application/json, text/plain, */*",
                "anthropic-client-platform": "web_claude_ai",
                "origin": "https://claude.ai",
                "referer": "https://claude.ai/",
            },
            timeout=20,
        )
        org_data = org_resp.json() if org_resp.status_code == 200 else {}
        session_window = data.get("five_hour", {}) or {}
        weekly_window = data.get("seven_day", {}) or {}
        design_window = data.get("seven_day_omelette", {}) or {}

        session_used = safe_int(session_window.get("utilization"), 0)
        weekly_used = safe_int(weekly_window.get("utilization"), 0)
        design_used = safe_int(design_window.get("utilization"), 0) if design_window else None
        session_remaining = max(0, 100 - session_used)
        weekly_remaining = max(0, 100 - weekly_used)

        block = {
            "status": "Live",
            "plan_label": normalize_claude_plan(org_data),
            "session_pct": percent_str(session_used),
            "weekly_pct": percent_str(weekly_used),
            "session_reset": format_reset_iso(session_window.get("resets_at", "")),
            "weekly_reset": format_reset_iso(weekly_window.get("resets_at", "")),
            "session_used_pct": session_used,
            "weekly_used_pct": weekly_used,
            "session_remaining_pct": session_remaining,
            "weekly_remaining_pct": weekly_remaining,
            "credits_balance": "—",
            "design_weekly_pct": percent_str(design_used) if design_used is not None else "—",
            "design_weekly_reset": format_reset_iso(design_window.get("resets_at", "")) if design_window else "—",
            "last_updated": now_str(),
        }
        at_limit = session_used >= 100 or weekly_used >= 100
        return block, at_limit, 0

    except Exception as e:
        failures = consecutive_failures + 1
        return default_block(f"Error: {str(e)[:60]}"), False, failures


def fetch_codex_usage(consecutive_failures):
    try:
        cookies = get_chatgpt_cookies(force=(consecutive_failures >= 2))
        if not cookies:
            return default_block("Log in to chatgpt.com in Chrome first"), False, consecutive_failures + 1

        session = _make_session_with_retry()
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
            "plan_label": normalize_codex_plan(data.get("plan_type")),
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


def push_to_supabase(payload):
    try:
        if not os.path.exists(SUPABASE_CONFIG_PATH):
            _log.error("push_to_supabase: config file missing at %s", SUPABASE_CONFIG_PATH)
            return
        with open(SUPABASE_CONFIG_PATH, encoding="utf-8") as f:
            cfg = json.load(f)
        url = cfg.get("url", "").rstrip("/")
        key = cfg.get("service_role_key", "")
        if not url or not key:
            _log.error("push_to_supabase: url or service_role_key missing from %s", SUPABASE_CONFIG_PATH)
            return
        endpoint = f"{url}/rest/v1/tracker_snapshot"
        row = {"id": 1, "data": json.dumps(payload), "updated_at": datetime.now(timezone.utc).isoformat()}
        resp = requests.post(
            endpoint,
            json=row,
            headers={
                "apikey": key,
                "Authorization": f"Bearer {key}",
                "Content-Type": "application/json",
                "Prefer": "resolution=merge-duplicates",
            },
            timeout=10,
        )
        if resp.status_code not in (200, 201):
            _log.error("Supabase push failed: HTTP %s — %s", resp.status_code, resp.text[:200])
    except Exception as e:
        _log.error("Supabase push exception: %s", e)


def main():
    claude_block = default_block("Starting...")
    codex_block = default_block("Starting...")
    write_data(**build_payload(claude_block, codex_block))

    claude_failures = 0
    codex_failures = 0

    with ThreadPoolExecutor(max_workers=2) as executor:
        while True:
            claude_future = executor.submit(fetch_claude_usage, claude_failures)
            codex_future  = executor.submit(fetch_codex_usage,  codex_failures)
            claude_block, claude_at_limit, claude_failures = claude_future.result()
            codex_block,  codex_at_limit,  codex_failures  = codex_future.result()

            payload = build_payload(claude_block, codex_block)
            write_data(**payload)
            push_to_supabase(payload)
            time.sleep(REFRESH_AT_LIMIT if (claude_at_limit or codex_at_limit) else REFRESH_INTERVAL)


if __name__ == "__main__":
    main()
