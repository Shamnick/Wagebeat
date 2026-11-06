import AppKit
import SwiftUI
import Combine

/// 无边框悬浮面板：不抢焦点、可跨空间悬浮、跟随窗口拖动。
final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init() {
        super.init(
            contentRect: NSRect(origin: .zero, size: Metrics.compactWindow),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        // 系统窗口阴影会贴着圆角描出一条灰黑色边，改由卡片自己绘制柔和投影
        hasShadow = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none
    }
}

/// 卡片右下角的拖拽热区：透明，只负责接鼠标事件。
/// 尺寸变化走 PanelController，SwiftUI 那边只管把卡片画成对应大小。
final class ResizeHotZone: NSView {
    /// 展开态可以同时改宽高，收起态只能改宽度。
    var isExpanded = false

    var onBegan: (() -> Void)?
    /// 参数是新的卡片尺寸（不含四周留白）
    var onChanged: ((CGSize) -> Void)?
    var onEnded: ((CGSize) -> Void)?

    private var startMouse: NSPoint = .zero
    private var startFrame: NSRect = .zero
    private var startCard: CGSize = .zero
    private var currentCard: CGSize = .zero

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: isExpanded ? .crosshair : .resizeLeftRight)
    }

    /// 面板不抢焦点，第一下点击也要能直接按住手柄。
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        startMouse = NSEvent.mouseLocation
        startFrame = window.frame
        startCard = CGSize(
            width: startFrame.width - Metrics.windowInset * 2,
            height: startFrame.height - Metrics.windowInset * 2
        )
        currentCard = startCard
        onBegan?()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        let now = NSEvent.mouseLocation
        let dx = now.x - startMouse.x
        let dy = now.y - startMouse.y

        let rawWidth = startCard.width + dx
        let width = isExpanded ? Metrics.clampExpandedWidth(rawWidth) : Metrics.clampCompactWidth(rawWidth)
        let height = isExpanded
            ? Metrics.clampExpandedHeight(startCard.height - dy)
            : startCard.height
        currentCard = CGSize(width: width, height: height)

        var frame = NSRect(
            x: startFrame.minX,
            y: startFrame.maxY - (height + Metrics.windowInset * 2),
            width: width + Metrics.windowInset * 2,
            height: height + Metrics.windowInset * 2
        )
        // 别把卡片拖出屏幕
        if let vis = (window.screen ?? NSScreen.main)?.visibleFrame {
            frame.origin.x = min(frame.origin.x, vis.maxX - frame.width - 8)
            frame.origin.y = max(frame.origin.y, vis.minY + 8)
        }
        window.setFrame(frame, display: true)
        onChanged?(currentCard)
    }

    override func mouseUp(with event: NSEvent) {
        onEnded?(currentCard)
    }
}

/// 承载 SwiftUI 的容器：负责把热区钉在卡片右下角。
final class PanelContentView: NSView {
    let hotZone = ResizeHotZone()

    override func layout() {
        super.layout()
        let inset = Metrics.windowInset
        hotZone.frame = NSRect(
            x: bounds.maxX - inset - 20,
            y: inset,
            width: 20,
            height: 20
        )
    }
}

final class PanelController {
    static let shared = PanelController()

    private var panel: FloatingPanel?
    private var model: AppModel?
    private var statusItem: NSStatusItem?
    private var hotZone: ResizeHotZone?
    private let positionKey = "wagebeat.frame"

    func install(model: AppModel) {
        self.model = model
        let panel = FloatingPanel()
        self.panel = panel

        let root = RootView(model: model)
        let host = NSHostingView(rootView: root)
        host.wantsLayer = true

        let container = PanelContentView()
        container.addSubview(host)
        host.frame = container.bounds
        host.autoresizingMask = [.width, .height]
        container.addSubview(container.hotZone)
        hotZone = container.hotZone
        panel.contentView = container

        hotZone?.isExpanded = model.isExpanded
        hotZone?.onBegan = { [weak self] in
            self?.beginUserResize()
        }
        // 拖的过程中就把尺寸喂给 SwiftUI，卡片内容跟着一起变，不用等松手
        hotZone?.onChanged = { [weak self] size in
            self?.model?.resizeCard(to: size)
        }
        hotZone?.onEnded = { [weak self] size in
            self?.finishUserResize(cardSize: size)
        }

        panel.setFrame(currentFrame(), display: false)
        panel.orderFrontRegardless()

        if ProcessInfo.processInfo.environment["WAGEBEAT_DEBUG"] != nil {
            let msg = "DEBUG panel frame=\(panel.frame) visible=\(panel.isVisible) level=\(panel.level.rawValue) screen=\(String(describing: NSScreen.main?.visibleFrame)) screens=\(NSScreen.screens.count)\n"
            try? msg.write(toFile: "/tmp/wagebeat-debug.log", atomically: true, encoding: .utf8)
        }

        buildStatusItem()
        observeExpansion()
        observeCardSize()
    }

    // MARK: - Frame

    /// 窗口尺寸 = 卡片尺寸 + 四周透明留白。
    private func windowSize(expanded: Bool) -> CGSize {
        let card = model?.cardSize(expanded: expanded) ?? (expanded ? Metrics.expandedSize : Metrics.compactSize)
        return CGSize(
            width: card.width + Metrics.windowInset * 2,
            height: card.height + Metrics.windowInset * 2
        )
    }

