import SwiftUI
import AppKit

/// 离屏渲染：把各个状态导出成 PNG，用于 README 截图与视觉回归。
/// 用法：Wagebeat --render <输出目录>
@MainActor
enum PreviewRenderer {
    static func run(outputDir: String) {
        let dir = URL(fileURLWithPath: outputDir, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // 选一个工作日 15:20：进度好看，又处于计薪中
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 11
        comps.day = 5
        comps.hour = 15
        comps.minute = 20
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        guard let date = cal.date(from: comps) else { return }

        for theme in ThemeID.allCases {
            let store = SettingsStore(persisted: false)
            store.settings.theme = theme
            store.settings.pinned = true

            let compact = AppModel(store: store, fixedDate: date)
            render(
                CompactView(model: compact)
                    .frame(width: Metrics.compactSize.width, height: Metrics.compactSize.height),
                size: Metrics.compactSize,
                to: dir.appendingPathComponent("compact-\(theme.rawValue).png")
            )

            let expanded = AppModel(store: store, fixedDate: date)
            expanded.isExpanded = true
            render(
                ExpandedView(model: expanded),
                size: Metrics.expandedSize,
                to: dir.appendingPathComponent("expanded-\(theme.rawValue).png")
            )

            let settings = AppModel(store: store, fixedDate: date)
            settings.isExpanded = true
            settings.showSettings = true
            render(
                ExpandedView(model: settings),
                size: Metrics.expandedSize,
                to: dir.appendingPathComponent("settings-\(theme.rawValue).png")
            )
        }
    }

    private static func render<V: View>(_ view: V, size: CGSize, to url: URL) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let cg = renderer.cgImage else {
            print("render failed: \(url.lastPathComponent)")
            return
        }
        let rep = NSBitmapImageRep(cgImage: cg)
        guard let data = rep.representation(using: .png, properties: [:]) else { return }
        try? data.write(to: url)
        print("wrote \(url.lastPathComponent)")
    }
}
