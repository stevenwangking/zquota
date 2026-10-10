import AppKit
#if canImport(ZCodeTouchBarShim)
import ZCodeTouchBarShim
#endif

final class CompactHUDViewController: NSViewController, NSTouchBarDelegate {
    private enum TouchBarIdentifiers {
        static let touchBar = NSTouchBar.CustomizationIdentifier("com.steven.zquota.touchbar")
        static let limits = NSTouchBarItem.Identifier("com.steven.zquota.touchbar.limits")
    }

    private let onRefresh: () -> Void
    private let onQuit: () -> Void
    private let onCollapseTouchBar: () -> Void
    private let contextMenuProvider: () -> NSMenu
    private var hudAppearance: HUDAppearance
    private var currentState = RateLimitDisplayState.initial
    private var systemModalTouchBar: NSTouchBar?
    private lazy var hudView = CompactQuotaHUDView(
        touchBarProvider: self,
        initialAppearance: hudAppearance,
        onRefresh: onRefresh,
        onQuit: onQuit,
        contextMenuProvider: contextMenuProvider
    )
    private lazy var touchBarView = TouchBarRateLimitsView(
        closeTarget: self,
        closeAction: #selector(collapseTouchBarClicked),
        refreshTarget: self,
        refreshAction: #selector(refreshClicked)
    )

    init(
        initialAppearance: HUDAppearance,
        onRefresh: @escaping () -> Void,
        onQuit: @escaping () -> Void,
        onCollapseTouchBar: @escaping () -> Void,
        contextMenuProvider: @escaping () -> NSMenu
    ) {
        self.hudAppearance = initialAppearance
        self.onRefresh = onRefresh
        self.onQuit = onQuit
        self.onCollapseTouchBar = onCollapseTouchBar
        self.contextMenuProvider = contextMenuProvider
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = hudView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        update(with: currentState)
    }

    override func makeTouchBar() -> NSTouchBar? {
        makeQuotaTouchBar()
    }

    func makeQuotaTouchBar() -> NSTouchBar {
        let touchBar = NSTouchBar()
        touchBar.customizationIdentifier = TouchBarIdentifiers.touchBar
        touchBar.delegate = self
        touchBar.defaultItemIdentifiers = [TouchBarIdentifiers.limits]
        return touchBar
    }

    /// 以系统模态方式呈现额度条（不依赖本应用窗口成为 key window）。
    /// 呈现时机由 AppDelegate 按前台应用驱动（仅 ZCode 前台时调用），此处不再激活应用：
    /// 跟随切换反复激活会抢走 ZCode 的输入焦点；TouchBar 按钮事件只要求本 app
    /// 曾被激活过一次，由 AppDelegate 在启动时保证。
    func presentTouchBarOnSystem() {
        dismissTouchBarFromSystem()
        let touchBar = makeQuotaTouchBar()
        touchBarView.update(with: currentState)

        // present 成功才持有引用；失败时保持 nil，菜单栏/HUD 不受影响
        #if canImport(ZCodeTouchBarShim)
        if ZCTouchBarPresentSystemModal(Unmanaged.passUnretained(touchBar).toOpaque(), 1) {
            systemModalTouchBar = touchBar
        } else {
            NSLog("[ZQuota] present skipped: system modal API unavailable at runtime")
        }
        #else
        NSLog("[ZQuota] present skipped: shim missing")
        #endif
    }

    /// 系统模态条是否处于呈现状态（供判重，避免已呈现时重复重建引发闪烁）
    var isTouchBarPresentedOnSystem: Bool {
        systemModalTouchBar != nil
    }

    func dismissTouchBarFromSystem() {
        if let touchBar = systemModalTouchBar {
            #if canImport(ZCodeTouchBarShim)
            ZCTouchBarDismissSystemModal(Unmanaged.passUnretained(touchBar).toOpaque())
            #endif
        }
        systemModalTouchBar = nil
    }

    /// HUD 浮窗场景：面板成为 key window 时接管 TouchBar
    func activateTouchBar(bringAppForward: Bool = false) {
        hudView.activateTouchBar(bringAppForward: bringAppForward)
    }

    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {
        case TouchBarIdentifiers.limits:
            let item = NSCustomTouchBarItem(identifier: identifier)
            item.view = touchBarView
            return item
        default:
            return nil
        }
    }

    func update(with state: RateLimitDisplayState) {
        currentState = state

        guard isViewLoaded else {
            touchBarView.update(with: state)
            return
        }

        hudView.update(with: state)
        touchBarView.update(with: state)
    }

    func updateAppearance(_ appearance: HUDAppearance) {
        hudView.updateAppearance(appearance)
    }

    @objc private func collapseTouchBarClicked() {
        onCollapseTouchBar()
    }

    @objc private func refreshClicked() {
        onRefresh()
    }

    @objc private func quitClicked() {
        onQuit()
    }
}

