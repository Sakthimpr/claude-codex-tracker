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
        CATransaction.setAnimationDuration(0.10)
        layer?.transform = CATransform3DMakeScale(1.01, 1.01, 1.0)
        layer?.backgroundColor = hoverColor.cgColor
        layer?.cornerRadius = 8
        layer?.shadowColor = NSColor.black.withAlphaComponent(0.22).cgColor
        layer?.shadowOpacity = 0.22
        layer?.shadowRadius = 4
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
        CATransaction.setAnimationDuration(0.10)
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

final class ProgressBarMenuRowView: NSView {
    var fillFraction: CGFloat = 0.0 { didSet { needsDisplay = true } }
    var secondaryFraction: CGFloat = 0.0 { didSet { needsDisplay = true } }
    var tickFraction: CGFloat? { didSet { needsDisplay = true } }
    var fillColor: NSColor = .systemGreen { didSet { needsDisplay = true } }
    var secondaryColor: NSColor = NSColor(calibratedWhite: 1.0, alpha: 0.18) { didSet { needsDisplay = true } }
    var trackColor: NSColor = NSColor(calibratedRed: 0.29, green: 0.32, blue: 0.31, alpha: 0.75) { didSet { needsDisplay = true } }
    var glowFactor: CGFloat = 1.0 { didSet { needsDisplay = true } }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.saveGState()

        let insetX: CGFloat = 16
        let barHeight: CGFloat = 4
        let trackRect = NSRect(
            x: insetX,
            y: max(0.0, (bounds.height - barHeight) / 2.0),
            width: max(10, bounds.width - insetX * 2),
            height: barHeight
        )

        let trackPath = NSBezierPath(roundedRect: trackRect, xRadius: barHeight / 2, yRadius: barHeight / 2)
        trackColor.setFill()
        trackPath.fill()
        let glow = min(max(glowFactor, 0.0), 1.0)

        let clampedSecondary = min(max(secondaryFraction, 0.0), 1.0)
        if clampedSecondary > 0.0 {
            let rawWidth = trackRect.width * clampedSecondary
            let fillWidth = min(trackRect.width, max(rawWidth, 2.0))
            let fillRect = NSRect(x: trackRect.minX, y: trackRect.minY, width: fillWidth, height: trackRect.height)
            let fillRadius = min(barHeight / 2, max(1.5, fillRect.width / 3.5))
            let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: fillRadius, yRadius: fillRadius)
            let secondaryCore = secondaryColor.blended(withFraction: 0.14, of: .white) ?? secondaryColor
            let secondaryAtmosphere = NSRect(
                x: fillRect.minX,
                y: fillRect.minY - 1.8,
                width: fillRect.width,
                height: fillRect.height + 3.6
            )
            let secondaryAtmospherePath = NSBezierPath(
                roundedRect: secondaryAtmosphere,
                xRadius: (fillRect.height + 3.6) / 2,
                yRadius: (fillRect.height + 3.6) / 2
            )

            ctx.saveGState()
            ctx.setShadow(offset: .zero, blur: 20.0 * glow, color: secondaryColor.withAlphaComponent(0.28 * glow).cgColor)
            secondaryColor.withAlphaComponent(0.60).setFill()
            secondaryAtmospherePath.fill()
            ctx.restoreGState()

            ctx.saveGState()
            ctx.setShadow(offset: .zero, blur: 12.0 * glow, color: secondaryColor.withAlphaComponent(0.50 * glow).cgColor)
            secondaryColor.withAlphaComponent(0.78).setFill()
            fillPath.fill()
            ctx.restoreGState()

            ctx.saveGState()
            ctx.setShadow(offset: .zero, blur: 7.5 * glow, color: secondaryColor.withAlphaComponent(0.68 * glow).cgColor)
            secondaryCore.setFill()
            fillPath.fill()
            ctx.restoreGState()

            secondaryCore.setFill()
            fillPath.fill()
        }

        let clampedFill = min(max(fillFraction, 0.0), 1.0)
        if clampedFill > 0.0 {
            let rawWidth = trackRect.width * clampedFill
            let fillWidth = min(trackRect.width, max(rawWidth, 2.0))
            let fillRect = NSRect(x: trackRect.minX, y: trackRect.minY, width: fillWidth, height: trackRect.height)
            let fillRadius = min(barHeight / 2, max(1.5, fillRect.width / 3.5))
            let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: fillRadius, yRadius: fillRadius)
            let primaryCore = fillColor.blended(withFraction: 0.20, of: .white) ?? fillColor
            let primaryAtmosphere = NSRect(
                x: fillRect.minX,
                y: fillRect.minY - 2.3,
                width: fillRect.width,
                height: fillRect.height + 4.6
            )
            let primaryAtmospherePath = NSBezierPath(
                roundedRect: primaryAtmosphere,
                xRadius: (fillRect.height + 4.6) / 2,
                yRadius: (fillRect.height + 4.6) / 2
            )

            ctx.saveGState()
            ctx.setShadow(offset: .zero, blur: 26.0 * glow, color: fillColor.withAlphaComponent(0.30 * glow).cgColor)
            fillColor.withAlphaComponent(0.58).setFill()
            primaryAtmospherePath.fill()
            ctx.restoreGState()

            ctx.saveGState()
            ctx.setShadow(offset: .zero, blur: 15.0 * glow, color: fillColor.withAlphaComponent(0.50 * glow).cgColor)
            fillColor.withAlphaComponent(0.82).setFill()
            fillPath.fill()
            ctx.restoreGState()

            ctx.saveGState()
            ctx.setShadow(offset: .zero, blur: 9.5 * glow, color: fillColor.withAlphaComponent(0.72 * glow).cgColor)
            primaryCore.setFill()
            fillPath.fill()
            ctx.restoreGState()

            primaryCore.setFill()
            fillPath.fill()
        }

        if let tickFraction {
            let t = min(max(tickFraction, 0.0), 1.0)
            let x = trackRect.minX + trackRect.width * t
            let tickRect = NSRect(x: x - 0.75, y: trackRect.minY - 1.0, width: 1.5, height: trackRect.height + 2)
            let tickPath = NSBezierPath(roundedRect: tickRect, xRadius: 1.0, yRadius: 1.0)
            NSColor(calibratedWhite: 1.0, alpha: 0.58).setFill()
            tickPath.fill()
        }

        ctx.restoreGState()
    }
}

final class DialPairMenuRowView: NSView {
    var leftFraction:  CGFloat = 0.0   { didSet { needsDisplay = true } }
    var leftColor:     NSColor = .systemGreen { didSet { needsDisplay = true } }
    var leftPct:       String  = "—"   { didSet { needsDisplay = true } }
    var leftLabel:     String  = "Current" { didSet { needsDisplay = true } }
    var leftReset:     String  = "—"   { didSet { needsDisplay = true } }
    var leftWarning:   Bool    = false { didSet { needsDisplay = true } }
    var leftGlow:      CGFloat = 1.0   { didSet { needsDisplay = true } }

    var rightFraction: CGFloat = 0.0   { didSet { needsDisplay = true } }
    var rightColor:    NSColor = .systemGreen { didSet { needsDisplay = true } }
    var rightPct:      String  = "—"   { didSet { needsDisplay = true } }
    var rightLabel:    String  = "Weekly" { didSet { needsDisplay = true } }
    var rightSublabel: String  = ""    { didSet { needsDisplay = true } }
    var rightReset:    String  = "—"   { didSet { needsDisplay = true } }
    var rightWarning:  Bool    = false { didSet { needsDisplay = true } }
    var rightGlow:     CGFloat = 1.0   { didSet { needsDisplay = true } }

    var showThird:    Bool    = false { didSet { needsDisplay = true } }
    var showDivider:  Bool    = false { didSet { needsDisplay = true } }

    var thirdFraction: CGFloat = 0.0   { didSet { needsDisplay = true } }
    var thirdColor:    NSColor = .systemGreen { didSet { needsDisplay = true } }
    var thirdPct:      String  = "—"   { didSet { needsDisplay = true } }
    var thirdLabel:    String  = "Design" { didSet { needsDisplay = true } }
    var thirdSublabel: String  = ""    { didSet { needsDisplay = true } }
    var thirdReset:    String  = "—"   { didSet { needsDisplay = true } }
    var thirdWarning:  Bool    = false { didSet { needsDisplay = true } }
    var thirdGlow:     CGFloat = 1.0   { didSet { needsDisplay = true } }

    private var drawRadius:  CGFloat { showThird ? 22.0 : 32.5 }
    private var trackWidth:  CGFloat { showThird ? 4.0  : 5.0  }
    private var fillWidth:   CGFloat { showThird ? 5.5  : 7.0  }
    private var dialCenterY: CGFloat { showThird ? 50.0 : 58.0 }
    private let startAngle:  CGFloat = 225.0
    private let totalSweep:  CGFloat = 270.0

