import Cocoa
import Foundation

final class ClickableMenuRowView: NSView {
    var onClick: (() -> Void)?
    var trackingAreaRef: NSTrackingArea?
    var normalColor: NSColor = NSColor.clear
    var hoverColor: NSColor = NSColor.clear
    var currentColor: NSColor = NSColor.clear
    var cursorPushed = false

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        currentColor.setFill()
        dirtyRect.fill()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area = trackingAreaRef {
            removeTrackingArea(area)
        }
        let opts: NSTrackingArea.Options = [.mouseEnteredAndExited, .cursorUpdate, .activeAlways, .inVisibleRect]
        let area = NSTrackingArea(rect: bounds, options: opts, owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingAreaRef = area
        window?.invalidateCursorRects(for: self)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.pointingHand.set()
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        if !cursorPushed {
            NSCursor.pointingHand.push()
            cursorPushed = true
        }
        currentColor = hoverColor
        needsDisplay = true
        wantsLayer = true
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.12)
        layer?.transform = CATransform3DMakeScale(1.02, 1.02, 1.0)
        layer?.backgroundColor = hoverColor.cgColor
        layer?.cornerRadius = 8
        layer?.shadowColor = NSColor.black.withAlphaComponent(0.35).cgColor
        layer?.shadowOpacity = 0.35
        layer?.shadowRadius = 6
        layer?.shadowOffset = CGSize(width: 0, height: -1)
        CATransaction.commit()
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        if cursorPushed {
            NSCursor.pop()
            cursorPushed = false
        }
        currentColor = normalColor
        needsDisplay = true
        wantsLayer = true
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.12)
        layer?.transform = CATransform3DIdentity
        layer?.backgroundColor = normalColor.cgColor
        layer?.cornerRadius = 0
        layer?.shadowOpacity = 0
        CATransaction.commit()
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var appMenu: NSMenu!
    var pythonProcess: Process?
    var isQuitting = false
    var showRemaining = false
    var toggleUsageModeItem: NSMenuItem!
    var lbToggleActionTitle: NSTextField!

    var lbHeader: NSTextField!
    var lbClaudeTitle: NSTextField!
    var lbCodexTitle: NSTextField!

    var lbClaudeSessionTop: NSTextField!
    var lbClaudeSessionBottom: NSTextField!
    var claudeSessionResetItem: NSMenuItem!
    var lbClaudeSessionResetLine: NSTextField!
    var claudeCappedItem: NSMenuItem!
    var lbClaudeCapped: NSTextField!
    var lbClaudeWeeklyTop: NSTextField!
    var lbClaudeWeeklyBottom: NSTextField!

    var lbCodexSessionTop: NSTextField!
    var lbCodexSessionBottom: NSTextField!
    var codexSessionResetItem: NSMenuItem!
    var lbCodexSessionResetLine: NSTextField!
    var codexCappedItem: NSMenuItem!
    var lbCodexCapped: NSTextField!
    var lbCodexWeeklyTop: NSTextField!
    var lbCodexWeeklyBottom: NSTextField!

    var pulseOn = false
    let rowWidth: CGFloat = 350
    let textWidth: CGFloat = 326
    let columns = 50

    let usageRed = NSColor(calibratedRed: 0.84, green: 0.27, blue: 0.27, alpha: 1.0)
    let usageAmber = NSColor(calibratedRed: 0.66, green: 0.45, blue: 0.00, alpha: 1.0)
    let usageGreen = NSColor.systemGreen
    let panelTeal = NSColor(calibratedRed: 0.08, green: 0.22, blue: 0.24, alpha: 0.90)
    let actionHoverTeal = NSColor(calibratedRed: 0.12, green: 0.30, blue: 0.33, alpha: 0.98)
    let headerText = NSColor(calibratedRed: 0.95, green: 0.98, blue: 0.98, alpha: 1.0)
    let dimText = NSColor(calibratedRed: 0.86, green: 0.94, blue: 0.94, alpha: 1.0)

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        buildStatusItem()
        startPolling()
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.5) {
            self.launchPython()
        }
    }

    func makeRow(text: String, color: NSColor, size: CGFloat = 13, bold: Bool = false, height: CGFloat = 22, mono: Bool = false) -> (NSMenuItem, NSTextField) {
        let font: NSFont
        if mono {
            font = NSFont.monospacedDigitSystemFont(ofSize: size, weight: bold ? .semibold : .regular)
        } else {
            font = bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size)
        }

        let tfH = size + 7
        let tf = NSTextField(frame: NSRect(x: 12, y: (height - tfH) / 2, width: textWidth, height: tfH))
        tf.attributedStringValue = NSAttributedString(string: text, attributes: [.foregroundColor: color, .font: font])
        tf.drawsBackground = false
        tf.isBezeled = false
        tf.isEditable = false
        tf.isSelectable = false
        tf.lineBreakMode = .byClipping

        let view = NSView(frame: NSRect(x: 0, y: 0, width: rowWidth, height: height))
        view.wantsLayer = true
        view.layer?.backgroundColor = panelTeal.cgColor
        view.addSubview(tf)

        let item = NSMenuItem()
        item.view = view
        return (item, tf)
    }

    func makeSeparatorRow(height: CGFloat = 10) -> NSMenuItem {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: rowWidth, height: height))
        view.wantsLayer = true
        view.layer?.backgroundColor = panelTeal.cgColor

        let line = NSView(frame: NSRect(x: 16, y: (height - 1) / 2, width: rowWidth - 32, height: 1))
        line.wantsLayer = true
        line.layer?.backgroundColor = NSColor(calibratedWhite: 1.0, alpha: 0.16).cgColor
        view.addSubview(line)

        let item = NSMenuItem()
        item.view = view
        return item
    }

    func makeActionRow(title: String, shortcut: String, action: Selector, keyEquivalent: String) -> (NSMenuItem, NSTextField) {
        let view = ClickableMenuRowView(frame: NSRect(x: 0, y: 0, width: rowWidth, height: 30))
        view.wantsLayer = true
        view.layer?.backgroundColor = panelTeal.cgColor
        view.normalColor = panelTeal
        view.hoverColor = actionHoverTeal
        view.currentColor = panelTeal

        let left = NSTextField(frame: NSRect(x: 12, y: 5, width: textWidth - 44, height: 20))
        left.attributedStringValue = NSAttributedString(
            string: "  \(title)",
            attributes: [
                .foregroundColor: headerText,
                .font: NSFont.systemFont(ofSize: 13, weight: .regular),
            ]
        )
        left.drawsBackground = false
        left.isBezeled = false
        left.isEditable = false
        left.isSelectable = false

        let right = NSTextField(frame: NSRect(x: rowWidth - 56, y: 5, width: 44, height: 20))
        right.alignment = .right
        right.attributedStringValue = NSAttributedString(
            string: shortcut,
            attributes: [
                .foregroundColor: dimText,
                .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular),
            ]
        )
        right.drawsBackground = false
        right.isBezeled = false
        right.isEditable = false
        right.isSelectable = false

        view.addSubview(left)
        view.addSubview(right)

        let item = NSMenuItem()
        item.view = view
        item.action = action
        item.target = self
        item.keyEquivalent = keyEquivalent
        item.keyEquivalentModifierMask = [.command]

        view.onClick = { [weak self, weak item] in
            guard let self else { return }
            _ = NSApp.sendAction(action, to: self, from: item)
        }

        return (item, left)
    }

    func buildMenu() {
        appMenu = NSMenu()
        appMenu.autoenablesItems = false
        appMenu.appearance = NSAppearance(named: .darkAqua)

        let header = headerText
        let dim = dimText

        let (h, lbH) = makeRow(text: "  ● Claude/Codex_Live Tracker                ↻ --:--:--", color: header, size: 13, bold: true, height: 30, mono: true)
        lbHeader = lbH
        appMenu.addItem(h)
        appMenu.addItem(makeSeparatorRow())

        let (clh, lbCLH) = makeRow(text: "  Claude", color: header, size: 14, bold: true, height: 28)
        lbClaudeTitle = lbCLH
        appMenu.addItem(clh)

        let (cst, lbCST) = makeRow(text: "  Session                                                —", color: header, size: 12, bold: true, height: 24, mono: true)
        lbClaudeSessionTop = lbCST
        appMenu.addItem(cst)

        let (csb, lbCSB) = makeRow(text: "  5h window    ░░░░░░░░░░░░░░░░░░░░░░                   —", color: dim, size: 11, height: 22, mono: true)
        lbClaudeSessionBottom = lbCSB
        appMenu.addItem(csb)

        let (csr, lbCSR) = makeRow(text: "  resets in —", color: dim, size: 11, height: 18, mono: true)
        claudeSessionResetItem = csr
        lbClaudeSessionResetLine = lbCSR
        appMenu.addItem(csr)

        let (cap, lbCap) = makeRow(text: "  Session capped. Unlock in —", color: header, size: 12, bold: true, height: 30, mono: true)
        claudeCappedItem = cap
        lbClaudeCapped = lbCap
        claudeCappedItem.isHidden = true
        appMenu.addItem(cap)

        let (cwt, lbCWT) = makeRow(text: "  Weekly                                                 —", color: header, size: 12, bold: true, height: 24, mono: true)
        lbClaudeWeeklyTop = lbCWT
        appMenu.addItem(cwt)

        let (cwb, lbCWB) = makeRow(text: "  all models   ░░░░░░░░░░░░░░░░░░░░░░                pace —", color: dim, size: 11, height: 22, mono: true)
        lbClaudeWeeklyBottom = lbCWB
        appMenu.addItem(cwb)

        appMenu.addItem(makeSeparatorRow())

        let (cxh, lbCXH) = makeRow(text: "  Codex", color: header, size: 14, bold: true, height: 28)
        lbCodexTitle = lbCXH
        appMenu.addItem(cxh)

        let (ost, lbOST) = makeRow(text: "  Session                                                —", color: header, size: 12, bold: true, height: 24, mono: true)
        lbCodexSessionTop = lbOST
        appMenu.addItem(ost)

        let (osb, lbOSB) = makeRow(text: "  5h window    ░░░░░░░░░░░░░░░░░░░░░░                   —", color: dim, size: 11, height: 22, mono: true)
        lbCodexSessionBottom = lbOSB
        appMenu.addItem(osb)

        let (osr, lbOSR) = makeRow(text: "  resets in —", color: dim, size: 11, height: 18, mono: true)
        codexSessionResetItem = osr
        lbCodexSessionResetLine = lbOSR
        appMenu.addItem(osr)

        let (ocap, lbOCap) = makeRow(text: "  Session capped. Unlock in —", color: header, size: 12, bold: true, height: 30, mono: true)
        codexCappedItem = ocap
        lbCodexCapped = lbOCap
        codexCappedItem.isHidden = true
        appMenu.addItem(ocap)

        let (owt, lbOWT) = makeRow(text: "  Weekly                                                 —", color: header, size: 12, bold: true, height: 24, mono: true)
        lbCodexWeeklyTop = lbOWT
        appMenu.addItem(owt)

        let (owb, lbOWB) = makeRow(text: "  resets —    ░░░░░░░░░░░░░░░░░░░░░░               on track", color: dim, size: 11, height: 22, mono: true)
        lbCodexWeeklyBottom = lbOWB
        appMenu.addItem(owb)

        appMenu.addItem(makeSeparatorRow())

        let (toggleItem, lbToggle) = makeActionRow(
            title: "Show Remaining %",
            shortcut: "⌘M",
            action: #selector(toggleUsageMode),
            keyEquivalent: "m"
        )
        toggleUsageModeItem = toggleItem
        lbToggleActionTitle = lbToggle
        appMenu.addItem(toggleItem)

        let (openClaudeItem, _) = makeActionRow(
            title: "Open Claude Analytics",
            shortcut: "⌘L",
            action: #selector(openClaudeAnalytics),
            keyEquivalent: "l"
        )
        appMenu.addItem(openClaudeItem)

        let (openCodexItem, _) = makeActionRow(
            title: "Open Codex Analytics",
            shortcut: "⌘O",
            action: #selector(openCodexAnalytics),
            keyEquivalent: "o"
        )
        appMenu.addItem(openCodexItem)

        appMenu.addItem(makeSeparatorRow())

        let (restartItem, _) = makeActionRow(
            title: "Refresh Tracker",
            shortcut: "⌘R",
            action: #selector(restartTracker),
            keyEquivalent: "r"
        )
        appMenu.addItem(restartItem)

        let (quitItem, _) = makeActionRow(
            title: "Quit",
            shortcut: "⌘Q",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        appMenu.addItem(quitItem)
    }

    func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let btn = statusItem.button {
            btn.title = "C ⚪⚪  O ⚪⚪"
            btn.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        }
        statusItem.menu = appMenu
    }

    func launchPython() {
        if let p = pythonProcess, p.isRunning { return }

        let binaryDir = (Bundle.main.executablePath! as NSString).deletingLastPathComponent
        let candidates = [
            binaryDir + "/tracker_data.py",
            NSHomeDirectory() + "/.claude-tracker/tracker_data.py",
        ]
        guard let script = candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            DispatchQueue.main.async {
                self.setLabel(self.lbHeader, self.twoCol("● Claude/Codex_Session Error", "↻ --:--:--", total: self.columns), color: self.usageRed, size: 13, bold: true, mono: true)
            }
            return
        }

        let pythonCandidates = [
            "/Library/Frameworks/Python.framework/Versions/3.10/bin/python3",
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/usr/bin/python3",
        ]
        let pythonBin = pythonCandidates.first(where: { FileManager.default.fileExists(atPath: $0) }) ?? "/usr/bin/python3"

        let cmd = "exec \"\(pythonBin)\" \"\(script)\""
        pythonProcess = Process()
        pythonProcess?.executableURL = URL(fileURLWithPath: "/bin/sh")
        pythonProcess?.arguments = ["-c", cmd]

        if !FileManager.default.fileExists(atPath: "/tmp/claude_tracker_python.log") {
            FileManager.default.createFile(atPath: "/tmp/claude_tracker_python.log", contents: nil)
        }
        if let log = FileHandle(forWritingAtPath: "/tmp/claude_tracker_python.log") {
            log.seekToEndOfFile()
            pythonProcess?.standardOutput = log
            pythonProcess?.standardError = log
        } else {
            pythonProcess?.standardOutput = FileHandle.nullDevice
            pythonProcess?.standardError = FileHandle.nullDevice
        }
        pythonProcess?.terminationHandler = { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if !self.isQuitting {
                    self.pythonProcess = nil
                    self.launchPython()
                }
            }
        }
        do {
            try pythonProcess?.run()
        } catch {
            pythonProcess = nil
            if let log = FileHandle(forWritingAtPath: "/tmp/claude_tracker_python.log") {
                log.seekToEndOfFile()
                let line = "[\(Date())] launch failed: \(error.localizedDescription)\n"
                if let data = line.data(using: .utf8) { log.write(data) }
                try? log.close()
            }
        }
    }

    func startPolling() {
        loadData()
        Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.loadData()
            self?.ensureFetcherHealthy()
        }
    }

    func ensureFetcherHealthy() {
        let path = "/tmp/claude_tracker_data.json"
        let isRunning = pythonProcess?.isRunning ?? false

        if let attrs = try? FileManager.default.attributesOfItem(atPath: path),
           let mtime = attrs[.modificationDate] as? Date {
            let age = Date().timeIntervalSince(mtime)
            if age > 150 || !isRunning {
                pythonProcess?.terminate()
                pythonProcess = nil
                launchPython()
            }
            return
        }

        if !isRunning {
            launchPython()
        }
    }

    func loadData() {
        let url = URL(fileURLWithPath: "/tmp/claude_tracker_data.json")
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }
        DispatchQueue.main.async { self.updateUI(json) }
    }

    func setLabel(_ lbl: NSTextField, _ text: String, color: NSColor, size: CGFloat = 13, bold: Bool = false, mono: Bool = false) {
        let font: NSFont
        if mono {
            font = NSFont.monospacedDigitSystemFont(ofSize: size, weight: bold ? .semibold : .regular)
        } else {
            font = bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size)
        }
        lbl.attributedStringValue = NSAttributedString(string: text, attributes: [.foregroundColor: color, .font: font])
    }

    func setMeterTopLabel(_ lbl: NSTextField, title: String, pct: String, pctColor: NSColor) {
        let badge = "  \(title)  "
        let text = twoCol(badge, pct, total: columns)
        let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        let attr = NSMutableAttributedString(string: text, attributes: [.foregroundColor: headerText, .font: font])
        if let badgeRange = text.range(of: badge) {
            let nsBadgeRange = NSRange(badgeRange, in: text)
            attr.addAttribute(.backgroundColor, value: NSColor.black.withAlphaComponent(0.35), range: nsBadgeRange)
            attr.addAttribute(.foregroundColor, value: NSColor.white, range: nsBadgeRange)
            attr.addAttribute(.strokeColor, value: NSColor.white.withAlphaComponent(0.30), range: nsBadgeRange)
            attr.addAttribute(.strokeWidth, value: -1.0, range: nsBadgeRange)

            let emboss = NSShadow()
            emboss.shadowColor = NSColor.black.withAlphaComponent(0.35)
            emboss.shadowOffset = NSSize(width: 0, height: -1)
            emboss.shadowBlurRadius = 1.2
            attr.addAttribute(.shadow, value: emboss, range: nsBadgeRange)
        }
        if let range = text.range(of: pct, options: .backwards) {
            let nsRange = NSRange(range, in: text)
            attr.addAttribute(.foregroundColor, value: pctColor, range: nsRange)
        }
        lbl.attributedStringValue = attr
    }

    func setBarRowLabel(_ lbl: NSTextField, prefix: String, pct: String, suffix: String = "", barColor: NSColor, barWidth: Int = 18) {
        let bar = progressBar(pct, width: barWidth)
        let suffixPart = suffix.isEmpty ? "" : "  \(suffix)"
        let text = "  \(prefix)  \(bar)\(suffixPart)"
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        let attr = NSMutableAttributedString(string: text, attributes: [.foregroundColor: dimText, .font: font])
        if let range = text.range(of: bar) {
            let nsRange = NSRange(range, in: text)
            attr.addAttribute(.foregroundColor, value: barColor, range: nsRange)
        }
        lbl.attributedStringValue = attr
    }

    func pctInt(_ pct: String) -> Int? {
        Int(pct.replacingOccurrences(of: "%", with: ""))
    }

    func progressBar(_ pct: String, width: Int = 18) -> String {
        guard let n = pctInt(pct) else {
            return String(repeating: "░", count: width)
        }
        let filled = min(max(Int(Double(n) / 100.0 * Double(width) + 0.5), 0), width)
        return String(repeating: "█", count: filled) + String(repeating: "░", count: width - filled)
    }

    func barColor(_ pct: String) -> NSColor {
        guard let n = pctInt(pct) else { return .secondaryLabelColor }
        if n > 70 { return usageRed }
        if n >= 50 { return usageAmber }
        return usageGreen
    }

    func barColorForValue(_ pct: String, isRemaining: Bool) -> NSColor {
        guard let n = pctInt(pct) else { return .secondaryLabelColor }
        if isRemaining {
            if n < 30 { return usageRed }
            if n <= 50 { return usageAmber }
            return usageGreen
        }
        return barColor(pct)
    }

    func colorDot(_ pct: String) -> String {
        guard let n = pctInt(pct) else { return "⚪" }
        if n > 70 { return "🔴" }
        if n >= 50 { return "🟡" }
        return "🟢"
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

    func usedRemainingPcts(from block: [String: Any], weekly: Bool = false) -> (used: String, remaining: String) {
        let usedKey = weekly ? "weekly_pct" : "session_pct"
        let remainKey = weekly ? "weekly_remaining_pct" : "session_remaining_pct"

        let used = stringValue(block[usedKey])
        if let n = block[remainKey] as? NSNumber {
            return (used, "\(n.intValue)%")
        }
        if let u = pctInt(used) {
            return (used, "\(max(0, 100 - u))%")
        }
        return (used, "—")
    }

    func shortClock(_ value: String) -> String {
        if value == "Never" || value == "—" { return "--:--:--" }

        let pattern = #"\b\d{1,2}:\d{2}(?::\d{2})?(?:\s?[AP]M)?\b"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(value.startIndex..<value.endIndex, in: value)
            if let match = regex.firstMatch(in: value, options: [], range: range),
               let swiftRange = Range(match.range, in: value) {
                return String(value[swiftRange]).replacingOccurrences(of: " ", with: "")
            }
        }

        let parts = value.split(separator: " ")
        if let last = parts.last {
            return String(last)
        }
        return value
    }

    func compactClock(_ value: String) -> String {
        let c = shortClock(value)
        if c == "--:--:--" { return "--:--" }

        // Prefer compact HH:MM to avoid header clipping
        if let first = c.split(separator: " ").first {
            let token = String(first)
            let comps = token.split(separator: ":")
            if comps.count >= 2 {
                return "\(comps[0]):\(comps[1])"
            }
        }
        return c
    }

    func shortCountdown(_ reset: String) -> String {
        if reset.contains("Resets in") {
            return reset.replacingOccurrences(of: "Resets in ", with: "")
                .replacingOccurrences(of: "hr", with: "h")
                .replacingOccurrences(of: "min", with: "m")
        }
        if reset == "Resetting soon" {
            return "soon"
        }
        if reset.contains("Resets ") {
            return reset.replacingOccurrences(of: "Resets ", with: "")
        }
        return "—"
    }

    func shortResetPhrase(_ reset: String) -> String {
        let c = shortCountdown(reset)
        if c == "—" {
            return "Resets-—"
        }
        if c == "soon" {
            return "Resets-soon"
        }
        return "Resets in \(c)"
    }

    func weeklyResetPhrase(_ reset: String) -> String {
        let tz = TimeZone.autoupdatingCurrent.abbreviation() ?? TimeZone.autoupdatingCurrent.identifier

        if reset.hasPrefix("Resets ") {
            let raw = reset.replacingOccurrences(of: "Resets ", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            let parts = raw.split(separator: " ")

            if parts.count >= 3 {
                let dayToken = String(parts[0])
                let timeToken = String(parts[1]).replacingOccurrences(of: ":", with: ".")
                let ampm = String(parts[2])
                let dayMap: [String: String] = [
                    "Mon": "Monday", "Tue": "Tuesday", "Wed": "Wednesday", "Thu": "Thursday",
                    "Fri": "Friday", "Sat": "Saturday", "Sun": "Sunday",
                ]
                let fullDay = dayMap[dayToken] ?? dayToken
                return "Resets-\(fullDay) \(timeToken) \(ampm) \(tz)"
            }

            return "Resets-\(raw) \(tz)"
        }

        if reset.contains("Resets in") {
            let c = shortCountdown(reset)
            return c == "—" ? "Resets-—" : "Resets-\(c) \(tz)"
        }

        return "Resets-—"
    }

    func normalizedPlanLabel(_ raw: String, fallback: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return t.isEmpty || t == "—" ? fallback : t
    }

    func twoCol(_ left: String, _ right: String, total: Int = 58) -> String {
        let l = left
        let r = right
        let spaceCount = max(2, total - l.count - r.count)
        return "  " + l + String(repeating: " ", count: spaceCount) + r
    }

    func healthLabel(_ pct: String, isRemaining: Bool) -> String {
        guard let n = pctInt(pct) else { return "unknown" }
        if isRemaining {
            if n < 30 { return "at risk" }
            if n <= 50 { return "watch" }
            return "on track"
        }
        if n > 80 { return "at risk" }
        if n >= 50 { return "watch" }
        return "on track"
    }

    func updateUI(_ payload: [String: Any]) {
        let claude = usageBlock(from: payload, key: "claude", fallbackToRoot: true)
        let codex = usageBlock(from: payload, key: "codex")

        let cSReset = stringValue(claude["session_reset"])
        let cWReset = stringValue(claude["weekly_reset"])
        let cPlanRaw = stringValue(claude["plan_label"], fallback: "PRO")
        let cStatus = stringValue(claude["status"])

        let oWReset = stringValue(codex["weekly_reset"])
        let oSReset = stringValue(codex["session_reset"])
        let oPlanRaw = stringValue(codex["plan_label"], fallback: "PLUS")
        let oStatus = stringValue(codex["status"], fallback: codex.isEmpty ? "Waiting for data..." : "—")

        let updated = stringValue(payload["last_updated"], fallback: stringValue(claude["last_updated"], fallback: "Never"))

        let cSession = usedRemainingPcts(from: claude, weekly: false)
        let cWeekly = usedRemainingPcts(from: claude, weekly: true)
        let oSession = usedRemainingPcts(from: codex, weekly: false)
        let oWeekly = usedRemainingPcts(from: codex, weekly: true)

        let cSView = showRemaining ? cSession.remaining : cSession.used
        let cWView = showRemaining ? cWeekly.remaining : cWeekly.used
        let oSView = showRemaining ? oSession.remaining : oSession.used
        let oWView = showRemaining ? oWeekly.remaining : oWeekly.used

        let modeLabel = showRemaining ? "remaining" : "used"

        let cWDot = cWView != "—" ? colorDotForValue(cWView, isRemaining: showRemaining) : "⚪"
        let cSDot = cSView != "—" ? colorDotForValue(cSView, isRemaining: showRemaining) : "⚪"
        let oWDot = oWView != "—" ? colorDotForValue(oWView, isRemaining: showRemaining) : "⚪"
        let oSDot = oSView != "—" ? colorDotForValue(oSView, isRemaining: showRemaining) : "⚪"

        statusItem.button?.title = "C \(cWDot)\(cSDot)  O \(oWDot)\(oSDot)"

        pulseOn.toggle()
        let isLive = (cStatus == "Live") || (oStatus == "Live")
        let dot = pulseOn ? "●" : "◉"
        let headColor: NSColor = headerText
        let refreshText = "↻" + compactClock(updated)
        _ = isLive
        setLabel(lbHeader, twoCol("\(dot) Claude/Codex_Live Tracker", refreshText, total: columns), color: headColor, size: 13, bold: true, mono: true)
        setLabel(lbClaudeTitle, "  Claude  \(normalizedPlanLabel(cPlanRaw, fallback: "PRO"))", color: headerText, size: 14, bold: true)
        setLabel(lbCodexTitle, "  Codex  \(normalizedPlanLabel(oPlanRaw, fallback: "PLUS"))", color: headerText, size: 14, bold: true)

        setMeterTopLabel(lbClaudeSessionTop, title: "Session", pct: cSView, pctColor: barColorForValue(cSView, isRemaining: showRemaining))
        setBarRowLabel(lbClaudeSessionBottom, prefix: "5h window", pct: cSView, barColor: barColorForValue(cSView, isRemaining: showRemaining), barWidth: 18)
        setMeterTopLabel(lbClaudeWeeklyTop, title: "Weekly", pct: cWView, pctColor: barColorForValue(cWView, isRemaining: showRemaining))
        let cWeeklyPrefix = weeklyResetPhrase(cWReset)
        let cWeeklyWidth = cWeeklyPrefix.count > 16 ? 12 : 14
        setBarRowLabel(lbClaudeWeeklyBottom, prefix: cWeeklyPrefix, pct: cWView, suffix: healthLabel(cWView, isRemaining: showRemaining), barColor: barColorForValue(cWView, isRemaining: showRemaining), barWidth: cWeeklyWidth)

        let claudeCapped = (!showRemaining && (cSView == "100%"))
        claudeCappedItem.isHidden = !claudeCapped
        claudeSessionResetItem.isHidden = claudeCapped
        if claudeCapped {
            setLabel(lbClaudeCapped, "  Session capped. Unlock in \(shortCountdown(cSReset))", color: headerText, size: 12, bold: true, mono: true)
        } else {
            setLabel(lbClaudeSessionResetLine, "  \(shortResetPhrase(cSReset))", color: dimText, size: 11, mono: true)
        }

        setMeterTopLabel(lbCodexSessionTop, title: "Session", pct: oSView, pctColor: barColorForValue(oSView, isRemaining: showRemaining))
        setBarRowLabel(lbCodexSessionBottom, prefix: "5h window", pct: oSView, barColor: barColorForValue(oSView, isRemaining: showRemaining), barWidth: 18)
        let codexCapped = (!showRemaining && (oSView == "100%"))
        codexSessionResetItem.isHidden = codexCapped
        codexCappedItem.isHidden = !codexCapped
        if codexCapped {
            setLabel(lbCodexCapped, "  Session capped. Unlock in \(shortCountdown(oSReset))", color: headerText, size: 12, bold: true, mono: true)
        } else {
            setLabel(lbCodexSessionResetLine, "  \(shortResetPhrase(oSReset))", color: dimText, size: 11, mono: true)
        }
        setMeterTopLabel(lbCodexWeeklyTop, title: "Weekly", pct: oWView, pctColor: barColorForValue(oWView, isRemaining: showRemaining))
        let oWeeklyPrefix = weeklyResetPhrase(oWReset)
        let oWeeklyWidth = oWeeklyPrefix.count > 16 ? 12 : 14
        setBarRowLabel(lbCodexWeeklyBottom, prefix: oWeeklyPrefix, pct: oWView, suffix: healthLabel(oWView, isRemaining: showRemaining), barColor: barColorForValue(oWView, isRemaining: showRemaining), barWidth: oWeeklyWidth)

        let toggleTitle = showRemaining ? "Show Used %" : "Show Remaining %"
        toggleUsageModeItem.title = toggleTitle
        setLabel(lbToggleActionTitle, "  \(toggleTitle)", color: headerText, size: 13, bold: false, mono: false)

        _ = modeLabel
    }

    @objc func toggleUsageMode() {
        showRemaining.toggle()
        loadData()
    }

    @objc func openClaudeAnalytics() {
        guard let url = URL(string: "https://claude.ai/settings/usage") else { return }
        NSWorkspace.shared.open(url)
    }

    @objc func openCodexAnalytics() {
        guard let url = URL(string: "https://chatgpt.com/codex/cloud/settings/analytics#usage") else { return }
        NSWorkspace.shared.open(url)
    }

    @objc func restartTracker() {
        let launchPath = Bundle.main.executablePath ?? (NSHomeDirectory() + "/.local/bin/claude-tracker")
        let escaped = launchPath.replacingOccurrences(of: "\"", with: "\\\"")

        isQuitting = true
        pythonProcess?.terminate()

        let relaunch = Process()
        relaunch.executableURL = URL(fileURLWithPath: "/bin/sh")
        relaunch.arguments = ["-c", "sleep 0.25; \"\(escaped)\" >/tmp/claude-tracker.log 2>&1 &"]
        relaunch.standardOutput = FileHandle.nullDevice
        relaunch.standardError = FileHandle.nullDevice
        try? relaunch.run()

        NSApp.terminate(nil)
    }

    @objc func quitApp() {
        isQuitting = true
        pythonProcess?.terminate()
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        isQuitting = true
        pythonProcess?.terminate()
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
