#!/bin/bash
set -e

BINARY_NAME="claude-tracker"
INSTALL_BIN="${HOME}/.local/bin/${BINARY_NAME}"
INSTALL_DIR="${HOME}/.claude-tracker"
DIST="dist"

# ── Step 1: Validate Python and dependencies ──────────────────────────────────
echo "▶ Checking Python..."
PYTHON=$(which python3 2>/dev/null || echo "")
if [ -z "$PYTHON" ]; then
    echo "❌  Python 3 not found."
    exit 1
fi
echo "✅  Python: $($PYTHON --version)  ($PYTHON)"

echo "▶ Checking required packages..."
MISSING=""
for pkg in playwright browser_cookie3; do
    if ! $PYTHON -c "import $pkg" 2>/dev/null; then
        MISSING="$MISSING $pkg"
    fi
done
if [ -n "$MISSING" ]; then
    echo "❌  Missing:$MISSING  →  pip3 install$MISSING && playwright install chromium"
    exit 1
fi
echo "✅  All packages present"

# ── Step 2: Compile ───────────────────────────────────────────────────────────
echo ""
echo "▶ Cleaning previous build..."
rm -rf "${DIST}"
mkdir -p "${DIST}"

echo "▶ Compiling Swift binary..."
xcrun swiftc \
    -framework Cocoa \
    -target arm64-apple-macosx13.0 \
    -O \
    native/Launcher.swift \
    -o "${DIST}/${BINARY_NAME}"
echo "✅  Compiled"

# ── Step 3: Install ───────────────────────────────────────────────────────────
echo ""
echo "▶ Stopping any running instance..."
pkill -f "${BINARY_NAME}"   2>/dev/null || true
pkill -f "tracker_data.py"  2>/dev/null || true
pkill -f "ClaudeTracker"    2>/dev/null || true
sleep 0.5

echo "▶ Installing to ${INSTALL_BIN}..."
mkdir -p "${HOME}/.local/bin"
cp "${DIST}/${BINARY_NAME}" "${INSTALL_BIN}"
chmod +x "${INSTALL_BIN}"

echo "▶ Installing tracker_data.py to ${INSTALL_DIR}..."
mkdir -p "${INSTALL_DIR}"
cp tracker_data.py "${INSTALL_DIR}/tracker_data.py"

# ── Step 4: Update LaunchAgent ────────────────────────────────────────────────
PLIST="${HOME}/Library/LaunchAgents/com.sakthivel.claudetracker.plist"
cat > "${PLIST}" << LAUNCHPLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>             <string>com.sakthivel.claudetracker</string>
    <key>ProgramArguments</key>
    <array><string>${INSTALL_BIN}</string></array>
    <key>RunAtLoad</key>         <true/>
    <key>KeepAlive</key>         <false/>
    <key>StandardOutPath</key>   <string>/tmp/claude-tracker.log</string>
    <key>StandardErrorPath</key> <string>/tmp/claude-tracker.log</string>
</dict>
</plist>
LAUNCHPLIST

launchctl unload "${PLIST}" 2>/dev/null || true
launchctl load   "${PLIST}" 2>/dev/null || true

echo ""
echo "✅  Done. Launching..."
"${INSTALL_BIN}" &
