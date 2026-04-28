import Cocoa
import Foundation

// Find Python 3
func findPython() -> String? {
    let candidates = [
        "/Library/Frameworks/Python.framework/Versions/3.12/bin/python3",
        "/Library/Frameworks/Python.framework/Versions/3.11/bin/python3",
        "/Library/Frameworks/Python.framework/Versions/3.10/bin/python3",
        "/opt/homebrew/bin/python3",
        "/usr/local/bin/python3",
        "/usr/bin/python3",
    ]
    for path in candidates {
        if FileManager.default.isExecutableFile(atPath: path) { return path }
    }
    return nil
}

// Show error dialog and quit
func fatalAlert(_ message: String) {
    let alert = NSAlert()
    alert.messageText = "Claude Tracker"
    alert.informativeText = message
    alert.alertStyle = .critical
    alert.addButton(withTitle: "OK")
    alert.runModal()
    exit(1)
}

// ── App setup ────────────────────────────────────────────────────────────────
let app = NSApplication.shared
// Accessory policy = LSUIElement: no Dock icon, no app menu, menu bar only
app.setActivationPolicy(.accessory)

guard let python = findPython() else {
    fatalAlert("Python 3 is required.\n\nInstall it from python.org and relaunch.")
    exit(1)
}

guard let script = Bundle.main.path(forResource: "tracker_v2", ofType: "py") else {
    fatalAlert("tracker_v2.py missing from app bundle.\n\nRebuild with ./build.sh")
    exit(1)
}

// Launch Python as a child process — it creates its own rumps menu bar
let task = Process()
task.executableURL = URL(fileURLWithPath: python)
task.arguments = [script]

// Forward Python stdout/stderr to system log for debugging
task.standardOutput = FileHandle.nullDevice
task.standardError  = FileHandle.nullDevice

// When Python exits, quit the wrapper too
task.terminationHandler = { _ in
    DispatchQueue.main.async { NSApp.terminate(nil) }
}

do {
    try task.run()
} catch {
    fatalAlert("Failed to launch tracker:\n\(error.localizedDescription)")
}

// Keep this wrapper alive so the bundle stays registered with macOS
app.run()
