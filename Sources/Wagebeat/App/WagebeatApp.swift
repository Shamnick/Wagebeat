import SwiftUI
import AppKit

@main
struct WagebeatApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        // 面板与菜单栏都由 AppDelegate 手动搭建，
        // 这里留一个空 Settings 场景，避免 SwiftUI 自动生成主窗口。
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 截图工具：渲染各状态后直接退出，不启动面板
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "--render"), i + 1 < args.count {
            PreviewRenderer.run(outputDir: args[i + 1])
            NSApp.terminate(nil)
            return
        }

        NSApp.setActivationPolicy(.accessory)

        let model = AppModel()
        self.model = model
        PanelController.shared.install(model: model)
        PanelController.shared.applyPin()
        // 系统里真实的自启状态优先，别让设置和它拧着
        let real = LaunchAtLogin.isOn
        if model.settings.launchAtLogin != real {
            model.update { $0.launchAtLogin = real }
        }
        model.start()

        if ProcessInfo.processInfo.arguments.contains("--expanded") {
            model.isExpanded = true
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        PanelController.shared.persistPosition()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