    private let trackCol = NSColor(calibratedRed: 0.29, green: 0.32, blue: 0.31, alpha: 0.55)
    private let dimCol   = NSColor(calibratedRed: 0.70, green: 0.73, blue: 0.78, alpha: 1.0)

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let lx = bounds.width * (showThird ? 0.167 : 0.27)
        let mx = bounds.width * (showThird ? 0.500 : 0.73)
        drawDial(cx: lx, fraction: leftFraction,  color: leftColor,
                 pct: leftPct,   label: leftLabel,   reset: leftReset,
                 warning: leftWarning,  glow: leftGlow)
        drawDial(cx: mx, fraction: rightFraction, color: rightColor,
                 pct: rightPct,  label: rightLabel,  reset: rightReset,
                 warning: rightWarning, glow: rightGlow, skipReset: showThird,
                 sublabel: rightSublabel)
        if showThird {
            let rx = bounds.width * 0.833
            drawDial(cx: rx, fraction: thirdFraction, color: thirdColor,
                     pct: thirdPct, label: thirdLabel, reset: thirdReset,
                     warning: thirdWarning, glow: thirdGlow, skipReset: true,
                     sublabel: thirdSublabel)
            if showDivider { drawVerticalDivider() }
            drawSharedReset(cx: (mx + rx) / 2, text: rightReset)
        }
    }

    private func drawDial(cx: CGFloat, fraction: CGFloat, color: NSColor,
                          pct: String, label: String, reset: String,
                          warning: Bool, glow: CGFloat, skipReset: Bool = false,
                          sublabel: String = "") {
        let center = CGPoint(x: cx, y: dialCenterY)
        let clamp  = min(max(fraction, 0), 1)

        // Track arc
        let trackPath = NSBezierPath()
        trackPath.appendArc(withCenter: center, radius: drawRadius,
                            startAngle: startAngle, endAngle: startAngle - totalSweep,
                            clockwise: true)
        trackPath.lineWidth = trackWidth
        trackPath.lineCapStyle = .round
        trackCol.setStroke()
        trackPath.stroke()

        // Fill arc
        if clamp > 0 {
            let fillEnd = startAngle - clamp * totalSweep
            let fillPath = NSBezierPath()
            fillPath.appendArc(withCenter: center, radius: drawRadius,
                               startAngle: startAngle, endAngle: fillEnd, clockwise: true)
            fillPath.lineWidth = fillWidth
            fillPath.lineCapStyle = .round

            NSGraphicsContext.saveGraphicsState()
            let gs = NSShadow()
            gs.shadowColor = color.withAlphaComponent(0.55 * glow)
            gs.shadowBlurRadius = 9 * glow
            gs.shadowOffset = .zero
            gs.set()
            color.setStroke()
            fillPath.stroke()
            NSGraphicsContext.restoreGraphicsState()

            color.setStroke()
            fillPath.stroke()
        }

        // Centre percentage
        let pctFont  = NSFont.monospacedDigitSystemFont(ofSize: showThird ? 13 : 16, weight: .bold)
        let pctColor = clamp > 0 ? (color.blended(withFraction: 0.40, of: .white) ?? color) : dimCol.withAlphaComponent(0.50)
        let pctAttrs: [NSAttributedString.Key: Any] = [.foregroundColor: pctColor, .font: pctFont]
        let pctStr   = pct as NSString
        let pctSize  = pctStr.size(withAttributes: pctAttrs)
        pctStr.draw(at: CGPoint(x: center.x - pctSize.width / 2,
                                y: center.y - pctSize.height / 2),
                    withAttributes: pctAttrs)

        // Warning symbol inside arc
        if warning {
            let wAttrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor(calibratedRed: 1.0, green: 0.18, blue: 0.24, alpha: 0.60),
                .font: NSFont.systemFont(ofSize: 8, weight: .semibold)
            ]
            let ws = "⚠" as NSString
            let wSz = ws.size(withAttributes: wAttrs)
            ws.draw(at: CGPoint(x: center.x - wSz.width / 2,
                                y: center.y + drawRadius * 0.50),
                    withAttributes: wAttrs)
        }

        // Label above arc
        let lblAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor(calibratedWhite: 0.92, alpha: 1.0),
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold)
        ]
        let lblStr  = label as NSString
        let lblSize = lblStr.size(withAttributes: lblAttrs)
        let arcTop  = center.y + drawRadius + trackWidth / 2
        lblStr.draw(at: CGPoint(x: center.x - lblSize.width / 2, y: arcTop + 5),
                    withAttributes: lblAttrs)
        if !sublabel.isEmpty {
            let subAttrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor(calibratedWhite: 0.82, alpha: 1.0),
                .font: NSFont.systemFont(ofSize: 11, weight: .medium)
            ]
            let subStr  = sublabel as NSString
            let subSize = subStr.size(withAttributes: subAttrs)
            subStr.draw(at: CGPoint(x: center.x - subSize.width / 2,
                                    y: arcTop + 5 + lblSize.height + 1),
                        withAttributes: subAttrs)
        }

        // Reset line below arc
        if !skipReset {
            let rstAttrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor(calibratedWhite: 0.92, alpha: 1.0),
                .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium)
            ]
            let rstStr  = reset as NSString
            let rstSize = rstStr.size(withAttributes: rstAttrs)
            let arcBot  = center.y - drawRadius - trackWidth / 2
            rstStr.draw(at: CGPoint(x: center.x - rstSize.width / 2,
                                    y: arcBot - rstSize.height - 4),
                        withAttributes: rstAttrs)
        }
    }

    private func drawSharedReset(cx: CGFloat, text: String) {
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor(calibratedWhite: 0.92, alpha: 1.0),
            .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        ]
        let str  = text as NSString
        let size = str.size(withAttributes: attrs)
        let arcBot = dialCenterY - drawRadius - trackWidth / 2
        str.draw(at: CGPoint(x: cx - size.width / 2, y: arcBot - size.height - 4),
                 withAttributes: attrs)
    }

    private func drawVerticalDivider() {
        let x = bounds.width * 0.360
        let halfH = drawRadius + trackWidth * 4.5
        let path = NSBezierPath()
        path.move(to: CGPoint(x: x, y: dialCenterY - halfH))
        path.line(to: CGPoint(x: x, y: dialCenterY + halfH))
        path.lineWidth = 1.0
        NSColor(calibratedWhite: 1.0, alpha: 0.18).setStroke()
        path.stroke()
    }
}

final class WarnBannerView: NSView {
    private let label = NSTextField(labelWithString: "")
    var accentColor: NSColor = NSColor(calibratedRed: 0.86, green: 0.70, blue: 0.45, alpha: 1.0)

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        label.font = NSFont.systemFont(ofSize: 10.5, weight: .medium)
        label.textColor = NSColor(calibratedWhite: 0.88, alpha: 1.0)
        label.drawsBackground = false
        label.isBezeled = false
        label.isEditable = false
        label.isSelectable = false
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        addSubview(label)
    }
    required init?(coder: NSCoder) { fatalError() }

    func update(message: String, color: NSColor) {
        label.stringValue = message
        accentColor = color
        needsDisplay = true
    }

    override func layout() {
        super.layout()
        label.frame = NSRect(x: 14, y: (bounds.height - 16) / 2,
                             width: bounds.width - 18, height: 16)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        // Tinted background to make it read as a bar
        accentColor.withAlphaComponent(0.22).setFill()
        NSBezierPath(rect: bounds).fill()
        // Left accent stripe
        let stripe = NSBezierPath(rect: NSRect(x: 0, y: 0, width: 5, height: bounds.height))
        accentColor.withAlphaComponent(0.95).setFill()
        stripe.fill()
    }
}

protocol SectionHoverDelegate: AnyObject {
    func sectionHoverChanged(group: String, delta: Int)
}

protocol StatusDotHoverDelegate: AnyObject {
    func statusDotHoverChanged(key: String, entered: Bool, anchor: NSView)
}

final class SectionHoverRowView: NSView {
    weak var delegate: SectionHoverDelegate?
    var group: String = ""
    var trackingAreaRef: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area = trackingAreaRef {
            removeTrackingArea(area)
        }
        let opts: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways, .inVisibleRect]
        let area = NSTrackingArea(rect: bounds, options: opts, owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingAreaRef = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        delegate?.sectionHoverChanged(group: group, delta: 1)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        delegate?.sectionHoverChanged(group: group, delta: -1)
    }
}

final class StatusDotTooltipView: NSView {
    weak var hoverDelegate: StatusDotHoverDelegate?
    var metricKey: String = ""
    private var trackingAreaRef: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area = trackingAreaRef {
            removeTrackingArea(area)
        }
        let opts: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways, .inVisibleRect]
        let area = NSTrackingArea(rect: bounds, options: opts, owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingAreaRef = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        hoverDelegate?.statusDotHoverChanged(key: metricKey, entered: true, anchor: self)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        hoverDelegate?.statusDotHoverChanged(key: metricKey, entered: false, anchor: self)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Keep status button click behavior unchanged while still enabling tooltip regions.
        nil
    }
}

final class StatusTooltipRowView: NSView {
    let label = NSTextField(labelWithString: "")
    var accentColor: NSColor

    init(accentColor: NSColor) {
        self.accentColor = accentColor
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.masksToBounds = true
        label.drawsBackground = false
        label.isBezeled = false
        label.isEditable = false
        label.isSelectable = false
        label.lineBreakMode = .byTruncatingTail
        addSubview(label)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        label.frame = NSRect(x: 6, y: 2, width: max(0, bounds.width - 12), height: max(0, bounds.height - 4))
    }

    func update(text: String, active: Bool) {
        let fg = NSColor(calibratedWhite: 0.94, alpha: 1.0)
        label.attributedStringValue = NSAttributedString(
            string: text,
            attributes: [
                .foregroundColor: fg,
                .font: NSFont.systemFont(ofSize: 11, weight: active ? .semibold : .regular),
            ]
        )
        layer?.backgroundColor = accentColor.withAlphaComponent(active ? 0.22 : 0.12).cgColor
        layer?.borderWidth = active ? 1.0 : 0.7
        layer?.borderColor = accentColor.withAlphaComponent(active ? 0.42 : 0.22).cgColor
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, SectionHoverDelegate, StatusDotHoverDelegate {
    var statusItem: NSStatusItem!
    var appMenu: NSMenu!
    var pythonProcess: Process?
    var isQuitting = false
    var showRemaining = false
    var toggleUsageModeItem: NSMenuItem!
    var lbToggleActionTitle: NSTextField!
    var toggleShortcutText: String = "⌘M"
    var lastPayload: [String: Any]?

    var lbHeader: NSTextField!
    var lbClaudeTitle: NSTextField!
    var lbCodexTitle: NSTextField!

    var claudeDialView: DialPairMenuRowView!
    var claudeDialItem: NSMenuItem!
    var codexDialView: DialPairMenuRowView!
    var codexDialItem: NSMenuItem!
    var claudeIsCapped = false
    var codexIsCapped = false
    var claudeWeeklyIsCapped = false
    var codexWeeklyIsCapped = false

    var claudeWarningItem:  NSMenuItem!
    var claudeWarningView:  WarnBannerView!
    var codexWarningItem:   NSMenuItem!
    var codexWarningView:   WarnBannerView!

    var pulseOn = false
    let rowWidth: CGFloat = 360
    let textWidth: CGFloat = 340
    let columns = 54
    let textLeftX: CGFloat = 12
    let barInsetX: CGFloat = 14

    let usageRed = NSColor(calibratedRed: 0.84, green: 0.67, blue: 0.42, alpha: 1.0)
    let usageAmber = NSColor(calibratedRed: 0.86, green: 0.70, blue: 0.45, alpha: 1.0)
    let usageGreen = NSColor(calibratedRed: 0.1843, green: 0.4784, blue: 0.3451, alpha: 1.0) // #2F7A58
    let usageHealthyGold = NSColor(calibratedRed: 0.8667, green: 0.7216, blue: 0.3569, alpha: 1.0)
    let usageCriticalAmber = NSColor(calibratedRed: 0.82, green: 0.67, blue: 0.38, alpha: 1.0)
    let usageCriticalRed = NSColor(calibratedRed: 1.00, green: 0.18, blue: 0.24, alpha: 0.60)
    let usageCappedMuted = NSColor(calibratedRed: 0.60, green: 0.57, blue: 0.52, alpha: 1.0)
    let panelTeal = NSColor(calibratedRed: 0.11, green: 0.13, blue: 0.17, alpha: 0.92)
    let actionHoverTeal = NSColor(calibratedRed: 0.16, green: 0.18, blue: 0.22, alpha: 0.95)
    let subBoxTeal = NSColor(calibratedRed: 0.12, green: 0.14, blue: 0.18, alpha: 0.94)
    let subBoxStroke = NSColor(calibratedWhite: 1.0, alpha: 0.06)
    let headerText = NSColor(calibratedRed: 0.94, green: 0.95, blue: 0.96, alpha: 1.0)
    let dimText = NSColor(calibratedRed: 0.70, green: 0.73, blue: 0.78, alpha: 1.0)
    // Identity colors: separate from usage-state colors (green/amber/red bars).
    // Brown palette accents per request: one dark + one light.
    let claudeHeaderTint = NSColor(calibratedRed: 0.95, green: 0.94, blue: 0.90, alpha: 1.0)
    let codexHeaderTint = NSColor(calibratedRed: 0.78, green: 0.68, blue: 0.42, alpha: 1.0)
    // Subtle section differentiation for Claude/Codex blocks.
    let claudePanelTint = NSColor(calibratedRed: 0.09, green: 0.10, blue: 0.16, alpha: 0.94)
    let codexPanelTint = NSColor(calibratedRed: 0.08, green: 0.125, blue: 0.12, alpha: 0.94)
    let footerPanelTint = NSColor(calibratedRed: 0.105, green: 0.125, blue: 0.165, alpha: 0.94)
    let claudeSubBoxTint = NSColor(calibratedRed: 0.125, green: 0.145, blue: 0.185, alpha: 0.94)
    let codexSubBoxTint = NSColor(calibratedRed: 0.085, green: 0.125, blue: 0.135, alpha: 0.94)
    var sectionViews: [String: [NSView]] = ["claude": [], "codex": []]
    var sectionHoverCount: [String: Int] = ["claude": 0, "codex": 0]
    var baseRowBackgrounds: [ObjectIdentifier: CGColor] = [:]
    var lastDataMTime: Date?
    var claudeSessionDotTipView: StatusDotTooltipView?
    var claudeWeeklyDotTipView: StatusDotTooltipView?
    var claudeDesignDotTipView: StatusDotTooltipView?
    var codexSessionDotTipView: StatusDotTooltipView?
    var codexWeeklyDotTipView: StatusDotTooltipView?
    var statusDotPopover: NSPopover?
    var statusDotRows: [String: StatusTooltipRowView] = [:]
    var statusDotTexts: [String: String] = [:]
    var statusDotColors: [String: NSColor] = [:]
    var activeStatusDotKey: String?
    var pendingPopoverHide: DispatchWorkItem?
    var globalMouseMonitor: Any?
    var sharedDataPath = NSHomeDirectory() + "/.cache/claude-codex-tracker/data.json"

    private let shortClockRegex = try! NSRegularExpression(pattern: #"\b\d{1,2}:\d{2}(?::\d{2})?(?:\s?[AP]M)?\b"#)
    private let shortHmRegex = try! NSRegularExpression(pattern: #"\b\d{1,2}:\d{2}\b"#)
    private lazy var uiClockFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .autoupdatingCurrent
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()
    private lazy var parser12HourFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .autoupdatingCurrent
        f.dateFormat = "h:mm a"
        return f
    }()
    private lazy var shortDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .autoupdatingCurrent
        f.dateFormat = "EEE"
        return f
    }()

    func panelColor(for group: String?) -> NSColor {
        switch group {
        case "claude":
            return claudePanelTint
        case "codex":
            return codexPanelTint
        case "footer":
            return footerPanelTint
        default:
            return panelTeal
        }
    }

    func subBoxColor(for group: String?) -> NSColor {
        // Keep sub-rows on the same tint as the section to avoid seam/gap feel.
        panelColor(for: group)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        buildStatusItem()
        startPolling()
        setupGlobalMouseMonitor()
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.5) {
            self.launchPython()
        }
    }

    func makeRow(
        text: String,
        color: NSColor,
        size: CGFloat = 13,
        bold: Bool = false,
        height: CGFloat = 22,
        mono: Bool = false,
        hoverGroup: String? = nil
    ) -> (NSMenuItem, NSTextField) {
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

        let view: NSView
        if let group = hoverGroup {
            let hv = SectionHoverRowView(frame: NSRect(x: 0, y: 0, width: rowWidth, height: height))
            hv.group = group
            hv.delegate = self
            view = hv
        } else {
            view = NSView(frame: NSRect(x: 0, y: 0, width: rowWidth, height: height))
        }
        view.wantsLayer = true
        let rowBG = panelColor(for: hoverGroup)
        view.layer?.backgroundColor = rowBG.cgColor
        baseRowBackgrounds[ObjectIdentifier(view)] = rowBG.cgColor
        view.addSubview(tf)

        if let group = hoverGroup {
            sectionViews[group, default: []].append(view)
        }

        let item = NSMenuItem()
        item.view = view
        return (item, tf)
    }

    func makeSeparatorRow(height: CGFloat = 10, group: String? = nil) -> NSMenuItem {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: rowWidth, height: height))
        view.wantsLayer = true
        let rowBG = panelColor(for: group)
        view.layer?.backgroundColor = rowBG.cgColor
        baseRowBackgrounds[ObjectIdentifier(view)] = rowBG.cgColor

