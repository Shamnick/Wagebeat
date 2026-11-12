import Foundation
import ServiceManagement

/// 开机自启动。macOS 13 起统一走 SMAppService，不需要自己塞 LaunchAgent。
enum LaunchAtLogin {
    static var isOn: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func set(_ on: Bool) {
        do {
            if on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // 调试运行时 bundle 不在 /Applications，注册会失败，忽略即可
            NSLog("Wagebeat: launch at login \(on ? "on" : "off") failed — \(error.localizedDescription)")
        }
    }
}