    private func currentFrame() -> NSRect {
        let size = windowSize(expanded: false)
        if let raw = UserDefaults.standard.string(forKey: positionKey) {
            let parts = raw.split(separator: ",").compactMap { Double($0) }
            if parts.count == 2 {
                return clamped(NSRect(x: parts[0], y: parts[1], width: size.width, height: size.height))
            }
        }
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        return NSRect(
            x: screen.maxX - size.width - 40,
            y: screen.maxY - size.height - 40,
            width: size.width,
            height: size.height
        )
    }

    /// 换过显示器、改过分辨率后，旧位置可能已经落在屏幕外。
    private func clamped(_ rect: NSRect) -> NSRect {
        guard let vis = (NSScreen.main?.visibleFrame) else { return rect }
        var r = rect
        r.origin.x = min(max(r.minX, vis.minX + 8), vis.maxX - r.width - 8)
        r.origin.y = min(max(r.minY, vis.minY + 8), vis.maxY - r.height - 8)
        return r
    }

    private func observeExpansion() {
        guard let model else { return }
        model.$isExpanded
            .removeDuplicates()
            .sink { [weak self] expanded in
                guard let self else { return }
                if let hotZone = self.hotZone {
                    hotZone.isExpanded = expanded
                    self.panel?.invalidateCursorRects(for: hotZone)
                }
                self.resize(expanded: expanded)
            }
            .store(in: &bag)
    }

    /// 拖动缩放、恢复默认尺寸都会动到设置里的尺寸，窗口跟着一起变。
    private func observeCardSize() {
        guard let model else { return }
        model.store.$settings
            .map { [weak model] _ in model?.cardSize ?? .zero }
            .removeDuplicates()
            .sink { [weak self] size in
                guard let self, let panel = self.panel else { return }
                // 正在拖手柄时窗口由 userResize 自己摆，别在这里二次改锚点
                guard !self.isUserResizing else { return }
                let target = CGSize(
                    width: size.width + Metrics.windowInset * 2,
                    height: size.height + Metrics.windowInset * 2
                )
                guard target != panel.frame.size else { return }
                self.setFrame(anchored: target, animated: true)
            }
            .store(in: &bag)
    }

    private var bag = Set<AnyCancellable>()

    private func resize(expanded: Bool) {
        setFrame(anchored: windowSize(expanded: expanded), animated: true)
    }

    /// 保持右上角不动地改窗口尺寸，并保证不出屏幕。
    private func setFrame(anchored target: CGSize, animated: Bool) {
        guard let panel else { return }
        let old = panel.frame
        var rect = NSRect(
            x: old.maxX - target.width,
            y: old.maxY - target.height,
            width: target.width,
            height: target.height
        )
        if let screen = panel.screen ?? NSScreen.main {
            let vis = screen.visibleFrame
            rect.origin.x = min(max(rect.minX, vis.minX + 8), vis.maxX - rect.width - 8)
            rect.origin.y = min(max(rect.minY, vis.minY + 8), vis.maxY - rect.height - 8)
        }

        guard animated else {
            panel.setFrame(rect, display: true)
            return
        }

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.34
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 1, 0.36, 1)
            panel.animator().setFrame(rect, display: true)
        }
    }

    // MARK: - 拖动缩放

    private var isUserResizing = false

    /// 手柄按下：先冻结自动跟随，避免和拖拽抢窗口位置。
    func beginUserResize() {
        isUserResizing = true
    }

    /// 手柄松开：把最终尺寸写回设置，再恢复自动跟随。
    func finishUserResize(cardSize: CGSize) {
        model?.resizeCard(to: cardSize)
        isUserResizing = false
        persistPosition()
    }

    func persistPosition() {
        guard let panel else { return }
        UserDefaults.standard.set("\(panel.frame.origin.x),\(panel.frame.origin.y)", forKey: positionKey)
    }

    func toggleExpanded() {
        model?.isExpanded.toggle()
    }

    func toggleVisible() {
        guard let panel else { return }
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.orderFrontRegardless()
        }
    }

    func applyPin() {
        guard let panel else { return }
        let pinned = model?.settings.pinned ?? true
        panel.level = pinned ? .floating : .normal
        panel.collectionBehavior = pinned ? [.canJoinAllSpaces, .fullScreenAuxiliary] : []
    }

    // MARK: - Menu Bar

    private func buildStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "yensign.circle.fill",
            accessibilityDescription: "薪跳"
        )
        item.button?.image?.isTemplate = true

        let menu = NSMenu()
        menu.addItem(withTitle: "展开 / 收起", action: #selector(menuToggle), keyEquivalent: "").target = self
        menu.addItem(withTitle: "显示 / 隐藏", action: #selector(menuVisible), keyEquivalent: "").target = self
        menu.addItem(withTitle: "恢复默认尺寸", action: #selector(menuResetSize), keyEquivalent: "").target = self
        menu.addItem(.separator())
        let pin = menu.addItem(withTitle: "始终置顶", action: #selector(menuPin), keyEquivalent: "")
        pin.target = self
        pin.state = .on
        menu.addItem(withTitle: "偏好设置…", action: #selector(menuSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出薪跳", action: #selector(menuQuit), keyEquivalent: "q").target = self

        item.menu = menu
        statusItem = item
    }

    @objc private func menuToggle() { toggleExpanded() }
    @objc private func menuVisible() { toggleVisible() }

    @objc private func menuResetSize() {
        model?.resetCardSize()
    }

    @objc private func menuPin(_ sender: NSMenuItem) {
        model?.update { $0.pinned.toggle() }
        sender.state = (model?.settings.pinned ?? true) ? .on : .off
        applyPin()
    }

    @objc private func menuSettings() {
        model?.isExpanded = true
        model?.showSettings = true
    }

    @objc private func menuQuit() {
        NSApp.terminate(nil)
    }
}