final class CompactQuotaHUDView: NSView {
    weak var touchBarProvider: CompactHUDViewController?

    private let firstItem = CompactQuotaItemView()
    private let secondItem = CompactQuotaItemView()
    private let refreshButton = CompactIconButton(
        symbolName: "arrow.clockwise",
        accessibilityLabel: "刷新额度"
    )
    private let quitButton = CompactIconButton(
        symbolName: "xmark",
        accessibilityLabel: "退出额度条"
    )
    private let onRefresh: () -> Void
    private let onQuit: () -> Void
    private let contextMenuProvider: () -> NSMenu
    private var hudAppearance: HUDAppearance
    private var widthConstraint: NSLayoutConstraint?
    private var contentStack: NSStackView?

    init(
        touchBarProvider: CompactHUDViewController,
        initialAppearance: HUDAppearance,
        onRefresh: @escaping () -> Void,
        onQuit: @escaping () -> Void,
        contextMenuProvider: @escaping () -> NSMenu
    ) {
        self.touchBarProvider = touchBarProvider
        self.onRefresh = onRefresh
        self.onQuit = onQuit
        self.contextMenuProvider = contextMenuProvider
        self.hudAppearance = initialAppearance
        super.init(frame: .zero)
        configure()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var mouseDownCanMoveWindow: Bool {
        true
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func becomeFirstResponder() -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        activateTouchBar(bringAppForward: true)
        super.mouseDown(with: event)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        contextMenuProvider()
    }

    override func makeTouchBar() -> NSTouchBar? {
        touchBarProvider?.makeQuotaTouchBar()
    }

    func activateTouchBar(bringAppForward: Bool = false) {
        if bringAppForward {
            NSApp.activate(ignoringOtherApps: true)
            window?.makeKeyAndOrderFront(nil)
        }

        touchBar = nil
        touchBar = makeTouchBar()
        window?.makeFirstResponder(nil)
        window?.makeFirstResponder(self)
    }

    func update(with state: RateLimitDisplayState) {
        let hasError = state.errorMessage != nil && state.fiveHour == nil && state.weekly == nil

        if let fiveHour = state.fiveHour {
            firstItem.update(with: fiveHour, title: "5h")
            if let weekly = state.weekly {
                secondItem.update(with: weekly, title: "7d")
                setMetricCount(2)
            } else {
                setMetricCount(1)
            }
        } else if let weekly = state.weekly {
            firstItem.update(with: weekly, title: "7d")
            setMetricCount(1)
        } else {
            firstItem.updatePlaceholder(title: "5h", hasError: hasError)
            secondItem.updatePlaceholder(title: "7d", hasError: hasError)
            setMetricCount(2)
        }

        refreshButton.setSpinning(state.isRefreshing)
        toolTip = state.statusText
    }

    func updateAppearance(_ appearance: HUDAppearance) {
        self.hudAppearance = appearance
        layer?.backgroundColor = appearance.backgroundColor.cgColor
        contentStack?.alphaValue = appearance.contentOpacity
    }

    private func configure() {
        wantsLayer = true
        layer?.backgroundColor = hudAppearance.backgroundColor.cgColor
        layer?.cornerRadius = 17
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = false

        refreshButton.target = self
        refreshButton.action = #selector(refreshClicked)
        quitButton.target = self
        quitButton.action = #selector(quitClicked)

        let stack = NSStackView(views: [firstItem, secondItem, refreshButton, quitButton])
        contentStack = stack
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.distribution = .fill
        stack.spacing = 8
        stack.alphaValue = hudAppearance.contentOpacity

        addSubview(stack)

        let widthConstraint = widthAnchor.constraint(equalToConstant: 250)
        self.widthConstraint = widthConstraint

        NSLayoutConstraint.activate([
            widthConstraint,
            heightAnchor.constraint(equalToConstant: 34),
            firstItem.widthAnchor.constraint(equalToConstant: 76),
            secondItem.widthAnchor.constraint(equalToConstant: 76),
            refreshButton.widthAnchor.constraint(equalToConstant: 20),
            refreshButton.heightAnchor.constraint(equalToConstant: 20),
            quitButton.widthAnchor.constraint(equalToConstant: 20),
            quitButton.heightAnchor.constraint(equalToConstant: 20),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    private func setMetricCount(_ count: Int) {
        let showsSecondItem = count > 1
        secondItem.isHidden = !showsSecondItem

        let targetWidth: CGFloat = showsSecondItem ? 250 : 166
        guard widthConstraint?.constant != targetWidth else {
            return
        }

        widthConstraint?.constant = targetWidth

        guard let window else {
            frame.size.width = targetWidth
            return
        }

        let previousMidX = window.frame.midX
        window.setContentSize(NSSize(width: targetWidth, height: 34))
        var origin = window.frame.origin
        origin.x = previousMidX - window.frame.width / 2
        window.setFrameOrigin(origin)
    }

    @objc private func refreshClicked() {
        onRefresh()
    }

    @objc private func quitClicked() {
        onQuit()
    }
}

private final class CompactQuotaItemView: NSView {
    private let dotView = CompactStatusDotView()
    private let label = NSTextField(labelWithString: "-- --")

    init() {
        super.init(frame: .zero)
        configure()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(with meter: LimitMeter, title: String) {
        let remaining = Int(meter.remainingPercent.rounded())
        label.stringValue = "\(title) \(remaining)%"
        label.textColor = .white
        dotView.color = color(for: remaining)
    }

    func updatePlaceholder(title: String, hasError: Bool) {
        label.stringValue = "\(title) --"
        label.textColor = NSColor.white.withAlphaComponent(0.62)
        dotView.color = hasError ? NSColor.systemRed : NSColor.white.withAlphaComponent(0.28)
    }

    private func configure() {
        translatesAutoresizingMaskIntoConstraints = false

        label.font = .monospacedDigitSystemFont(ofSize: 13, weight: .bold)
        label.textColor = .white
        label.lineBreakMode = .byClipping
        label.setContentCompressionResistancePriority(.required, for: .horizontal)

        let stack = NSStackView(views: [dotView, label])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 6

        addSubview(stack)

        NSLayoutConstraint.activate([
            dotView.widthAnchor.constraint(equalToConstant: 8),
            dotView.heightAnchor.constraint(equalToConstant: 8),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func color(for remaining: Int) -> NSColor {
        if remaining <= 20 {
            return NSColor.systemRed
        }
        if remaining <= 45 {
            return NSColor.systemYellow
        }
        return NSColor.systemGreen
    }
}

/// HUD 上的小图标按钮：hover 有高亮与放大反馈，可播放旋转动画（刷新态）
private final class CompactIconButton: NSButton {
    private var hoverArea: NSTrackingArea?

    init(symbolName: String, accessibilityLabel: String) {
        super.init(frame: .zero)

        image = NSImage(systemSymbolName: symbolName, accessibilityDescription: accessibilityLabel)
        imagePosition = .imageOnly
        imageScaling = .scaleProportionallyDown
        isBordered = false
        bezelStyle = .regularSquare
        setButtonType(.momentaryChange)
        contentTintColor = NSColor.white.withAlphaComponent(0.88)
        toolTip = accessibilityLabel
        translatesAutoresizingMaskIntoConstraints = false

        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.cornerCurve = .continuous
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        // hover 缩放需要中心锚点；先记 frame 再改 anchor，frame setter 会同步重算 position 保持几何不变
        if let layer {
            let frame = layer.frame
            layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            layer.frame = frame
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverArea {
            removeTrackingArea(hoverArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        hoverArea = area
        addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) {
        setHoverEffect(true)
    }

    override func mouseExited(with event: NSEvent) {
        setHoverEffect(false)
    }

    private func setHoverEffect(_ hovered: Bool) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.12)
        layer?.backgroundColor = hovered
            ? NSColor.white.withAlphaComponent(0.18).cgColor
            : nil
        layer?.transform = hovered
            ? CATransform3DMakeScale(1.15, 1.15, 1)
            : CATransform3DIdentity
        CATransaction.commit()

        contentTintColor = hovered ? .white : NSColor.white.withAlphaComponent(0.88)
    }
}

private final class CompactStatusDotView: NSView {
    var color = NSColor.systemGreen {
        didSet {
            needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        color.setFill()
        NSBezierPath(ovalIn: bounds.insetBy(dx: 1, dy: 1)).fill()
    }
}
