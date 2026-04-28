#!/bin/bash
set -e

APP_NAME="Claude Tracker"
BUNDLE_NAME="ClaudeTracker"
DIST="dist"
APP_DIR="${DIST}/${APP_NAME}.app"
MACOS="${APP_DIR}/Contents/MacOS"
RESOURCES="${APP_DIR}/Contents/Resources"
BINARY="${MACOS}/${BUNDLE_NAME}"

# ── Step 1: Validate Python and dependencies ──────────────────────────────────
echo "▶ Checking Python..."
PYTHON=$(which python3 2>/dev/null || echo "")
if [ -z "$PYTHON" ]; then
    echo "❌  Python 3 not found. Install from https://python.org and try again."
    exit 1
fi
echo "✅  Python: $($PYTHON --version)  ($PYTHON)"

echo "▶ Checking required packages..."
MISSING=""
for pkg in rumps playwright browser_cookie3; do
    if ! $PYTHON -c "import $pkg" 2>/dev/null; then
        MISSING="$MISSING $pkg"
    fi
done
if [ -n "$MISSING" ]; then
    echo "❌  Missing packages:$MISSING"
    echo "    Run: pip3 install$MISSING"
    exit 1
fi
echo "✅  All packages present"

# ── Step 2: Build app bundle ──────────────────────────────────────────────────
echo ""
echo "▶ Cleaning previous build..."
rm -rf "${DIST}"
mkdir -p "${MACOS}" "${RESOURCES}"

echo "▶ Copying Python script..."
cp tracker_v2.py "${RESOURCES}/tracker_v2.py"

echo "▶ Compiling Swift launcher..."
xcrun swiftc \
    -target arm64-apple-macosx13.0 \
    -O \
    native/Launcher.swift \
    -o "${BINARY}"

echo "▶ Writing Info.plist..."
cat > "${APP_DIR}/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>             <string>Claude Tracker</string>
    <key>CFBundleDisplayName</key>      <string>Claude Tracker</string>
    <key>CFBundleIdentifier</key>       <string>com.sakthivel.claudetracker</string>
    <key>CFBundleVersion</key>          <string>2.0.0</string>
    <key>CFBundleShortVersionString</key><string>2.0</string>
    <key>CFBundleExecutable</key>       <string>ClaudeTracker</string>
    <key>CFBundlePackageType</key>      <string>APPL</string>
    <key>LSUIElement</key>              <true/>
    <key>NSHighResolutionCapable</key>  <true/>
</dict>
</plist>
PLIST

SIZE=$(du -sh "${APP_DIR}" | cut -f1)
echo "✅  App built: ${APP_DIR}  (${SIZE})"

# ── Step 3: Install to /Applications ─────────────────────────────────────────
echo ""
echo "▶ Installing to /Applications..."
pkill -f "tracker_v2.py" 2>/dev/null || true; sleep 0.5
rm -rf "/Applications/${APP_NAME}.app"
cp -R "${APP_DIR}" "/Applications/${APP_NAME}.app"
xattr -rc "/Applications/${APP_NAME}.app"
echo ""
echo "✅  Done. Launching..."
open "/Applications/${APP_NAME}.app"
