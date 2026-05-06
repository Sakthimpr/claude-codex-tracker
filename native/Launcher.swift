import Cocoa
import Foundation

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var appMenu: NSMenu!
    var pythonProcess: Process?
    var showRemaining = false
    var toggleUsageModeItem: NSMenuItem!

    var lbClaudeSessionBar: NSTextField!
    var lbClaudeSessionReset: NSTextField!
    var lbClaudeWeeklyBar: NSTextField!
    var lbClaudeWeeklyReset: NSTextField!
    var lbClaudeStatus: NSTextField!

    var lbCodexSessionBar: NSTextField!
    var lbCodexSessionReset: NSTextField!
    var lbCodexWeeklyBar: NSTextField!
    var lbCodexWeeklyReset: NSTextField!
    var lbCodexCredits: NSTextField!
    var lbCodexStatus: NSTextField!

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

        let (h, _) = makeRow(text: "  ◎  Claude + Codex — Live Usage", color: header, size: 13, bold: true, height: 26)
        appMenu.addItem(h)
        appMenu.addItem(.separator())

        let (clh, _) = makeRow(text: "  Claude Pro", color: header, size: 12, bold: true, height: 20)
        appMenu.addItem(clh)

        let (sl, _) = makeRow(text: "  ⏱   Current Session  (5-hr window)", color: accent, size: 12, height: 18)
        appMenu.addItem(sl)

        let (sb, lbSB) = makeRow(text: "     ⚪  ░░░░░░░░░░  — used", color: cream, height: 22)
        lbClaudeSessionBar = lbSB
        appMenu.addItem(sb)

        let (sr, lbSR) = makeRow(text: "     ↻  —", color: dim, size: 11, height: 18)
        lbClaudeSessionReset = lbSR
        appMenu.addItem(sr)

        let (wl, _) = makeRow(text: "  📅  Weekly  (All Models)", color: accent, size: 12, height: 18)
        appMenu.addItem(wl)

        let (wb, lbWB) = makeRow(text: "     ⚪  ░░░░░░░░░░  — used", color: cream, height: 22)
        lbClaudeWeeklyBar = lbWB
        appMenu.addItem(wb)

        let (wr, lbWR) = makeRow(text: "     ↻  —", color: dim, size: 11, height: 18)
        lbClaudeWeeklyReset = lbWR
        appMenu.addItem(wr)

        let (clst, lbClSt) = makeRow(text: "  ●  Status: Starting...", color: dim, size: 11, height: 18)
        lbClaudeStatus = lbClSt
        appMenu.addItem(clst)

        appMenu.addItem(.separator())

        let (cxh, _) = makeRow(text: "  Codex", color: header, size: 12, bold: true, height: 20)
        appMenu.addItem(cxh)

        let (csl, _) = makeRow(text: "  ⏱   Current Session  (5-hr window)", color: accent, size: 12, height: 18)
        appMenu.addItem(csl)

        let (csb, lbCSB) = makeRow(text: "     ⚪  ░░░░░░░░░░  — used", color: cream, height: 22)
        lbCodexSessionBar = lbCSB
        appMenu.addItem(csb)

        let (csr, lbCSR) = makeRow(text: "     ↻  —", color: dim, size: 11, height: 18)
        lbCodexSessionReset = lbCSR
        appMenu.addItem(csr)

        let (cwl, _) = makeRow(text: "  📅  Weekly", color: accent, size: 12, height: 18)
        appMenu.addItem(cwl)

        let (cwb, lbCWB) = makeRow(text: "     ⚪  ░░░░░░░░░░  — used", color: cream, height: 22)
        lbCodexWeeklyBar = lbCWB
        appMenu.addItem(cwb)

        let (cwr, lbCWR) = makeRow(text: "     ↻  —", color: dim, size: 11, height: 18)
        lbCodexWeeklyReset = lbCWR
        appMenu.addItem(cwr)

        let (cxcr, lbCxCr) = makeRow(text: "     ⊕  Credits: —", color: dim, size: 11, height: 18)
        lbCodexCredits = lbCxCr
        appMenu.addItem(cxcr)

        let (cxst, lbCxSt) = makeRow(text: "  ●  Status: Starting...", color: dim, size: 11, height: 18)
        lbCodexStatus = lbCxSt
        appMenu.addItem(cxst)

        appMenu.addItem(.separator())

        let (upRow, lbUp) = makeRow(text: "  🕐  Updated: Never", color: dim, size: 11, height: 18)
        lbUpdated = lbUp
        appMenu.addItem(upRow)

        appMenu.addItem(.separator())

        toggleUsageModeItem = NSMenuItem(title: "Show Remaining %", action: #selector(toggleUsageMode), keyEquivalent: "m")
        toggleUsageModeItem.target = self
        toggleUsageModeItem.isEnabled = true
        appMenu.addItem(toggleUsageModeItem)

        let openCodexItem = NSMenuItem(title: "Open Codex Analytics", action: #selector(openCodexAnalytics), keyEquivalent: "o")
        openCodexItem.target = self
        openCodexItem.isEnabled = true
        appMenu.addItem(openCodexItem)

        appMenu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        quitItem.isEnabled = true
        appMenu.addItem(quitItem)
    }

    func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let btn = statusItem.button {
            btn.title = "⚪⚪ C W:— S:— | ⚪⚪ O W:— S:—"
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
                self.setLabel(self.lbClaudeStatus, "  ●  Status: tracker_data.py missing",
                              color: .systemRed, size: 11)
                self.setLabel(self.lbCodexStatus, "  ●  Status: tracker_data.py missing",
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
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
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

    func pctInt(_ pct: String) -> Int? {
        Int(pct.replacingOccurrences(of: "%", with: ""))
    }

    func usedRemainingPcts(from block: [String: Any]) -> (used: String, remaining: String) {
        let used = stringValue(block["session_pct"])
        if let n = block["session_remaining_pct"] as? NSNumber {
            return (used, "\(n.intValue)%")
        }
        if let u = pctInt(used) {
            return (used, "\(max(0, 100 - u))%")
        }
        return (used, "—")
    }

    func weeklyUsedRemainingPcts(from block: [String: Any]) -> (used: String, remaining: String) {
        let used = stringValue(block["weekly_pct"])
        if let n = block["weekly_remaining_pct"] as? NSNumber {
            return (used, "\(n.intValue)%")
        }
        if let u = pctInt(used) {
            return (used, "\(max(0, 100 - u))%")
        }
        return (used, "—")
    }

    func colorDotForValue(_ pct: String, isRemaining: Bool) -> String {
        guard let n = pctInt(pct) else { return "⚪" }
        if isRemaining {
            if n < 30 { return "🔴" }
            if n <= 50 { return "🟡" }
            return "🟢"
        }
        return colorDot(pct)
    }

    func barColorForValue(_ pct: String, isRemaining: Bool) -> NSColor {
        guard let n = pctInt(pct) else { return .secondaryLabelColor }
        if isRemaining {
            if n < 30 { return .systemRed }
            if n <= 50 { return .systemYellow }
            return .systemGreen
        }
        return barColor(pct)
    }

    func stringValue(_ any: Any?, fallback: String = "—") -> String {
        if let s = any as? String, !s.isEmpty { return s }
        if let n = any as? NSNumber { return "\(n)" }
        return fallback
    }

    func usageBlock(from root: [String: Any], key: String, fallbackToRoot: Bool = false) -> [String: Any] {
        if let block = root[key] as? [String: Any] {
            return block
        }
        return fallbackToRoot ? root : [:]
    }

    func updateUI(_ payload: [String: Any]) {
        let claude = usageBlock(from: payload, key: "claude", fallbackToRoot: true)
        let codex = usageBlock(from: payload, key: "codex")

        let cWReset = stringValue(claude["weekly_reset"])
        let cSReset = stringValue(claude["session_reset"])
        let cStatus = stringValue(claude["status"])

        let oWReset = stringValue(codex["weekly_reset"])
        let oSReset = stringValue(codex["session_reset"])
        let oStatus = stringValue(codex["status"], fallback: codex.isEmpty ? "Waiting for data..." : "—")
        let oCredits = stringValue(codex["credits_balance"], fallback: "—")

        let updated = stringValue(payload["last_updated"], fallback: stringValue(claude["last_updated"], fallback: "Never"))

        let cSession = usedRemainingPcts(from: claude)
        let cWeekly = weeklyUsedRemainingPcts(from: claude)
        let oSession = usedRemainingPcts(from: codex)
        let oWeekly = weeklyUsedRemainingPcts(from: codex)

        let cSView = showRemaining ? cSession.remaining : cSession.used
        let cWView = showRemaining ? cWeekly.remaining : cWeekly.used
        let oSView = showRemaining ? oSession.remaining : oSession.used
        let oWView = showRemaining ? oWeekly.remaining : oWeekly.used
        let modeLabel = showRemaining ? "remaining" : "used"

        let cWDot = cWView != "—" ? colorDotForValue(cWView, isRemaining: showRemaining) : "⚪"
        let cSDot = cSView != "—" ? colorDotForValue(cSView, isRemaining: showRemaining) : "⚪"
        let oWDot = oWView != "—" ? colorDotForValue(oWView, isRemaining: showRemaining) : "⚪"
        let oSDot = oSView != "—" ? colorDotForValue(oSView, isRemaining: showRemaining) : "⚪"

        statusItem.button?.title = "\(cWDot)\(cSDot) C W:\(cWView) S:\(cSView) | \(oWDot)\(oSDot) O W:\(oWView) S:\(oSView)"

        setLabel(lbClaudeSessionBar, "     \(colorDotForValue(cSView, isRemaining: showRemaining))  \(progressBar(cSView))  \(cSView) \(modeLabel)", color: barColorForValue(cSView, isRemaining: showRemaining))
        setLabel(lbClaudeSessionReset, "     ↻  \(cSReset)", color: .secondaryLabelColor, size: 11)
        setLabel(lbClaudeWeeklyBar, "     \(colorDotForValue(cWView, isRemaining: showRemaining))  \(progressBar(cWView))  \(cWView) \(modeLabel)", color: barColorForValue(cWView, isRemaining: showRemaining))
        setLabel(lbClaudeWeeklyReset, "     ↻  \(cWReset)", color: .secondaryLabelColor, size: 11)
        setLabel(lbClaudeStatus, "  ●  Status: \(cStatus)", color: .labelColor, size: 11)

        setLabel(lbCodexSessionBar, "     \(colorDotForValue(oSView, isRemaining: showRemaining))  \(progressBar(oSView))  \(oSView) \(modeLabel)", color: barColorForValue(oSView, isRemaining: showRemaining))
        setLabel(lbCodexSessionReset, "     ↻  \(oSReset)", color: .secondaryLabelColor, size: 11)
        setLabel(lbCodexWeeklyBar, "     \(colorDotForValue(oWView, isRemaining: showRemaining))  \(progressBar(oWView))  \(oWView) \(modeLabel)", color: barColorForValue(oWView, isRemaining: showRemaining))
        setLabel(lbCodexWeeklyReset, "     ↻  \(oWReset)", color: .secondaryLabelColor, size: 11)
        setLabel(lbCodexCredits, "     ⊕  Credits: \(oCredits)", color: .secondaryLabelColor, size: 11)
        setLabel(lbCodexStatus, "  ●  Status: \(oStatus)", color: .labelColor, size: 11)

        toggleUsageModeItem.state = showRemaining ? .on : .off
        toggleUsageModeItem.title = showRemaining ? "Show Used %" : "Show Remaining %"
        setLabel(lbUpdated, "  🕐  Updated: \(updated)", color: .secondaryLabelColor, size: 11)
    }

    @objc func toggleUsageMode() {
        showRemaining.toggle()
        loadData()
    }

    @objc func openCodexAnalytics() {
        guard let url = URL(string: "https://chatgpt.com/codex/cloud/settings/analytics#usage") else { return }
        NSWorkspace.shared.open(url)
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
