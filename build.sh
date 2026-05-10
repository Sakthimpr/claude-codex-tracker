#!/bin/bash
set -e

BINARY_NAME="claude-tracker"
INSTALL_BIN="${HOME}/.local/bin/${BINARY_NAME}"
INSTALL_DIR="${HOME}/.claude-tracker"
DIST="dist"
APP_NAME="Claude_Codex_Tracker.app"
APP_DIR="/Applications/${APP_NAME}"
APP_BIN="${APP_DIR}/Contents/MacOS/ClaudeTracker"
APP_PLIST="${APP_DIR}/Contents/Info.plist"
APP_RESOURCES="${APP_DIR}/Contents/Resources"
ICON_SRC="assets/ClaudeCodexIcon1024.png"
ICONSET_DIR="${DIST}/AppIcon.iconset"
ICON_ICNS="${DIST}/AppIcon.icns"

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
for pkg in browser_cookie3 requests; do
    if ! $PYTHON -c "import $pkg" 2>/dev/null; then
        MISSING="$MISSING $pkg"
    fi
done
if [ -n "$MISSING" ]; then
    echo "❌  Missing:$MISSING  →  pip3 install$MISSING"
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

echo "▶ Building app icon..."
if [ ! -f "${ICON_SRC}" ]; then
    echo "❌  Missing icon source: ${ICON_SRC}"
    exit 1
fi
rm -rf "${ICONSET_DIR}" "${ICON_ICNS}"
mkdir -p "${ICONSET_DIR}"
sips -z 16 16     "${ICON_SRC}" --out "${ICONSET_DIR}/icon_16x16.png" >/dev/null
sips -z 32 32     "${ICON_SRC}" --out "${ICONSET_DIR}/icon_16x16@2x.png" >/dev/null
sips -z 32 32     "${ICON_SRC}" --out "${ICONSET_DIR}/icon_32x32.png" >/dev/null
sips -z 64 64     "${ICON_SRC}" --out "${ICONSET_DIR}/icon_32x32@2x.png" >/dev/null
sips -z 128 128   "${ICON_SRC}" --out "${ICONSET_DIR}/icon_128x128.png" >/dev/null
sips -z 256 256   "${ICON_SRC}" --out "${ICONSET_DIR}/icon_128x128@2x.png" >/dev/null
sips -z 256 256   "${ICON_SRC}" --out "${ICONSET_DIR}/icon_256x256.png" >/dev/null
sips -z 512 512   "${ICON_SRC}" --out "${ICONSET_DIR}/icon_256x256@2x.png" >/dev/null
sips -z 512 512   "${ICON_SRC}" --out "${ICONSET_DIR}/icon_512x512.png" >/dev/null
cp "${ICON_SRC}" "${ICONSET_DIR}/icon_512x512@2x.png"
iconutil -c icns "${ICONSET_DIR}" -o "${ICON_ICNS}"
echo "✅  Icon ready"

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

echo "▶ Creating launcher app in ${APP_DIR}..."
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_RESOURCES}"
cp "${ICON_ICNS}" "${APP_RESOURCES}/AppIcon.icns"
cat > "${APP_BIN}" << 'STARTER'
#!/bin/bash
set -e
UID_VAL=$(id -u)
PLIST_PATH="$HOME/Library/LaunchAgents/com.sakthivel.claudetracker.plist"
launchctl kickstart -k "gui/${UID_VAL}/com.sakthivel.claudetracker" 2>/dev/null || {
    launchctl unload "$PLIST_PATH" 2>/dev/null || true
    launchctl load "$PLIST_PATH"
}
STARTER
chmod +x "${APP_BIN}"

cat > "${APP_PLIST}" << 'APPINFO'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleDisplayName</key><string>Claude_Codex_Tracker</string>
    <key>CFBundleExecutable</key><string>ClaudeTracker</string>
    <key>CFBundleIdentifier</key><string>com.sakthivel.claudetracker</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleName</key><string>Claude_Codex_Tracker</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSUIElement</key><false/>
</dict>
</plist>
APPINFO

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
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key><false/>
    </dict>
    <key>StandardOutPath</key>   <string>/tmp/claude-tracker.log</string>
    <key>StandardErrorPath</key> <string>/tmp/claude-tracker.log</string>
</dict>
</plist>
LAUNCHPLIST

launchctl unload "${PLIST}" 2>/dev/null || true
launchctl load   "${PLIST}" 2>/dev/null || true

echo ""
echo "✅  Done. LaunchAgent loaded and tracker started."
