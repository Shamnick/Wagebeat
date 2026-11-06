import SwiftUI

struct RootView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ZStack {
            if model.isExpanded {
                ExpandedView(model: model)
                    .transition(.opacity)
            } else {
                CompactView(model: model)
                    .transition(.opacity)
            }
        }
        .frame(
            width: model.isExpanded ? Metrics.expandedSize.width : Metrics.compactSize.width,
            height: model.isExpanded ? Metrics.expandedSize.height : Metrics.compactSize.height
        )
        // 四周留白给卡片自己画的投影，窗口本体不带系统阴影
        .padding(Metrics.windowInset)
        .frame(
            width: model.isExpanded ? Metrics.expandedWindow.width : Metrics.compactWindow.width,
            height: model.isExpanded ? Metrics.expandedWindow.height : Metrics.compactWindow.height
        )
        .background(Color.clear)
        .preferredColorScheme(model.palette.isDark ? .dark : .light)
        .onChange(of: model.isExpanded) { _ in
            if !model.isExpanded { model.showSettings = false }
        }
    }
}
