import AppKit
import ObjectiveC

extension NSButton {
    private static var spinningStateKey: UInt8 = 0
    private var isSpinActive: Bool {
        get { objc_getAssociatedObject(self, &Self.spinningStateKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &Self.spinningStateKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// 刷新态：CA 层旋转动画（TouchBar 视图由 Core Animation 合成，
    /// NSAnimationContext 的 frameCenterRotation 属性动画在其中不渲染）
    func setSpinning(_ spinning: Bool) {
        wantsLayer = true
        guard spinning != isSpinActive else {
            return
        }
        NSLog("[ZQuota] spin \(spinning ? "start" : "stop")")
        isSpinActive = spinning
        if spinning {
            centerLayerAnchor()
            let spin = CABasicAnimation(keyPath: "transform.rotation.z")
            spin.fromValue = 0
            spin.toValue = CGFloat.pi * 2
            spin.duration = 0.9
            spin.repeatCount = .infinity
            layer?.add(spin, forKey: "spin")
        } else {
            layer?.removeAnimation(forKey: "spin")
        }
    }

    /// 锚点居中：先记 frame 再改 anchor，frame setter 会按新锚点重算 position，几何不变
    private func centerLayerAnchor() {
        guard let layer else {
            return
        }
        let frame = layer.frame
        layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        layer.frame = frame
    }
}

final class TouchBarRateLimitsView: NSView {
    private let closeButton = NSButton()
    private let refreshButton = NSButton()
    private let zcodeIconView = NSImageView()
    private let fiveHourRow = TouchBarLimitRow(title: "5 小时")
    private let weeklyRow = TouchBarLimitRow(title: "周限额")

    init(closeTarget: AnyObject, closeAction: Selector, refreshTarget: AnyObject, refreshAction: Selector) {
        super.init(frame: .zero)
        closeButton.target = closeTarget
        closeButton.action = closeAction
        refreshButton.target = refreshTarget
        refreshButton.action = refreshAction
        configure()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        // 无需锚点处理：旋转动画走 frameCenterRotation（NSButton 扩展内实现）
    }

    func update(with state: RateLimitDisplayState) {
        refreshButton.setSpinning(state.isRefreshing)
        if let fiveHour = state.fiveHour {
            fiveHourRow.isHidden = false
            fiveHourRow.updateLimit(
                title: "5 小时",
                meter: fiveHour,
                usageText: Self.resetCountdownText(for: fiveHour.resetDate)
            )
        } else if state.lastUpdated != nil {
            fiveHourRow.isHidden = true
        } else {
            fiveHourRow.isHidden = false
            fiveHourRow.updatePlaceholder(title: "5 小时", usageText: "重置 --")
        }

        if let weekly = state.weekly {
            weeklyRow.isHidden = false
            weeklyRow.updateLimit(
                title: "周限额",
                meter: weekly,
                usageText: Self.resetCountdownText(for: weekly.resetDate)
            )
        } else if state.lastUpdated != nil {
            weeklyRow.isHidden = true
        } else {
            weeklyRow.isHidden = false
            weeklyRow.updatePlaceholder(title: "周限额", usageText: "重置 --")
        }
    }

    /// 距离额度重置的倒计时文案；重置即额度恢复满额
    static func resetCountdownText(for resetDate: Date?) -> String {
        guard let resetDate else {
            return "重置 --"
        }

        let seconds = max(0, Int(resetDate.timeIntervalSinceNow))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours >= 24 {
            return "\(hours / 24)天\(hours % 24)时后重置"
        }
        if hours >= 1 {
            return "\(hours)时\(minutes)分后重置"
        }
        return "\(minutes)分后重置"
    }

    private func configure() {
        translatesAutoresizingMaskIntoConstraints = false

        // circular bezel 在新版 AppKit 的 TouchBar 环境下不再可靠绘制，改无边框文本按钮
        closeButton.title = "×"
        closeButton.isBordered = false
        closeButton.setButtonType(.momentaryChange)
        closeButton.font = .systemFont(ofSize: 15, weight: .semibold)
        closeButton.contentTintColor = .labelColor
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        // 右端刷新按钮：系统同款双箭头刷新图标，小尺寸、紧跟状态文字
        if let symbol = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: "刷新额度")?
            .withSymbolConfiguration(.init(pointSize: 14, weight: .medium)) {
            refreshButton.image = symbol
            refreshButton.imagePosition = .imageOnly
            refreshButton.imageScaling = .scaleProportionallyDown
            refreshButton.contentTintColor = .labelColor
        } else {
            refreshButton.title = "↻"
            refreshButton.font = .systemFont(ofSize: 12, weight: .semibold)
        }
        refreshButton.isBordered = false
        refreshButton.setButtonType(.momentaryChange)
        refreshButton.toolTip = "刷新额度"
        refreshButton.translatesAutoresizingMaskIntoConstraints = false
        refreshButton.wantsLayer = true

        zcodeIconView.image = Self.zcodeIcon()
        zcodeIconView.imageAlignment = .alignCenter
        zcodeIconView.imageScaling = .scaleProportionallyUpOrDown
        zcodeIconView.translatesAutoresizingMaskIntoConstraints = false
        zcodeIconView.toolTip = "ZCode"

        let rows = NSStackView(views: [fiveHourRow, weeklyRow])
        rows.translatesAutoresizingMaskIntoConstraints = false
        rows.orientation = .vertical
        rows.alignment = .leading
        rows.distribution = .fill
        rows.spacing = 1
        // 拒绝水平拉伸：否则 content stack 会把 rows 拉宽、把刷新按钮顶到最右端
        rows.setContentHuggingPriority(.required, for: .horizontal)
        fiveHourRow.setContentHuggingPriority(.required, for: .horizontal)
        weeklyRow.setContentHuggingPriority(.required, for: .horizontal)

        let content = NSStackView(views: [closeButton, zcodeIconView, rows, refreshButton])
        content.translatesAutoresizingMaskIntoConstraints = false
        content.orientation = .horizontal
        content.alignment = .centerY
        content.spacing = 12
        content.setCustomSpacing(2, after: zcodeIconView)
        content.setCustomSpacing(5, after: rows)

        addSubview(content)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 660),
            heightAnchor.constraint(equalToConstant: 30),
            closeButton.widthAnchor.constraint(equalToConstant: 34),
            closeButton.heightAnchor.constraint(equalToConstant: 28),
            refreshButton.widthAnchor.constraint(equalToConstant: 30),
            refreshButton.heightAnchor.constraint(equalToConstant: 28),
            zcodeIconView.widthAnchor.constraint(equalToConstant: 34),
            zcodeIconView.heightAnchor.constraint(equalToConstant: 30),
            fiveHourRow.widthAnchor.constraint(equalToConstant: 538),
            weeklyRow.widthAnchor.constraint(equalToConstant: 538),
            content.leadingAnchor.constraint(equalTo: leadingAnchor),
            content.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            content.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    private static func zcodeIcon() -> NSImage {
        let zcodeAppPath = "/Applications/ZCode.app"
        if FileManager.default.fileExists(atPath: zcodeAppPath) {
            let image = NSWorkspace.shared.icon(forFile: zcodeAppPath)
            image.size = NSSize(width: 30, height: 30)
            return image
        }

        let bundledIconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns")
        let image = bundledIconPath.flatMap(NSImage.init(contentsOfFile:))
            ?? NSImage(systemSymbolName: "terminal.fill", accessibilityDescription: "ZCode")
            ?? NSImage(size: NSSize(width: 30, height: 30))
        image.size = NSSize(width: 30, height: 30)
        return image
    }
}

private final class TouchBarLimitRow: NSView {
    private let titleLabel: NSTextField
    private let batteryBar = SegmentedBatteryBar()
    private let remainingLabel = NSTextField(labelWithString: "剩余 --")
    private let resetLabel = NSTextField(labelWithString: "-- 重置")
    private let separatorLabel = NSTextField(labelWithString: "|")
    private let usageLabel = NSTextField(labelWithString: "--")

    init(title: String) {
        self.titleLabel = NSTextField(labelWithString: title)
        super.init(frame: .zero)
        configure()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateLimit(title: String, meter: LimitMeter, usageText: String) {
        titleLabel.stringValue = title
        batteryBar.isHidden = false
        batteryBar.remainingPercent = meter.remainingPercent
        batteryBar.isDimmed = false
        remainingLabel.stringValue = "剩余 \(meter.remainingText)"
        resetLabel.stringValue = meter.resetText
        usageLabel.stringValue = usageText
    }

    func updatePlaceholder(title: String, usageText: String) {
        titleLabel.stringValue = title
        batteryBar.isHidden = false
        batteryBar.remainingPercent = 0
        batteryBar.isDimmed = true
        remainingLabel.stringValue = "剩余 --"
        resetLabel.stringValue = "-- 重置"
        usageLabel.stringValue = usageText
    }

    private func configure() {
        translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .left

        remainingLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        remainingLabel.textColor = .labelColor
        remainingLabel.lineBreakMode = .byTruncatingTail

        resetLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        resetLabel.textColor = .labelColor
        resetLabel.lineBreakMode = .byTruncatingTail

        separatorLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        separatorLabel.textColor = .labelColor
        separatorLabel.alignment = .center

        usageLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        usageLabel.textColor = .labelColor
        usageLabel.lineBreakMode = .byTruncatingTail

        batteryBar.translatesAutoresizingMaskIntoConstraints = false

        let row = NSStackView(views: [
            titleLabel,
            batteryBar,
            remainingLabel,
            resetLabel,
            separatorLabel,
            usageLabel
        ])
        row.translatesAutoresizingMaskIntoConstraints = false
        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .fill
        row.spacing = 8
        row.setCustomSpacing(4, after: titleLabel)
        row.setCustomSpacing(0, after: remainingLabel)
        row.setCustomSpacing(4, after: resetLabel)
        row.setCustomSpacing(4, after: separatorLabel)

        addSubview(row)

        let preferredHeight = heightAnchor.constraint(equalToConstant: 13)
        preferredHeight.priority = .defaultHigh

        NSLayoutConstraint.activate([
            preferredHeight,
            titleLabel.widthAnchor.constraint(equalToConstant: 42),
            batteryBar.widthAnchor.constraint(equalToConstant: 175),
            batteryBar.heightAnchor.constraint(equalToConstant: 11),
            remainingLabel.widthAnchor.constraint(equalToConstant: 58),
            resetLabel.widthAnchor.constraint(equalToConstant: 125),
            separatorLabel.widthAnchor.constraint(equalToConstant: 8),
            usageLabel.widthAnchor.constraint(equalToConstant: 110),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}
