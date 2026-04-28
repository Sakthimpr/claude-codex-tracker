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

echo "▶ Creating app icon..."
ICONSET=$(mktemp -d)/AppIcon.iconset
mkdir -p "${ICONSET}"
SRC="icon.png"
sips -z 16   16   "${SRC}" --out "${ICONSET}/icon_16x16.png"      > /dev/null
sips -z 32   32   "${SRC}" --out "${ICONSET}/icon_16x16@2x.png"   > /dev/null
sips -z 32   32   "${SRC}" --out "${ICONSET}/icon_32x32.png"      > /dev/null
sips -z 64   64   "${SRC}" --out "${ICONSET}/icon_32x32@2x.png"   > /dev/null
sips -z 128  128  "${SRC}" --out "${ICONSET}/icon_128x128.png"    > /dev/null
sips -z 256  256  "${SRC}" --out "${ICONSET}/icon_128x128@2x.png" > /dev/null
sips -z 256  256  "${SRC}" --out "${ICONSET}/icon_256x256.png"    > /dev/null
sips -z 512  512  "${SRC}" --out "${ICONSET}/icon_256x256@2x.png" > /dev/null
cp "${SRC}" "${ICONSET}/icon_512x512.png"
iconutil -c icns "${ICONSET}" -o "${RESOURCES}/AppIcon.icns"

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
    <key>CFBundleIconFile</key>         <string>AppIcon</string>
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
