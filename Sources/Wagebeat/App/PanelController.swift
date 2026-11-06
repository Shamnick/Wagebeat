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

final class PanelController {
    static let shared = PanelController()

    private var panel: FloatingPanel?
    private var model: AppModel?
    private var statusItem: NSStatusItem?
    private let positionKey = "wagebeat.frame"

    func install(model: AppModel) {
        self.model = model
        let panel = FloatingPanel()
        self.panel = panel

        let root = RootView(model: model)
        let host = NSHostingView(rootView: root)
        host.wantsLayer = true
        panel.contentView = host

        panel.setFrame(currentFrame(expanded: false), display: false)
        panel.orderFrontRegardless()

        if ProcessInfo.processInfo.environment["WAGEBEAT_DEBUG"] != nil {
            let msg = "DEBUG panel frame=\(panel.frame) visible=\(panel.isVisible) level=\(panel.level.rawValue) screen=\(String(describing: NSScreen.main?.visibleFrame)) screens=\(NSScreen.screens.count)\n"
            try? msg.write(toFile: "/tmp/wagebeat-debug.log", atomically: true, encoding: .utf8)
        }

        buildStatusItem()
        observeExpansion()
    }

    // MARK: - Frame

    private func currentFrame(expanded: Bool) -> NSRect {
        let size = Metrics.compactWindow
        if let raw = UserDefaults.standard.string(forKey: positionKey) {
            let parts = raw.split(separator: ",").compactMap { Double($0) }
            if parts.count == 2 {
                return NSRect(x: parts[0], y: parts[1], width: size.width, height: size.height)
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

    private func observeExpansion() {
        guard let model else { return }
        model.$isExpanded
            .removeDuplicates()
            .sink { [weak self] expanded in
                self?.resize(expanded: expanded)
            }
            .store(in: &bag)
    }

    private var bag = Set<AnyCancellable>()

    private func resize(expanded: Bool) {
        guard let panel else { return }
        let old = panel.frame
        let target = expanded ? Metrics.expandedWindow : Metrics.compactWindow

        // 以右上角为锚点展开，避免面板“跳走”
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

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.34
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 1, 0.36, 1)
            panel.animator().setFrame(rect, display: true)
        }
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
