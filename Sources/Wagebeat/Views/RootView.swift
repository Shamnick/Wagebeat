import SwiftUI

struct RootView: View {
    @ObservedObject var model: AppModel

    private var cardSize: CGSize { model.cardSize }
    private var windowSize: CGSize {
        CGSize(
            width: cardSize.width + Metrics.windowInset * 2,
            height: cardSize.height + Metrics.windowInset * 2
        )
    }

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
        .frame(width: cardSize.width, height: cardSize.height)
        // 四周留白给卡片自己画的投影，窗口本体不带系统阴影
        .padding(Metrics.windowInset)
        .frame(width: windowSize.width, height: windowSize.height)
        .background(Color.clear)
        .preferredColorScheme(model.palette.isDark ? .dark : .light)
        .onChange(of: model.isExpanded) { expanded in
            if !expanded { model.showSettings = false }
        }
    }
}
