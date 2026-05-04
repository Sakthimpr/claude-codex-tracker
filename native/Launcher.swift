import Cocoa
import Foundation

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var appMenu: NSMenu!
    var pythonProcess: Process?

    var lbSessionBar: NSTextField!
    var lbSessionReset: NSTextField!
    var lbWeeklyBar: NSTextField!
    var lbWeeklyReset: NSTextField!
    var lbStatus: NSTextField!
    var lbUpdated: NSTextField!

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        buildStatusItem()
        startPolling()
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.5) {
            self.launchPython()
        }
    }

    // ── Custom view row ───────────────────────────────────────────────────────
    // Using item.view bypasses macOS disabled-item dimming entirely.

    func makeRow(text: String, color: NSColor, size: CGFloat = 13, bold: Bool = false, height: CGFloat = 22) -> (NSMenuItem, NSTextField) {
        let font = bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size)
        let tfH = size + 6
        let tf = NSTextField(frame: NSRect(x: 14, y: (height - tfH) / 2, width: 290, height: tfH))
        tf.attributedStringValue = NSAttributedString(string: text,
            attributes: [.foregroundColor: color, .font: font])
        tf.drawsBackground  = false
        tf.isBezeled        = false
        tf.isEditable       = false
        tf.isSelectable     = false

        let view = NSView(frame: NSRect(x: 0, y: 0, width: 318, height: height))
        view.addSubview(tf)

        let item = NSMenuItem()
        item.view = view
        return (item, tf)
    }

    // ── Menu ──────────────────────────────────────────────────────────────────

    func buildMenu() {
        appMenu = NSMenu()
        appMenu.autoenablesItems = false

        let header  = NSColor.labelColor
        let accent  = NSColor(calibratedRed: 0.40, green: 0.80, blue: 1.00, alpha: 1)
        let cream   = NSColor(calibratedRed: 1.00, green: 0.90, blue: 0.60, alpha: 1)
        let dim     = NSColor.secondaryLabelColor

        let (h, _) = makeRow(text: "  ◎  Claude Pro — Live Usage", color: header, size: 13, bold: true, height: 26)
        appMenu.addItem(h)
        appMenu.addItem(.separator())

        let (sl, _) = makeRow(text: "  ⏱   Current Session  (5-hr window)", color: accent, size: 12, height: 20)
        appMenu.addItem(sl)

        let (sb, lbSB) = makeRow(text: "     ⚪  ░░░░░░░░░░  — used", color: cream, height: 24)
        lbSessionBar = lbSB
        appMenu.addItem(sb)

        let (sr, lbSR) = makeRow(text: "     ↻  —", color: dim, size: 11, height: 18)
        lbSessionReset = lbSR
        appMenu.addItem(sr)

        appMenu.addItem(.separator())

        let (wl, _) = makeRow(text: "  📅  Weekly  (All Models)", color: accent, size: 12, height: 20)
        appMenu.addItem(wl)

        let (wb, lbWB) = makeRow(text: "     ⚪  ░░░░░░░░░░  — used", color: cream, height: 24)
        lbWeeklyBar = lbWB
        appMenu.addItem(wb)

        let (wr, lbWR) = makeRow(text: "     ↻  —", color: dim, size: 11, height: 18)
        lbWeeklyReset = lbWR
        appMenu.addItem(wr)

        appMenu.addItem(.separator())

        let (stRow, lbSt) = makeRow(text: "  ●  Status: Starting...", color: dim, size: 11, height: 18)
        lbStatus = lbSt
        appMenu.addItem(stRow)

        let (upRow, lbUp) = makeRow(text: "  🕐  Updated: Never", color: dim, size: 11, height: 18)
        lbUpdated = lbUp
        appMenu.addItem(upRow)

        appMenu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        quitItem.isEnabled = true
        appMenu.addItem(quitItem)
    }

    func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let btn = statusItem.button {
            btn.title = "⚪⚪  W:—  S:—"
            btn.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        }
        statusItem.menu = appMenu
    }

    // ── Python ────────────────────────────────────────────────────────────────

    func launchPython() {
        let binaryDir = (Bundle.main.executablePath! as NSString).deletingLastPathComponent
        let candidates = [
            binaryDir + "/tracker_data.py",
            NSHomeDirectory() + "/.claude-tracker/tracker_data.py",
        ]
        guard let script = candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            DispatchQueue.main.async {
                self.setLabel(self.lbStatus, "  ●  Status: tracker_data.py missing",
                              color: .systemRed, size: 11)
            }
            return
        }
        let cmd = "exec $(which python3 || echo /usr/bin/python3) \"\(script)\""
        pythonProcess = Process()
        pythonProcess?.executableURL = URL(fileURLWithPath: "/bin/sh")
        pythonProcess?.arguments = ["-c", cmd]
        pythonProcess?.standardOutput = FileHandle.nullDevice
        pythonProcess?.standardError  = FileHandle.nullDevice
        try? pythonProcess?.run()
    }

    // ── Polling ───────────────────────────────────────────────────────────────

    func startPolling() {
        loadData()
        Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.loadData()
        }
    }

    func loadData() {
        let url = URL(fileURLWithPath: "/tmp/claude_tracker_data.json")
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: String]
        else { return }
        DispatchQueue.main.async { self.updateUI(json) }
    }

    // ── UI helpers ────────────────────────────────────────────────────────────

    func setLabel(_ lbl: NSTextField, _ text: String, color: NSColor, size: CGFloat = 13, bold: Bool = false) {
        let font = bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size)
        lbl.attributedStringValue = NSAttributedString(string: text,
            attributes: [.foregroundColor: color, .font: font])
    }

    func colorDot(_ pct: String) -> String {
        guard let n = Int(pct.replacingOccurrences(of: "%", with: "")) else { return "⚪" }
        if n > 70 { return "🔴" }
        if n >= 50 { return "🟡" }
        return "🟢"
    }

    func progressBar(_ pct: String, width: Int = 10) -> String {
        guard let n = Int(pct.replacingOccurrences(of: "%", with: "")) else {
            return String(repeating: "░", count: width)
        }
        let filled = min(max(Int(Double(n) / 100.0 * Double(width) + 0.5), 0), width)
        return String(repeating: "█", count: filled) + String(repeating: "░", count: width - filled)
    }

    func barColor(_ pct: String) -> NSColor {
        guard let n = Int(pct.replacingOccurrences(of: "%", with: "")) else { return .secondaryLabelColor }
        if n > 70 { return .systemRed }
        if n >= 50 { return .systemYellow }
        return .systemGreen
    }

    func updateUI(_ d: [String: String]) {
        let w       = d["weekly_pct"]    ?? "—"
        let s       = d["session_pct"]   ?? "—"
        let wReset  = d["weekly_reset"]  ?? "—"
        let sReset  = d["session_reset"] ?? "—"
        let status  = d["status"]        ?? "—"
        let updated = d["last_updated"]  ?? "Never"

        let wDot = w != "—" ? colorDot(w) : "⚪"
        let sDot = s != "—" ? colorDot(s) : "⚪"

        statusItem.button?.title = "\(wDot)\(sDot)  W:\(w)  S:\(s)"

        setLabel(lbSessionBar,   "     \(colorDot(s))  \(progressBar(s))  \(s) used", color: barColor(s))
        setLabel(lbSessionReset, "     ↻  \(sReset)", color: .secondaryLabelColor, size: 11)
        setLabel(lbWeeklyBar,    "     \(colorDot(w))  \(progressBar(w))  \(w) used", color: barColor(w))
        setLabel(lbWeeklyReset,  "     ↻  \(wReset)", color: .secondaryLabelColor, size: 11)
        setLabel(lbStatus,       "  ●  Status: \(status)", color: .labelColor, size: 11)
        setLabel(lbUpdated,      "  🕐  Updated: \(updated)", color: .secondaryLabelColor, size: 11)
    }

    @objc func quitApp() {
        pythonProcess?.terminate()
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        pythonProcess?.terminate()
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