        let line = NSView(frame: NSRect(x: 16, y: (height - 1) / 2, width: rowWidth - 32, height: 1))
        line.wantsLayer = true
        line.layer?.backgroundColor = NSColor(calibratedWhite: 1.0, alpha: 0.16).cgColor
        view.addSubview(line)

        let item = NSMenuItem()
        item.view = view
        return item
    }

    func makeTightDividerRow(group: String? = nil) -> NSMenuItem {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: rowWidth, height: 2))
        view.wantsLayer = true
        let rowBG = panelColor(for: group)
        view.layer?.backgroundColor = rowBG.cgColor
        baseRowBackgrounds[ObjectIdentifier(view)] = rowBG.cgColor

        let line = NSView(frame: NSRect(x: 16, y: 0, width: rowWidth - 32, height: 1))
        line.wantsLayer = true
        line.layer?.backgroundColor = NSColor(calibratedWhite: 1.0, alpha: 0.16).cgColor
        view.addSubview(line)

        let item = NSMenuItem()
        item.view = view
        return item
    }

    func makeDottedDividerRow(hoverGroup: String? = nil, height: CGFloat = 6) -> NSMenuItem {
        let view: NSView
        if let group = hoverGroup {
            let hv = SectionHoverRowView(frame: NSRect(x: 0, y: 0, width: rowWidth, height: height))
            hv.group = group
            hv.delegate = self
            view = hv
        } else {
            view = NSView(frame: NSRect(x: 0, y: 0, width: rowWidth, height: height))
        }
        view.wantsLayer = true
        let rowBG = subBoxColor(for: hoverGroup)
        view.layer?.backgroundColor = rowBG.cgColor
        baseRowBackgrounds[ObjectIdentifier(view)] = rowBG.cgColor

        let line = CAShapeLayer()
        // Place divider near center to keep breathing room both above and below.
        let y = height / 2.0
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 16, y: y))
        p.addLine(to: CGPoint(x: rowWidth - 16, y: y))
        line.path = p
        line.strokeColor = NSColor(calibratedWhite: 1.0, alpha: 0.16).cgColor
        line.lineWidth = 1.0
        line.lineDashPattern = [3, 3]
        view.layer?.addSublayer(line)

        if let group = hoverGroup {
            sectionViews[group, default: []].append(view)
        }
        let item = NSMenuItem()
        item.view = view
        return item
    }

    func makeSpacerRow(height: CGFloat = 8, hoverGroup: String? = nil) -> NSMenuItem {
        let view: NSView
        if let group = hoverGroup {
            let hv = SectionHoverRowView(frame: NSRect(x: 0, y: 0, width: rowWidth, height: height))
            hv.group = group
            hv.delegate = self
            view = hv
        } else {
            view = NSView(frame: NSRect(x: 0, y: 0, width: rowWidth, height: height))
        }
        view.wantsLayer = true
        let rowBG = panelColor(for: hoverGroup)
        view.layer?.backgroundColor = rowBG.cgColor
        baseRowBackgrounds[ObjectIdentifier(view)] = rowBG.cgColor
        if let group = hoverGroup {
            sectionViews[group, default: []].append(view)
        }
        let item = NSMenuItem()
        item.view = view
        return item
    }

    func makeProgressBarRow(height: CGFloat = 20, hoverGroup: String? = nil) -> (NSMenuItem, ProgressBarMenuRowView) {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: rowWidth, height: height))
        container.wantsLayer = true
        let rowBG = subBoxColor(for: hoverGroup)
        container.layer?.backgroundColor = rowBG.cgColor
        baseRowBackgrounds[ObjectIdentifier(container)] = rowBG.cgColor
        if let group = hoverGroup {
            sectionViews[group, default: []].append(container)
        }

        let bar = ProgressBarMenuRowView(frame: NSRect(x: 0, y: 0, width: rowWidth, height: height))
        bar.fillColor = usageGreen
        bar.trackColor = NSColor(calibratedRed: 0.29, green: 0.32, blue: 0.31, alpha: 0.75)
        container.addSubview(bar)

        let item = NSMenuItem()
        item.view = container
        return (item, bar)
    }

    func makeDialPairRow(height: CGFloat = 110, hoverGroup: String? = nil) -> (NSMenuItem, DialPairMenuRowView) {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: rowWidth, height: height))
        container.wantsLayer = true
        let rowBG = subBoxColor(for: hoverGroup)
        container.layer?.backgroundColor = rowBG.cgColor
        baseRowBackgrounds[ObjectIdentifier(container)] = rowBG.cgColor
        if let group = hoverGroup {
            sectionViews[group, default: []].append(container)
        }
        let dial = DialPairMenuRowView(frame: NSRect(x: 0, y: 0, width: rowWidth, height: height))
        container.addSubview(dial)
        let item = NSMenuItem()
        item.view = container
        return (item, dial)
    }

    func makeWarnBannerRow(group: String) -> (NSMenuItem, WarnBannerView) {
        let height: CGFloat = 30
        let container = NSView(frame: NSRect(x: 0, y: 0, width: rowWidth, height: height))
        container.wantsLayer = true
        let bg = panelColor(for: group)
        container.layer?.backgroundColor = bg.cgColor
        baseRowBackgrounds[ObjectIdentifier(container)] = bg.cgColor
        sectionViews[group, default: []].append(container)
        let banner = WarnBannerView(frame: NSRect(x: 0, y: 0, width: rowWidth, height: height))
        banner.wantsLayer = true
        banner.layer?.backgroundColor = bg.withAlphaComponent(0.18).cgColor
        container.addSubview(banner)
        let item = NSMenuItem()
        item.view = container
        return (item, banner)
    }

    func makeActionRow(title: String, shortcut: String, action: Selector, keyEquivalent: String) -> (NSMenuItem, NSTextField) {
        let view = ClickableMenuRowView(frame: NSRect(x: 0, y: 0, width: rowWidth, height: 24))
        view.wantsLayer = true
        let footerBG = panelColor(for: "footer")
        view.layer?.backgroundColor = footerBG.cgColor
        baseRowBackgrounds[ObjectIdentifier(view)] = footerBG.cgColor
        view.normalColor = footerBG
        view.hoverColor = actionHoverTeal
        view.currentColor = footerBG

        let left = NSTextField(frame: NSRect(x: 12, y: 3, width: textWidth, height: 18))
        left.drawsBackground = false
        left.isBezeled = false
        left.isEditable = false
        left.isSelectable = false
        setActionRowLabel(left, title: title, shortcut: shortcut)

        view.addSubview(left)

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

    func setActionRowLabel(_ lbl: NSTextField, title: String, shortcut: String) {
        _ = shortcut
        let text = "  \(title)"
        lbl.attributedStringValue = NSAttributedString(
            string: text,
            attributes: [
                .foregroundColor: headerText,
                .font: NSFont.systemFont(ofSize: 11.5, weight: .regular),
            ]
        )
    }

    func tightenMeterLabelGap(_ lbl: NSTextField) {
        var f = lbl.frame
        f.origin.y = 0.0
        lbl.frame = f
    }

    func setWeeklyLabelGap(_ lbl: NSTextField) {
        var f = lbl.frame
        // Increase breathing room below dotted divider and above WEEKLY.
        f.origin.y = -2.0
        lbl.frame = f
    }

    func buildMenu() {
        appMenu = NSMenu()
        appMenu.autoenablesItems = false
        appMenu.appearance = NSAppearance(named: .darkAqua)

        let header = headerText

        let (h, lbH) = makeRow(text: "  ● Claude & Codex — Usage                         --:--", color: header, size: 13, bold: true, height: 40, mono: false)
        lbHeader = lbH
        if let hv = h.view {
            hv.wantsLayer = true
            hv.layer?.backgroundColor = NSColor(calibratedRed: 0.06, green: 0.08, blue: 0.12, alpha: 1.0).cgColor
            // Bottom separator line
            let sep = CALayer()
            sep.frame = CGRect(x: 0, y: 0, width: rowWidth, height: 1)
            sep.backgroundColor = NSColor(calibratedWhite: 1.0, alpha: 0.10).cgColor
            hv.layer?.addSublayer(sep)
        }
        appMenu.addItem(h)
        let claudeStartSpacer = makeSpacerRow(height: 6, hoverGroup: "claude")
        appMenu.addItem(claudeStartSpacer)

        let (clh, lbCLH) = makeRow(text: "  Claude", color: header, size: 14, bold: true, height: 30, hoverGroup: "claude")
        lbClaudeTitle = lbCLH
        styleSubBoxRow(clh.view, corners: [], group: "claude")
        addSectionHeaderChip(clh.view, tint: NSColor(calibratedRed: 0.74, green: 0.78, blue: 0.86, alpha: 1.0))
        appMenu.addItem(clh)
        appMenu.addItem(makeSpacerRow(height: 4, hoverGroup: "claude"))

        let (cdi, cdv) = makeDialPairRow(height: 116, hoverGroup: "claude")
        claudeDialItem = cdi
        claudeDialView = cdv
        cdv.showThird   = true
        cdv.showDivider = true
        appMenu.addItem(cdi)
        appMenu.addItem(makeSpacerRow(height: 4, hoverGroup: "claude"))

        let (cwi, cwv) = makeWarnBannerRow(group: "claude")
        claudeWarningItem = cwi
        claudeWarningView = cwv
        claudeWarningItem.isHidden = true
        appMenu.addItem(cwi)
        appMenu.addItem(makeSpacerRow(height: 4, hoverGroup: "claude"))

        // Single subtle separator between Claude and Codex sections.
        let modelDivider = makeSeparatorRow(height: 8, group: "codex")
        appMenu.addItem(modelDivider)

        // Small top breathing room before Codex header.
        let codexStartSpacer = makeSpacerRow(height: 1, hoverGroup: "codex")
        appMenu.addItem(codexStartSpacer)

        let (cxh, lbCXH) = makeRow(text: "  Codex", color: header, size: 14, bold: true, height: 30, hoverGroup: "codex")
        lbCodexTitle = lbCXH
        styleSubBoxRow(cxh.view, corners: [], group: "codex")
        addSectionHeaderChip(cxh.view, tint: NSColor(calibratedRed: 0.58, green: 0.76, blue: 0.68, alpha: 1.0))
        appMenu.addItem(cxh)
        appMenu.addItem(makeSpacerRow(height: 4, hoverGroup: "codex"))

        let (odi, odv) = makeDialPairRow(height: 116, hoverGroup: "codex")
        codexDialItem = odi
        codexDialView = odv
        appMenu.addItem(odi)
        appMenu.addItem(makeSpacerRow(height: 4, hoverGroup: "codex"))

        let (cwxi, cwxv) = makeWarnBannerRow(group: "codex")
        codexWarningItem = cwxi
        codexWarningView = cwxv
        codexWarningItem.isHidden = true
        appMenu.addItem(cwxi)
        appMenu.addItem(makeSpacerRow(height: 4, hoverGroup: "codex"))

        appMenu.addItem(makeSeparatorRow(height: 8, group: "footer"))

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
            title: "↗ Open Claude Analytics",
            shortcut: "⌘L",
            action: #selector(openClaudeAnalytics),
            keyEquivalent: "l"
        )
        appMenu.addItem(openClaudeItem)

        let (openCodexItem, _) = makeActionRow(
            title: "↗ Open Codex Analytics",
            shortcut: "⌘O",
            action: #selector(openCodexAnalytics),
            keyEquivalent: "o"
        )
        appMenu.addItem(openCodexItem)

        appMenu.addItem(makeSeparatorRow(group: "footer"))

        let (restartItem, _) = makeActionRow(
            title: "↻ Refresh now",
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

    func sectionHoverChanged(group: String, delta: Int) {
        let current = sectionHoverCount[group, default: 0]
        let next = max(0, current + delta)
        sectionHoverCount[group] = next
        let active = next > 0
        let rows = sectionViews[group] ?? []
        let didEnter = (current == 0 && next > 0 && delta > 0)
        let didExit = (current > 0 && next == 0 && delta < 0)
        for row in rows {
            row.wantsLayer = true
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.10)
            if active {
                if let base = baseRowBackgrounds[ObjectIdentifier(row)] {
                    row.layer?.backgroundColor = base
                }
                row.layer?.shadowColor = NSColor.black.withAlphaComponent(0.30).cgColor
                row.layer?.shadowOpacity = 0.22
                row.layer?.shadowRadius = 5
                row.layer?.shadowOffset = CGSize(width: 0, height: -1)
                row.layer?.transform = CATransform3DMakeScale(1.006, 1.006, 1)
            } else {
                if let base = baseRowBackgrounds[ObjectIdentifier(row)] {
                    row.layer?.backgroundColor = base
                } else {
                    row.layer?.backgroundColor = panelTeal.cgColor
                }
                row.layer?.shadowOpacity = 0.0
                row.layer?.transform = CATransform3DIdentity
            }
            CATransaction.commit()
        }
        if didEnter {
            animateSectionBubble(rows)
        } else if didExit {
            settleSection(rows)
        }
        applyHoverDisclosure()
    }

    func animateSectionBubble(_ rows: [NSView]) {
        for row in rows {
            row.wantsLayer = true
            let anim = CAKeyframeAnimation(keyPath: "transform.scale")
            anim.values = [1.0, 1.018, 1.006]
            anim.keyTimes = [0.0, 0.55, 1.0]
            anim.duration = 0.19
            anim.timingFunctions = [
                CAMediaTimingFunction(name: .easeOut),
                CAMediaTimingFunction(name: .easeInEaseOut),
            ]
            row.layer?.add(anim, forKey: "section-bubble")
        }
    }

    func settleSection(_ rows: [NSView]) {
        for row in rows {
            row.wantsLayer = true
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.12)
            row.layer?.transform = CATransform3DIdentity
            CATransaction.commit()
        }
    }

    func applyHoverDisclosure() {
        // Capped state is expressed visually within the dials — no items to show/hide.
    }

    func applyWarningBanner(
        item: NSMenuItem, view: WarnBannerView,
        sessionPct: String, weeklyPct: String,
        sectionName: String, sessionReset: String, weeklyReset: String,
        isRemaining: Bool,
        designPct: String = "—", designReset: String = ""
    ) {
        let sState = meterState(for: sessionPct, isRemaining: isRemaining)
        let wState = meterState(for: weeklyPct,  isRemaining: isRemaining)
        let dState = meterState(for: designPct,  isRemaining: isRemaining)
        let sCritical = sState == .critical || sState == .capped
        let wCritical = wState == .critical || wState == .capped
        let dCritical = dState == .critical || dState == .capped
        guard sCritical || wCritical || dCritical else { item.isHidden = true; return }

        let sUsed = isRemaining ? (100 - (pctInt(sessionPct) ?? 0)) : (pctInt(sessionPct) ?? 0)
        let wUsed = isRemaining ? (100 - (pctInt(weeklyPct)  ?? 0)) : (pctInt(weeklyPct)  ?? 0)
        let dUsed = isRemaining ? (100 - (pctInt(designPct)  ?? 0)) : (pctInt(designPct)  ?? 0)
        let useDesign = dCritical && dUsed >= sUsed && dUsed >= wUsed
        let useWeekly = !useDesign && wCritical && wUsed >= sUsed
        let label     = useDesign ? "Design" : useWeekly ? "weekly" : "session"
        let pct       = useDesign ? designPct : useWeekly ? weeklyPct : sessionPct
        let clock     = useDesign ? weeklyClockPhrase(designReset)
                      : useWeekly ? weeklyClockPhrase(weeklyReset)
                      : sessionClockPhrase(sessionReset, pct: sessionPct)
        let highest   = max(sUsed, wUsed, dCritical ? dUsed : 0)
        let color     = highest >= 100 ? usageCriticalRed : usageHealthyGold
        let suffix    = clock.isEmpty ? "." : ". Resets \(clock)."
        view.update(message: "⚠  \(sectionName) \(label) at \(pct)\(suffix)", color: color)
        item.isHidden = false
    }

    func applySubBoxStyle(top: NSView?, middle: NSView?, bottom: NSView?, group: String?) {
        styleSubBoxRow(top, corners: [.layerMinXMinYCorner, .layerMaxXMinYCorner], group: group)
        styleSubBoxRow(middle, corners: [], group: group)
        styleSubBoxRow(bottom, corners: [.layerMinXMaxYCorner, .layerMaxXMaxYCorner], group: group)
    }

    func addSectionHeaderChip(_ row: NSView?, tint: NSColor) {
        guard let row else { return }
        let chipId = NSUserInterfaceItemIdentifier("section-header-chip")
        if let existing = row.subviews.first(where: { $0.identifier == chipId }) {
            existing.removeFromSuperview()
        }
        let chipX: CGFloat = 14
        let minW: CGFloat = 106
        let maxW: CGFloat = 152
        let textPad: CGFloat = 24
        let yInset: CGFloat = 1

        let (titleWidth, labelFrame): (CGFloat, NSRect) = {
            guard let lbl = row.subviews.first(where: { $0 is NSTextField }) as? NSTextField else {
                return (minW, NSRect(x: chipX, y: 4, width: minW, height: 20))
            }
            return (ceil(lbl.attributedStringValue.size().width), lbl.frame)
        }()
        let chipW = min(maxW, max(minW, titleWidth + textPad))

        let chipH = min(row.bounds.height - 4, labelFrame.height + yInset * 2)
        let chipY = max(2, ((labelFrame.minY + labelFrame.height / 2) - (chipH / 2)).rounded(.toNearestOrAwayFromZero))
        let chip = NSView(frame: NSRect(x: chipX, y: chipY, width: chipW, height: chipH))
        chip.identifier = chipId
        chip.wantsLayer = true
        chip.layer?.cornerRadius = chipH / 2
        chip.layer?.backgroundColor = tint.withAlphaComponent(0.16).cgColor
        chip.layer?.borderWidth = 1
        chip.layer?.borderColor = NSColor(calibratedWhite: 1.0, alpha: 0.16).cgColor
        chip.layer?.shadowColor = tint.withAlphaComponent(0.72).cgColor
        chip.layer?.shadowOpacity = 0.46
        chip.layer?.shadowRadius = 9.0
        chip.layer?.shadowOffset = .zero

        let glowName = "chip-top-highlight"
        chip.layer?.sublayers?.removeAll(where: { $0.name == glowName })
        let highlight = CAShapeLayer()
        highlight.name = glowName
        let inset: CGFloat = 1.5
        let hRect = NSRect(
            x: inset,
            y: chipH / 2 + 1.0,
            width: max(2, chipW - inset * 2),
            height: max(1, chipH / 2 - 2.5)
        )
        highlight.path = CGPath(roundedRect: hRect, cornerWidth: hRect.height / 2, cornerHeight: hRect.height / 2, transform: nil)
        highlight.fillColor = NSColor.white.withAlphaComponent(0.10).cgColor
        chip.layer?.addSublayer(highlight)
        row.addSubview(chip, positioned: .below, relativeTo: row.subviews.first)
    }

    func applySectionOutline(_ rows: [NSView], color: NSColor) {
        let borderName = "section-outline"
        let insetX: CGFloat = 8
        for (idx, row) in rows.enumerated() {
            row.wantsLayer = true
            row.layer?.sublayers?.removeAll(where: { $0.name == borderName })
            let isFirst = idx == 0
            let isLast = idx == rows.count - 1

            let left = CAShapeLayer()
            left.name = borderName
            let lp = CGMutablePath()
            lp.move(to: CGPoint(x: insetX, y: 0))
            lp.addLine(to: CGPoint(x: insetX, y: row.bounds.height))
            left.path = lp
            left.strokeColor = color.cgColor
            left.lineWidth = 1
            row.layer?.addSublayer(left)

            let right = CAShapeLayer()
            right.name = borderName
            let rp = CGMutablePath()
            rp.move(to: CGPoint(x: row.bounds.width - insetX, y: 0))
            rp.addLine(to: CGPoint(x: row.bounds.width - insetX, y: row.bounds.height))
            right.path = rp
            right.strokeColor = color.cgColor
            right.lineWidth = 1
            row.layer?.addSublayer(right)

            if isFirst {
                let top = CAShapeLayer()
                top.name = borderName
                let tp = CGMutablePath()
                tp.move(to: CGPoint(x: insetX, y: row.bounds.height - 0.5))
                tp.addLine(to: CGPoint(x: row.bounds.width - insetX, y: row.bounds.height - 0.5))
                top.path = tp
                top.strokeColor = color.cgColor
                top.lineWidth = 1
                row.layer?.addSublayer(top)
            }

            if isLast {
                let bottom = CAShapeLayer()
                bottom.name = borderName
                let bp = CGMutablePath()
                bp.move(to: CGPoint(x: insetX, y: 0.5))
                bp.addLine(to: CGPoint(x: row.bounds.width - insetX, y: 0.5))
                bottom.path = bp
                bottom.strokeColor = color.cgColor
                bottom.lineWidth = 1
                row.layer?.addSublayer(bottom)
            }
        }
    }

    func styleSubBoxRow(_ row: NSView?, corners: CACornerMask, group: String?) {
        guard let row else { return }
        row.wantsLayer = true
        let rowBG = subBoxColor(for: group)
        row.layer?.backgroundColor = rowBG.cgColor
        baseRowBackgrounds[ObjectIdentifier(row)] = rowBG.cgColor
        row.layer?.cornerRadius = 0
        row.layer?.borderWidth = 0
    }

    func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let btn = statusItem.button {
            btn.title = "CL⚪⚪⚪ CO⚪⚪"
            btn.toolTip = nil
            // Use a smaller proportional font so CL/CO letters are visually narrower than monospaced glyphs.
            btn.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        }
        statusItem.menu = appMenu
    }

    func statusTitleWidth(_ text: String, font: NSFont) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        return (text as NSString).size(withAttributes: attrs).width
    }

    func ensureStatusDotTooltipViews(on button: NSStatusBarButton) {
        if claudeSessionDotTipView == nil {
            let v = StatusDotTooltipView(frame: .zero)
            v.metricKey = "cl_5h"
            v.hoverDelegate = self
            button.addSubview(v)
            claudeSessionDotTipView = v
        }
        if claudeWeeklyDotTipView == nil {
            let v = StatusDotTooltipView(frame: .zero)
            v.metricKey = "cl_weekly"
            v.hoverDelegate = self
            button.addSubview(v)
            claudeWeeklyDotTipView = v
        }
        if claudeDesignDotTipView == nil {
            let v = StatusDotTooltipView(frame: .zero)
            v.metricKey = "cl_design"
            v.hoverDelegate = self
            button.addSubview(v)
            claudeDesignDotTipView = v
        }
        if codexSessionDotTipView == nil {
            let v = StatusDotTooltipView(frame: .zero)
            v.metricKey = "co_5h"
            v.hoverDelegate = self
            button.addSubview(v)
            codexSessionDotTipView = v
        }
        if codexWeeklyDotTipView == nil {
            let v = StatusDotTooltipView(frame: .zero)
            v.metricKey = "co_weekly"
            v.hoverDelegate = self
            button.addSubview(v)
            codexWeeklyDotTipView = v
        }
    }

    func ensureStatusDotPopover() {
        if statusDotPopover != nil { return }

        let content = NSView(frame: NSRect(x: 0, y: 0, width: 160, height: 44))
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor(calibratedWhite: 0.12, alpha: 0.98).cgColor

        let rowH: CGFloat = 22
        let rowW: CGFloat = 146
        let startX: CGFloat = 7

        let cl5hRow  = StatusTooltipRowView(accentColor: usageGreen)
        cl5hRow.frame  = NSRect(x: startX, y: 11, width: rowW, height: rowH)
        let clWRow   = StatusTooltipRowView(accentColor: usageGreen)
        clWRow.frame   = NSRect(x: startX, y: 11, width: rowW, height: rowH)
        let clDesignRow = StatusTooltipRowView(accentColor: usageGreen)
        clDesignRow.frame = NSRect(x: startX, y: 11, width: rowW, height: rowH)
        let co5hRow  = StatusTooltipRowView(accentColor: usageGreen)
        co5hRow.frame  = NSRect(x: startX, y: 11, width: rowW, height: rowH)
        let coWRow   = StatusTooltipRowView(accentColor: usageGreen)
        coWRow.frame   = NSRect(x: startX, y: 11, width: rowW, height: rowH)

        content.addSubview(cl5hRow)
        content.addSubview(clWRow)
        content.addSubview(clDesignRow)
        content.addSubview(co5hRow)
        content.addSubview(coWRow)

        statusDotRows["cl_5h"]     = cl5hRow
        statusDotRows["cl_weekly"] = clWRow
        statusDotRows["cl_design"] = clDesignRow
        statusDotRows["co_5h"]     = co5hRow
        statusDotRows["co_weekly"] = coWRow

        let vc = NSViewController()
        vc.view = content

        let pop = NSPopover()
        pop.behavior = .applicationDefined
        pop.animates = false
        pop.appearance = NSAppearance(named: .darkAqua)
        pop.contentSize = content.frame.size
        pop.contentViewController = vc
        statusDotPopover = pop
    }

    func refreshStatusDotPopoverRows() {
        let activeKey = activeStatusDotKey
        let ordered: [String] = ["cl_5h", "cl_weekly", "cl_design", "co_5h", "co_weekly"]
        for key in ordered {
            guard let row = statusDotRows[key] else { continue }
            if let color = statusDotColors[key] { row.accentColor = color }
            let text = statusDotTexts[key] ?? ""
            row.update(text: text, active: key == activeKey)
        }
    }

    func showStatusDotPopover(dotRect: NSRect, forKey key: String) {
        ensureStatusDotPopover()
        for (k, row) in statusDotRows { row.isHidden = (k != key) }
        refreshStatusDotPopoverRows()
        guard let pop = statusDotPopover, let button = statusItem.button else { return }

        // Resize popover to exactly fit the text for this dot — no fixed width.
        // Use boundingRect (not NSString.size) because ↻ renders via font fallback
        // (Apple Symbols) and comes out wider than SF Pro measures it.
        let text = statusDotTexts[key] ?? ""
        let font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        let attrStr = NSAttributedString(string: text, attributes: [.font: font])
        let measuredW = attrStr.boundingRect(
            with: CGSize(width: 9999, height: 44),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        ).width
        // 26 = startX(7) + labelPad(6) + labelPad(6) + rightMargin(7)
        // +10 safety for font-fallback rounding on Unicode symbols like ↻
        let newW = max(160, ceil(measuredW) + 36)
        if let content = pop.contentViewController?.view {
            content.frame = NSRect(x: 0, y: 0, width: newW, height: 44)
            statusDotRows[key]?.frame = NSRect(x: 7, y: 11, width: newW - 14, height: 22)
            pop.contentSize = content.frame.size
        }

        if pop.isShown { pop.close() }
        pop.show(relativeTo: dotRect, of: button, preferredEdge: .maxY)
    }

    func hideStatusDotPopover() {
        statusDotPopover?.close()
    }

    func setupGlobalMouseMonitor() {
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            DispatchQueue.main.async { self?.handleGlobalMouseMove() }
        }
    }

    func handleGlobalMouseMove() {
        guard let button = statusItem.button, let window = button.window else { return }
        let mouseScreen = NSEvent.mouseLocation
        let buttonScreenFrame = window.convertToScreen(button.convert(button.bounds, to: nil))

        guard buttonScreenFrame.contains(mouseScreen) else {
            guard statusDotPopover?.isShown == true || activeStatusDotKey != nil else { return }
            pendingPopoverHide?.cancel()
            let task = DispatchWorkItem { [weak self] in
                self?.activeStatusDotKey = nil
                self?.hideStatusDotPopover()
            }
            pendingPopoverHide = task
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: task)
            return
        }

        pendingPopoverHide?.cancel()
        pendingPopoverHide = nil

        let mouseInWindow = window.convertFromScreen(NSRect(origin: mouseScreen, size: .zero)).origin
        let mouseInButton = button.convert(mouseInWindow, from: nil)

        let dotViews: [(String, StatusDotTooltipView?)] = [
            ("cl_5h",     claudeSessionDotTipView),
            ("cl_weekly", claudeWeeklyDotTipView),
            ("cl_design", claudeDesignDotTipView),
            ("co_5h",     codexSessionDotTipView),
            ("co_weekly", codexWeeklyDotTipView),
        ]

        for (key, view) in dotViews {
            guard let view = view, view.frame.contains(mouseInButton) else { continue }
            guard activeStatusDotKey != key else { return }
            activeStatusDotKey = key
            showStatusDotPopover(dotRect: view.frame, forKey: key)
            return
        }

        let task = DispatchWorkItem { [weak self] in
            self?.activeStatusDotKey = nil
            self?.hideStatusDotPopover()
        }
        pendingPopoverHide = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: task)
    }

    func statusDotHoverChanged(key: String, entered: Bool, anchor: NSView) {
        // Kept for protocol conformance — hover is driven by globalMouseMonitor now.
    }

    func updateStatusDotTooltips(
        claudeSessionValue: String, claudeSessionReset: String,
        claudeWeeklyValue: String,  claudeWeeklyReset: String,
        claudeDesignValue: String,  claudeDesignReset: String,
        codexSessionValue: String,  codexSessionReset: String,
        codexWeeklyValue: String,   codexWeeklyReset: String,
        cSDot: String, cWDot: String, cDWDot: String, oSDot: String, oWDot: String
    ) {
        guard let button = statusItem.button else { return }
        ensureStatusDotTooltipViews(on: button)

        func tip(_ label: String, _ val: String, _ reset: String) -> String {
            let r = reset.trimmingCharacters(in: .whitespacesAndNewlines)
            return r.isEmpty ? "\(label) · \(val)" : "\(label) · \(val) · ↻ \(r)"
        }
        statusDotTexts["cl_5h"]     = tip("Claude Current",    claudeSessionValue, shortCountdown(claudeSessionReset))
        statusDotTexts["cl_weekly"] = tip("Claude All Models",  claudeWeeklyValue,  weeklyClockPhrase(claudeWeeklyReset))
        statusDotTexts["cl_design"] = tip("Claude Design",      claudeDesignValue,  weeklyClockPhrase(claudeDesignReset))
        statusDotTexts["co_5h"]     = tip("Codex Current",      codexSessionValue,  shortCountdown(codexSessionReset))
        statusDotTexts["co_weekly"] = tip("Codex Weekly",       codexWeeklyValue,   weeklyClockPhrase(codexWeeklyReset))
        statusDotColors["cl_5h"]     = barColorForValue(claudeSessionValue, isRemaining: showRemaining)
        statusDotColors["cl_weekly"] = barColorForValue(claudeWeeklyValue,  isRemaining: showRemaining)
        statusDotColors["cl_design"] = barColorForValue(claudeDesignValue,  isRemaining: showRemaining)
        statusDotColors["co_5h"]     = barColorForValue(codexSessionValue,  isRemaining: showRemaining)
        statusDotColors["co_weekly"] = barColorForValue(codexWeeklyValue,   isRemaining: showRemaining)
        refreshStatusDotPopoverRows()

        let font = button.font ?? NSFont.systemFont(ofSize: 11, weight: .regular)
        let full = "CL\(cSDot)\(cWDot)\(cDWDot) CO\(oSDot)\(oWDot)"
        let totalW = statusTitleWidth(full, font: font)
        let startX = max(0, floor((button.bounds.width - totalW) / 2.0))
        let fullHeight = button.bounds.height

        let cSStart  = startX + statusTitleWidth("CL", font: font)
        let cSWidth  = statusTitleWidth(cSDot, font: font)
        let cWStart  = startX + statusTitleWidth("CL\(cSDot)", font: font)
        let cWWidth  = statusTitleWidth(cWDot, font: font)
        let cDWStart = startX + statusTitleWidth("CL\(cSDot)\(cWDot)", font: font)
        let cDWWidth = statusTitleWidth(cDWDot, font: font)
        let oSStart  = startX + statusTitleWidth("CL\(cSDot)\(cWDot)\(cDWDot) CO", font: font)
        let oSWidth  = statusTitleWidth(oSDot, font: font)
        let oWStart  = startX + statusTitleWidth("CL\(cSDot)\(cWDot)\(cDWDot) CO\(oSDot)", font: font)
        let oWWidth  = statusTitleWidth(oWDot, font: font)

        let minHitW: CGFloat = 14
        let pad: CGFloat = 4
        claudeSessionDotTipView?.frame = NSRect(x: cSStart  - pad, y: 0, width: max(minHitW, cSWidth  + pad * 2), height: fullHeight)
        claudeWeeklyDotTipView?.frame  = NSRect(x: cWStart  - pad, y: 0, width: max(minHitW, cWWidth  + pad * 2), height: fullHeight)
        claudeDesignDotTipView?.frame  = NSRect(x: cDWStart - pad, y: 0, width: max(minHitW, cDWWidth + pad * 2), height: fullHeight)
        codexSessionDotTipView?.frame  = NSRect(x: oSStart  - pad, y: 0, width: max(minHitW, oSWidth  + pad * 2), height: fullHeight)
        codexWeeklyDotTipView?.frame   = NSRect(x: oWStart  - pad, y: 0, width: max(minHitW, oWWidth  + pad * 2), height: fullHeight)
        claudeSessionDotTipView?.toolTip = nil
        claudeWeeklyDotTipView?.toolTip  = nil
        claudeDesignDotTipView?.toolTip  = nil
        codexSessionDotTipView?.toolTip  = nil
        codexWeeklyDotTipView?.toolTip   = nil
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
                self.setLabel(self.lbHeader, self.twoCol("● Claude/Codex Usage Error", "updated --:--", total: self.columns), color: self.usageRed, size: 13, bold: true, mono: true)
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
        let path = sharedDataPath
        let isRunning = pythonProcess?.isRunning ?? false
        let staleThreshold: TimeInterval = 420 // must be greater than normal Python 5-min refresh

        if let attrs = try? FileManager.default.attributesOfItem(atPath: path),
           let mtime = attrs[.modificationDate] as? Date {
            let age = Date().timeIntervalSince(mtime)
            if age > staleThreshold || !isRunning {
                pythonProcess?.terminate()
                pythonProcess = nil
                lastDataMTime = nil
                launchPython()
            }
            return
        }

        if !isRunning {
            launchPython()
        }
    }

    func loadData() {
        let path = sharedDataPath
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let mtime = attrs[.modificationDate] as? Date
        else { return }

        if let last = lastDataMTime, mtime <= last {
            return
        }
        lastDataMTime = mtime

        let url = URL(fileURLWithPath: path)
        guard let data = try? Data(contentsOf: url) else { return }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            let msg = "[\(Date())] loadData: JSON parse failed for \(path)\n"
            if let logData = msg.data(using: .utf8) {
                let logURL = URL(fileURLWithPath: "/tmp/claude-tracker-fetcher.log")
                if let handle = try? FileHandle(forWritingTo: logURL) {
                    handle.seekToEndOfFile()
                    handle.write(logData)
                    handle.closeFile()
                } else {
                    try? logData.write(to: logURL, options: .atomic)
                }
            }
            DispatchQueue.main.async {
                self.setLabel(self.lbHeader, self.twoCol("● Data parse error", "check /tmp/claude-tracker-fetcher.log", total: self.columns), color: self.usageRed, size: 13, bold: true, mono: true)
            }
            return
        }
        lastPayload = json
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

    func setMeterTopLabel(
        _ lbl: NSTextField,
        title: String,
        subtitle: String,
        pct: String,
        pctColor: NSColor,
        warning: Bool = false,
        chip: String? = nil,
        chipTooltip: String? = nil
    ) {
        let titleText = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let subtitleText = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let leftBase = subtitleText.isEmpty ? "\(titleText)" : "\(titleText) · \(subtitleText)"
        let leftTextRaw = warning ? "⚠ \(leftBase)" : leftBase
        let rightText = chip == nil ? pct : "\(pct)  \(chip!)"
        let text = "  \(leftTextRaw)\t\(rightText)"
        let font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
        let tabRight = (rowWidth - barInsetX) - textLeftX
        let paragraph = NSMutableParagraphStyle()
        paragraph.tabStops = [NSTextTab(textAlignment: .right, location: tabRight, options: [:])]
        paragraph.defaultTabInterval = tabRight
        let attr = NSMutableAttributedString(
            string: text,
            attributes: [
                .foregroundColor: dimText,
                .font: font,
                .paragraphStyle: paragraph,
            ]
        )
        if let titleRange = text.range(of: titleText) {
            attr.addAttribute(.foregroundColor, value: headerText.withAlphaComponent(0.92), range: NSRange(titleRange, in: text))
            if titleText.uppercased() == "5H" || titleText.uppercased() == "CURRENT" {
                let ns = NSRange(titleRange, in: text)
                attr.addAttribute(.font, value: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .bold), range: ns)
                attr.addAttribute(.foregroundColor, value: headerText.withAlphaComponent(0.99), range: ns)
            }
        }
        if warning, let warningRange = text.range(of: "⚠") {
            let ns = NSRange(warningRange, in: text)
            attr.addAttribute(.foregroundColor, value: usageCriticalRed, range: ns)
            attr.addAttribute(.font, value: NSFont.systemFont(ofSize: 10, weight: .semibold), range: ns)
        }
        if !subtitleText.isEmpty, let subtitleRange = text.range(of: subtitleText) {
            attr.addAttribute(.foregroundColor, value: dimText.withAlphaComponent(0.65), range: NSRange(subtitleRange, in: text))
        }
        if let range = text.range(of: pct, options: .backwards) {
            let nsRange = NSRange(range, in: text)
            var pctDisplayColor = pctColor
            if meterState(for: pct, isRemaining: showRemaining) == .healthy {
                // Keep healthy percentages clearly readable on dark backgrounds.
                pctDisplayColor = NSColor(calibratedRed: 0.48, green: 0.89, blue: 0.66, alpha: 1.0)
            }
            attr.addAttribute(.foregroundColor, value: pctDisplayColor, range: nsRange)
            attr.addAttribute(.font, value: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .heavy), range: nsRange)
        }
        if let chip, let chipRange = text.range(of: chip, options: .backwards) {
            let nsChipRange = NSRange(chipRange, in: text)
            attr.addAttribute(.foregroundColor, value: chipTextColor(chip), range: nsChipRange)
            attr.addAttribute(.backgroundColor, value: chipBackgroundColor(chip), range: nsChipRange)
            attr.addAttribute(.font, value: NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .bold), range: nsChipRange)
        }
        lbl.attributedStringValue = attr
        lbl.toolTip = chipTooltip
    }

    func setSectionTitleLabel(_ lbl: NSTextField, name: String, plan: String, nameColor: NSColor, summaryDotColor: NSColor? = nil) {
        let cleanPlan = plan.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let text = "  ● \(name) · \(cleanPlan)  "
        let attr = NSMutableAttributedString(
            string: text,
            attributes: [
                .foregroundColor: nameColor,
                .font: NSFont.systemFont(ofSize: 12.0, weight: .semibold),
                .baselineOffset: -1.2,
            ]
        )
        if let dotRange = text.range(of: "●"), let summaryDotColor {
            attr.addAttribute(.foregroundColor, value: summaryDotColor, range: NSRange(dotRange, in: text))
        }
        if let sepRange = text.range(of: "·") {
            attr.addAttribute(.foregroundColor, value: dimText.withAlphaComponent(0.55), range: NSRange(sepRange, in: text))
        }
        if let planRange = text.range(of: cleanPlan, options: .backwards) {
            let ns = NSRange(planRange, in: text)
            attr.addAttribute(.font, value: NSFont.systemFont(ofSize: 11.2, weight: .semibold), range: ns)
            attr.addAttribute(.foregroundColor, value: dimText.withAlphaComponent(0.90), range: ns)
        }
        lbl.attributedStringValue = attr
    }

    func setTwoColLabel(
        _ lbl: NSTextField,
        left: String,
        right: String,
        color: NSColor,
        size: CGFloat = 11,
        bold: Bool = false,
        mono: Bool = true
    ) {
        let font: NSFont
        if mono {
            font = NSFont.monospacedDigitSystemFont(ofSize: size, weight: bold ? .semibold : .regular)
        } else {
            font = bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size)
        }
        let cleanLeft = left.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanRight = right.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = "  \(cleanLeft)\t\(cleanRight)"
        let tabRight = (rowWidth - barInsetX) - textLeftX
        let paragraph = NSMutableParagraphStyle()
        paragraph.tabStops = [NSTextTab(textAlignment: .right, location: tabRight, options: [:])]
        paragraph.defaultTabInterval = tabRight
        lbl.attributedStringValue = NSAttributedString(
            string: text,
            attributes: [
                .foregroundColor: color,
                .font: font,
                .paragraphStyle: paragraph,
            ]
        )
    }

    func chipBackgroundColor(_ chip: String) -> NSColor {
        switch chip {
        case "CURRENT":
            return NSColor(calibratedRed: 0.26, green: 0.34, blue: 0.47, alpha: 0.92)
        case "WEEKLY":
            return NSColor(calibratedRed: 0.33, green: 0.31, blue: 0.50, alpha: 0.92)
        case "AT RISK", "CAPPED":
            return NSColor(calibratedRed: 0.38, green: 0.18, blue: 0.20, alpha: 0.88)
        case "WATCH":
            return NSColor(calibratedRed: 0.43, green: 0.33, blue: 0.10, alpha: 0.90)
        default:
            return NSColor(calibratedRed: 0.15, green: 0.35, blue: 0.24, alpha: 0.88)
        }
    }

    func chipTextColor(_ chip: String) -> NSColor {
        switch chip {
        case "CURRENT", "WEEKLY":
            return NSColor(calibratedRed: 0.93, green: 0.95, blue: 0.99, alpha: 1.0)
        case "AT RISK", "CAPPED":
            return NSColor(calibratedRed: 1.00, green: 0.76, blue: 0.76, alpha: 1.0)
        case "WATCH":
            return NSColor(calibratedRed: 1.00, green: 0.88, blue: 0.53, alpha: 1.0)
        default:
            return NSColor(calibratedRed: 0.66, green: 0.95, blue: 0.70, alpha: 1.0)
        }
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
        switch meterState(for: pct, isRemaining: false) {
        case .healthy:
            return usageGreen
        case .watch:
            return usageHealthyGold
        case .critical:
            return usageCriticalRed
        case .capped:
            return usageCriticalRed
        case .unknown:
            return .secondaryLabelColor
        }
    }

    func barColorForValue(_ pct: String, isRemaining: Bool) -> NSColor {
        switch meterState(for: pct, isRemaining: isRemaining) {
        case .healthy:
            return usageGreen
        case .watch:
            return usageHealthyGold
        case .critical:
            return usageHealthyGold
        case .capped:
            return usageCriticalRed
        case .unknown:
            return .secondaryLabelColor
        }
    }

    enum MeterState {
        case healthy
        case watch
        case critical
        case capped
        case unknown
    }

    func meterState(for pct: String, isRemaining: Bool) -> MeterState {
        guard let n = pctInt(pct) else { return .unknown }
        let effective = isRemaining ? (100 - n) : n
        if effective >= 100 { return .capped }
        if effective >= 80  { return .critical }
        if effective >= 50  { return .watch }
        return .healthy
    }

    func isCriticalState(_ pct: String, isRemaining: Bool) -> Bool {
        meterState(for: pct, isRemaining: isRemaining) == .critical
    }

    func isCappedState(_ pct: String, isRemaining: Bool) -> Bool {
        meterState(for: pct, isRemaining: isRemaining) == .capped
    }

    func colorDot(_ pct: String) -> String {
        switch meterState(for: pct, isRemaining: false) {
        case .capped:
            return "🔴"
        case .watch:
            return "🟡"
        case .critical:
            return "🔴"
        case .healthy:
            return "🟢"
        case .unknown:
            return "⚪"
        }
    }

    func updateProgressBar(_ view: ProgressBarMenuRowView, pct: String, color: NSColor, projectedPct: Int?) {
        let used = Double(pctInt(pct) ?? 0) / 100.0
        view.fillFraction = min(max(used, 0.0), 1.0)
        view.fillColor = color
        if let projectedPct {
            view.tickFraction = min(max(Double(projectedPct) / 100.0, 0.0), 1.0)
        } else {
            view.tickFraction = nil
        }
    }

    func setShadowProgress(_ view: ProgressBarMenuRowView, pct: String, color: NSColor) {
        let shadow = Double(pctInt(pct) ?? 0) / 100.0
        view.secondaryFraction = min(max(shadow, 0.0), 1.0)
        view.secondaryColor = color.withAlphaComponent(0.50)
    }

    func colorDotForValue(_ pct: String, isRemaining: Bool) -> String {
        switch meterState(for: pct, isRemaining: isRemaining) {
        case .capped:
            return "🔴"
        case .watch:
            return "🟡"
        case .critical:
            return "🔴"
        case .healthy:
            return "🟢"
        case .unknown:
            return "⚪"
        }
    }

    func stateLabel(_ pct: String, isRemaining: Bool, isCapped: Bool = false) -> String {
        if isCapped { return "CAPPED" }
        switch meterState(for: pct, isRemaining: isRemaining) {
        case .healthy:
            return "ON TRACK"
        case .watch:
            return "WATCH"
        case .critical:
            return "AT RISK"
        case .capped:
            return "CAPPED"
        case .unknown:
            return "IDLE"
        }
    }

    func stateTooltip(_ label: String) -> String {
        switch label {
        case "IDLE":
            return "No usage in this window yet."
        case "ON TRACK":
            return "Usage is within comfortable range."
        case "WATCH":
            return "Usage is elevated. Monitor this window."
        case "AT RISK":
            return "High usage. You may hit the limit soon."
        case "CAPPED":
            return "Window limit reached. Access resumes at reset."
        default:
            return "Current usage state."
        }
    }

    func stateSeverity(_ label: String) -> Int {
        switch label {
        case "CAPPED", "AT RISK":
            return 3
        case "WATCH":
            return 2
        case "ON TRACK":
            return 1
        default:
            return 0
        }
    }

    func stateColor(_ label: String) -> NSColor {
        switch label {
        case "CAPPED", "AT RISK":
            return usageRed
        case "WATCH":
            return usageAmber
        default:
            return usageGreen
        }
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

        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        if let match = shortClockRegex.firstMatch(in: value, options: [], range: range),
           let swiftRange = Range(match.range, in: value) {
            return String(value[swiftRange]).replacingOccurrences(of: " ", with: "")
        }

        let parts = value.split(separator: " ")
        if let last = parts.last {
            return String(last)
        }
        return value
    }

    func compactClock(_ value: String) -> String {
        let c = shortClock(value)
        if c == "--:--:--" {
            return currentClockCompact()
        }

        if let first = c.split(separator: " ").first {
            let token = String(first)
            let comps = token.split(separator: ":")
            if comps.count >= 2 {
                return "\(comps[0]):\(comps[1])"
            }
        }
        return currentClockCompact()
    }

    func currentClockCompact() -> String {
        let raw = uiClockFormatter.string(from: Date())
        let range = NSRange(raw.startIndex..<raw.endIndex, in: raw)
        if let m = shortHmRegex.firstMatch(in: raw, options: [], range: range),
           let r = Range(m.range, in: raw) {
            return String(raw[r])
        }
        return "--:--"
    }

    func headerClockDisplay(_ compact: String) -> String {
        let t = compact.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty || t == "--:--" {
            return uiClockFormatter.string(from: Date())
        }
        let parser24 = DateFormatter()
        parser24.locale = .autoupdatingCurrent
        parser24.dateFormat = "H:mm"
        if let d = parser24.date(from: t) {
            return uiClockFormatter.string(from: d)
        }
        return t
    }

    func countdownSeconds(_ value: String) -> Int? {
        if value == "—" || value.isEmpty { return nil }
        let d = extractUnit(value, unit: "d")
        let h = extractUnit(value, unit: "h")
        let m = extractUnit(value, unit: "m")
        if d == nil && h == nil && m == nil { return nil }
        return (d ?? 0) * 86400 + (h ?? 0) * 3600 + (m ?? 0) * 60
    }

    func extractUnit(_ text: String, unit: String) -> Int? {
        guard let unitChar = unit.first, let idx = text.firstIndex(of: unitChar) else { return nil }
        var i = idx
        var digits: [Character] = []
        while i > text.startIndex {
            let prev = text.index(before: i)
            let ch = text[prev]
            guard ch.isNumber else { break }
            digits.append(ch)
            i = prev
        }
        guard !digits.isEmpty else { return nil }
        return Int(String(digits.reversed()))
    }

    func unlockClock(from sessionReset: String) -> String? {
        let countdown = shortCountdown(sessionReset)
        guard let secs = countdownSeconds(countdown), secs > 0 else { return nil }
        let unlockDate = Date().addingTimeInterval(TimeInterval(secs))
        return formattedClock(unlockDate)
    }

    func setCappedStrip(_ lbl: NSTextField, sessionReset: String) {
        let countdown = shortCountdown(sessionReset)
        let right = (countdown == "—") ? "↻ soon" : "↻ \(countdown)"
        let left = "↻ " + (unlockClock(from: sessionReset) ?? "soon")
        setTwoColLabel(lbl, left: left, right: right, color: headerText, size: 12, bold: true, mono: true)
    }

    func setWeeklyCappedLine(_ lbl: NSTextField, weeklyReset: String) {
        let left = weeklyCountdownPhrase(weeklyReset)
        let right = weeklyClockPhrase(weeklyReset)
        setTwoColLabel(lbl, left: left, right: right, color: headerText, size: 11, bold: true, mono: true)
    }

    func shortCountdown(_ reset: String) -> String {
        if reset.contains("Resets in") {
            var compact = reset
                .replacingOccurrences(of: "Resets in ", with: "")
                .replacingOccurrences(of: "Resets in, ", with: "")
                .replacingOccurrences(of: ",", with: " ")
            let replacements: [(String, String)] = [
                ("hours", "h"),
                ("hour", "h"),
                ("hrs", "h"),
                ("hr", "h"),
                (" hours", "h"),
                (" hour", "h"),
                (" hrs", "h"),
                (" hr", "h"),
                ("minutes", "m"),
                ("minute", "m"),
                ("mins", "m"),
                ("min", "m"),
                (" minutes", "m"),
                (" minute", "m"),
                (" mins", "m"),
                (" min", "m"),
            ]
            for (from, to) in replacements {
                compact = compact.replacingOccurrences(of: from, with: to, options: [.caseInsensitive], range: nil)
            }
            compact = compact.replacingOccurrences(of: "  ", with: " ")
            return compact.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if reset == "Resetting soon" {
            return "soon"
        }
        if reset.contains("Resets ") {
            return reset.replacingOccurrences(of: "Resets ", with: "")
        }
        return "—"
    }

    func sessionCountdownPhrase(_ reset: String, pct: String? = nil) -> String {
        if let pct, (pctInt(pct) ?? -1) == 0 {
            let c = shortCountdown(reset)
            if c == "—" {
                return "↻ starts on first call"
            }
        }
        let c = shortCountdown(reset)
        if c == "—" { return "↻ —" }
        if c == "soon" { return "↻ soon" }
        return "↻ \(c)"
    }

    func sessionClockPhrase(_ reset: String, pct: String? = nil) -> String {
        if let pct, (pctInt(pct) ?? -1) == 0 {
            let c = shortCountdown(reset)
            if c == "—" {
                return ""
            }
        }
        guard let clock = unlockClock(from: reset) else { return "" }
        return "at \(clock)"
    }

    func weeklyCountdownPhrase(_ reset: String) -> String {
        if let hrs = hoursUntilReset(reset) {
            let totalMinutes = max(0, Int((hrs * 60.0).rounded()))
            let days = totalMinutes / (24 * 60)
            let remMinsAfterDays = totalMinutes % (24 * 60)
            let hours = remMinsAfterDays / 60
            if days > 0 {
                return "↻ \(days)d \(hours)h"
            }
            if hours > 0 {
                return "↻ \(hours)h"
            }
            return "↻ <1h"
        }
        let c = shortCountdown(reset)
        if c == "—" { return "↻ —" }
        if c == "soon" { return "↻ soon" }
        return "↻ \(c)"
    }

    func weeklyClockPhrase(_ reset: String) -> String {
        if let target = resetDate(from: reset) {
            let day = shortDayFormatter.string(from: target)
            let time = formattedClock(target)
            return "\(day) \(time)"
        }
        return ""
    }

    func weeklyResumePhrase(_ reset: String) -> String {
        if let target = resetDate(from: reset) {
            let day = shortDayFormatter.string(from: target)
            let time = formattedClock(target)
            return "↻ \(day), \(time)"
        }
        return "↻ soon"
    }

    func normalizedClockToken(_ token: String, ampm: String) -> String {
        let composed = "\(token) \(ampm)"
        guard let date = parser12HourFormatter.date(from: composed) else {
            return "\(token) \(ampm)"
        }
        return formattedClock(date)
    }

    func formattedClock(_ date: Date) -> String {
        return uiClockFormatter.string(from: date)
    }

    func setHeaderLabel(dot: String, isLive: Bool, title: String, refreshText: String, dotColor: NSColor? = nil) {
        // title is expected to be "Claude & Codex — Usage"; split at " —" for hierarchy
        let dashSuffix = " — Usage"
        let mainTitle  = title.hasSuffix(dashSuffix)
            ? String(title.dropLast(dashSuffix.count))
            : title
        let subTitle   = title.hasSuffix(dashSuffix) ? dashSuffix : ""
        let text = "  \(dot) \(mainTitle)\(subTitle)\t\(refreshText)"

        let tabRight = (rowWidth - barInsetX) - textLeftX
        let paragraph = NSMutableParagraphStyle()
        paragraph.tabStops = [NSTextTab(textAlignment: .right, location: tabRight, options: [:])]
        paragraph.defaultTabInterval = tabRight
        let attr = NSMutableAttributedString(
            string: text,
            attributes: [
                .foregroundColor: headerText,
                .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                .paragraphStyle: paragraph,
            ]
        )
        // Dot — colored and glowing
        if let dotRange = attr.string.range(of: dot) {
            let ns = NSRange(dotRange, in: attr.string)
            let liveColor = dotColor ?? NSColor(calibratedRed: 0.58, green: 0.90, blue: 0.62, alpha: 1.0)
            let c = isLive ? liveColor : NSColor(calibratedWhite: 1.0, alpha: 0.80)
            attr.addAttribute(.foregroundColor, value: c, range: ns)
            let glow = NSShadow()
            glow.shadowColor = c.withAlphaComponent(isLive ? 0.78 : 0.30)
            glow.shadowBlurRadius = isLive ? 10.0 : 3.0
            glow.shadowOffset = .zero
            attr.addAttribute(.shadow, value: glow, range: ns)
        }
        // "— Usage" suffix — slightly dimmer but readable
        if !subTitle.isEmpty, let subRange = attr.string.range(of: subTitle) {
            let ns = NSRange(subRange, in: attr.string)
            attr.addAttribute(.foregroundColor, value: headerText.withAlphaComponent(0.88), range: ns)
            attr.addAttribute(.font, value: NSFont.systemFont(ofSize: 12, weight: .regular), range: ns)
        }
        // "updated X:XX PM" — secondary but readable
        if let rightRange = attr.string.range(of: refreshText, options: .backwards) {
            let ns = NSRange(rightRange, in: attr.string)
            attr.addAttribute(.foregroundColor, value: headerText.withAlphaComponent(0.92), range: ns)
            attr.addAttribute(.font, value: NSFont.monospacedDigitSystemFont(ofSize: 11.5, weight: .regular), range: ns)
        }
        lbHeader.attributedStringValue = attr
    }

    func hoursUntilReset(_ reset: String) -> Double? {
        if reset.hasPrefix("Resets in ") {
            let c = shortCountdown(reset)
            if c == "soon" { return 0.0 }
            guard let secs = countdownSeconds(c) else { return nil }
            return Double(secs) / 3600.0
        }
        if reset.hasPrefix("Resets ") {
            let raw = reset.replacingOccurrences(of: "Resets ", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            let parts = raw.split(separator: " ")
            if parts.count >= 3 {
                let dayToken = String(parts[0])
                let timeToken = String(parts[1])
                let ampm = String(parts[2]).uppercased()
                let dayMap: [String: Int] = [
                    "Sun": 1, "Mon": 2, "Tue": 3, "Wed": 4, "Thu": 5, "Fri": 6, "Sat": 7,
                ]
                guard let targetWeekday = dayMap[dayToken] else { return nil }
                let hm = timeToken.split(separator: ":")
                guard hm.count == 2, let hRaw = Int(hm[0]), let mRaw = Int(hm[1]) else { return nil }
                var hour = hRaw % 12
                if ampm == "PM" { hour += 12 }
                let minute = mRaw
                let cal = Calendar.autoupdatingCurrent
                let now = Date()
                for delta in 0 ... 7 {
                    guard let d = cal.date(byAdding: .day, value: delta, to: now),
                          let candidate = cal.date(bySettingHour: hour, minute: minute, second: 0, of: d)
                    else { continue }
                    if cal.component(.weekday, from: candidate) == targetWeekday && candidate > now {
                        return candidate.timeIntervalSince(now) / 3600.0
                    }
                }
            }
        }
        return nil
    }

    func resetDate(from reset: String) -> Date? {
        if let hrs = hoursUntilReset(reset) {
            return Date().addingTimeInterval(max(0.0, hrs) * 3600.0)
        }
        return nil
    }

    func normalizedPlanLabel(_ raw: String, fallback: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return t.isEmpty || t == "—" ? fallback : t
    }

    func meterStateShortLabel(_ pct: String, isRemaining: Bool) -> String {
        switch meterState(for: pct, isRemaining: isRemaining) {
        case .healthy:
            return "Healthy"
        case .watch:
            return "Gold"
        case .critical:
            return "Critical"
        case .capped:
            return "Capped"
        case .unknown:
            return "Unknown"
        }
    }

    func twoCol(_ left: String, _ right: String, total: Int = 58) -> String {
        let l = left
        let r = right
        let spaceCount = max(2, total - l.count - r.count)
        return "  " + l + String(repeating: " ", count: spaceCount) + r
    }

    func updateUI(_ payload: [String: Any]) {
        let claude = usageBlock(from: payload, key: "claude", fallbackToRoot: true)
        let codex = usageBlock(from: payload, key: "codex")

        let cSReset  = stringValue(claude["session_reset"])
        let cWReset  = stringValue(claude["weekly_reset"])
        let cDWReset = stringValue(claude["design_weekly_reset"])
        let cDWPct   = stringValue(claude["design_weekly_pct"])
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

        let cSView  = showRemaining ? cSession.remaining : cSession.used
        let cWView  = showRemaining ? cWeekly.remaining  : cWeekly.used
        let cDWView = showRemaining
            ? (cDWPct == "—" ? "—" : "\(max(0, 100 - (pctInt(cDWPct) ?? 0)))%")
            : cDWPct
        let oSView  = showRemaining ? oSession.remaining : oSession.used
        let oWView  = showRemaining ? oWeekly.remaining  : oWeekly.used

        let claudeWeeklyCapped = isCappedState(cWView, isRemaining: showRemaining)
        let codexWeeklyCapped = isCappedState(oWView, isRemaining: showRemaining)
        claudeWeeklyIsCapped = claudeWeeklyCapped
        codexWeeklyIsCapped = codexWeeklyCapped
        let cSEffectiveView = claudeWeeklyCapped ? (showRemaining ? "0%" : "100%") : cSView
        let oSEffectiveView = codexWeeklyCapped ? (showRemaining ? "0%" : "100%") : oSView

        let cSDot  = cSEffectiveView != "—" ? colorDotForValue(cSEffectiveView, isRemaining: showRemaining) : "⚪"
        let cWDot  = cWView  != "—" ? colorDotForValue(cWView,  isRemaining: showRemaining) : "⚪"
        let cDWDot = cDWView != "—" ? colorDotForValue(cDWView, isRemaining: showRemaining) : "⚪"
        let oSDot  = oSEffectiveView != "—" ? colorDotForValue(oSEffectiveView, isRemaining: showRemaining) : "⚪"
        let oWDot  = oWView  != "—" ? colorDotForValue(oWView,  isRemaining: showRemaining) : "⚪"

        pulseOn.toggle()
        let isLive = (cStatus == "Live") || (oStatus == "Live")
        statusItem.button?.title = "CL\(cSDot)\(cWDot)\(cDWDot) CO\(oSDot)\(oWDot)"
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.updateStatusDotTooltips(
                claudeSessionValue: cSEffectiveView, claudeSessionReset: cSReset,
                claudeWeeklyValue:  cWView,           claudeWeeklyReset:  cWReset,
                claudeDesignValue:  cDWView,           claudeDesignReset:  cDWReset,
                codexSessionValue:  oSEffectiveView,  codexSessionReset:  oSReset,
                codexWeeklyValue:   oWView,            codexWeeklyReset:   oWReset,
                cSDot: cSDot,
                cWDot: cWDot,
                cDWDot: cDWDot,
                oSDot: oSDot,
                oWDot: oWDot
            )
        }
        let dot = "●"
        let refreshedClock = compactClock(updated).trimmingCharacters(in: .whitespacesAndNewlines)
        let refreshText = "↻ " + headerClockDisplay(refreshedClock)
        let maxUsed = [cSEffectiveView, cWView, cDWView, oSEffectiveView, oWView].compactMap { pctInt($0) }.map { showRemaining ? (100 - $0) : $0 }.max() ?? 0
        let worstDotColor: NSColor = maxUsed >= 100 ? usageCriticalRed : maxUsed >= 50 ? usageHealthyGold : NSColor(calibratedRed: 0.58, green: 0.90, blue: 0.62, alpha: 1.0)
        setHeaderLabel(dot: dot, isLive: isLive, title: "Claude & Codex — Usage", refreshText: refreshText, dotColor: worstDotColor)
        let claudeCapped = isCappedState(cSEffectiveView, isRemaining: showRemaining)
        let codexCapped = isCappedState(oSEffectiveView, isRemaining: showRemaining)
        claudeIsCapped = claudeCapped
        codexIsCapped = codexCapped

        setSectionTitleLabel(lbClaudeTitle, name: "Claude", plan: normalizedPlanLabel(cPlanRaw, fallback: "PRO"), nameColor: headerText, summaryDotColor: claudeHeaderTint)
        setSectionTitleLabel(lbCodexTitle, name: "Codex", plan: normalizedPlanLabel(oPlanRaw, fallback: "PLUS"), nameColor: headerText, summaryDotColor: codexHeaderTint)

        claudeDialView.leftFraction  = CGFloat(pctInt(cSEffectiveView) ?? 0) / 100.0
        claudeDialView.leftColor     = barColorForValue(cSEffectiveView, isRemaining: showRemaining)
        claudeDialView.leftPct       = cSEffectiveView
        claudeDialView.leftLabel     = "Current"
        claudeDialView.leftWarning   = isCriticalState(cSEffectiveView, isRemaining: showRemaining)
        claudeDialView.leftGlow      = claudeCapped ? 0.20 : 1.0
        claudeDialView.leftReset     = claudeWeeklyCapped
            ? shortCountdown(cWReset) + " · " + weeklyClockPhrase(cWReset)
            : sessionCountdownPhrase(cSReset, pct: cSEffectiveView) + " · " + sessionClockPhrase(cSReset, pct: cSEffectiveView)

        claudeDialView.rightFraction = CGFloat(pctInt(cWView) ?? 0) / 100.0
        claudeDialView.rightColor    = barColorForValue(cWView, isRemaining: showRemaining)
        claudeDialView.rightPct      = cWView
        claudeDialView.rightLabel    = "All Models"
        claudeDialView.rightSublabel = "Weekly"
        claudeDialView.rightWarning  = isCriticalState(cWView, isRemaining: showRemaining)
        claudeDialView.rightGlow     = claudeWeeklyCapped ? 0.20 : 1.0
        claudeDialView.rightReset    = weeklyCountdownPhrase(cWReset) + " · " + weeklyClockPhrase(cWReset)

        // Design Weekly (seven_day_omelette)
        claudeDialView.thirdFraction = CGFloat(pctInt(cDWView) ?? 0) / 100.0
        claudeDialView.thirdColor    = barColorForValue(cDWView, isRemaining: showRemaining)
        claudeDialView.thirdPct      = cDWView
        claudeDialView.thirdLabel    = "Design"
        claudeDialView.thirdSublabel = "Weekly"
        claudeDialView.thirdWarning  = isCriticalState(cDWView, isRemaining: showRemaining)
        claudeDialView.thirdGlow     = cDWView == "—" ? 0.0 : 1.0

        codexDialView.leftFraction   = CGFloat(pctInt(oSEffectiveView) ?? 0) / 100.0
        codexDialView.leftColor      = barColorForValue(oSEffectiveView, isRemaining: showRemaining)
        codexDialView.leftPct        = oSEffectiveView
        codexDialView.leftLabel      = "Current"
        codexDialView.leftWarning    = isCriticalState(oSEffectiveView, isRemaining: showRemaining)
        codexDialView.leftGlow       = codexCapped ? 0.20 : 1.0
        codexDialView.leftReset      = codexWeeklyCapped
            ? shortCountdown(oWReset) + " · " + weeklyClockPhrase(oWReset)
            : sessionCountdownPhrase(oSReset, pct: oSEffectiveView) + " · " + sessionClockPhrase(oSReset, pct: oSEffectiveView)

        codexDialView.rightFraction  = CGFloat(pctInt(oWView) ?? 0) / 100.0
        codexDialView.rightColor     = barColorForValue(oWView, isRemaining: showRemaining)
        codexDialView.rightPct       = oWView
        codexDialView.rightLabel     = "Weekly"
        codexDialView.rightWarning   = isCriticalState(oWView, isRemaining: showRemaining)
        codexDialView.rightGlow      = codexWeeklyCapped ? 0.20 : 1.0
        codexDialView.rightReset     = weeklyCountdownPhrase(oWReset) + " · " + weeklyClockPhrase(oWReset)

        applyWarningBanner(item: claudeWarningItem, view: claudeWarningView,
                           sessionPct: cSEffectiveView, weeklyPct: cWView,
                           sectionName: "Claude", sessionReset: cSReset, weeklyReset: cWReset,
                           isRemaining: showRemaining,
                           designPct: cDWView, designReset: cDWReset)
        applyWarningBanner(item: codexWarningItem, view: codexWarningView,
                           sessionPct: oSEffectiveView, weeklyPct: oWView,
                           sectionName: "Codex", sessionReset: oSReset, weeklyReset: oWReset,
                           isRemaining: showRemaining)

        let toggleTitle = showRemaining ? "Show Consumed %" : "Show Remaining %"
        toggleUsageModeItem.title = toggleTitle
        setActionRowLabel(lbToggleActionTitle, title: toggleTitle, shortcut: toggleShortcutText)
        applyHoverDisclosure()
    }

    @objc func toggleUsageMode() {
        showRemaining.toggle()
        if let payload = lastPayload {
            updateUI(payload)
        } else {
            loadData()
        }
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
        if let m = globalMouseMonitor { NSEvent.removeMonitor(m) }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
