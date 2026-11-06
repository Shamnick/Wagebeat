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
        .background(Color.clear)
        .preferredColorScheme(model.palette.isDark ? .dark : .light)
        .onChange(of: model.isExpanded) { _ in
            if !model.isExpanded { model.showSettings = false }
        }
    }
}
