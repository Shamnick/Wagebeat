import SwiftUI
import Combine

final class AppModel: ObservableObject {
    let store: SettingsStore
    /// 固定时刻（截图/预览用）。为 nil 时跟随真实时间。
    let fixedDate: Date?

    @Published private(set) var snap: SalarySnapshot
    @Published var isExpanded = false
    @Published var showSettings = false
    /// 里程碑飘字：达到整 10 元时短暂提示
    @Published var milestone: String? = nil

    private var timer: Timer?
    private var lastMilestoneStep: Int = 0
    private var lastDayKey: String = ""
    /// 菜单栏文案跟着快照变，PanelController 订阅它。
    @Published private(set) var menuTitle: String = ""

    var settings: WorkSettings { store.settings }
    var palette: Palette { Palette.of(store.settings.theme) }

    init(store: SettingsStore = SettingsStore(), fixedDate: Date? = nil) {
        self.store = store
        self.fixedDate = fixedDate
        let now = fixedDate ?? Date()
        self.snap = SalaryEngine.snapshot(store.settings, at: now)
        self.lastMilestoneStep = Int(snap.todayEarned / 10)
        self.lastDayKey = SalaryEngine.dayKey(now)
        self.menuTitle = store.settings.showAmountInMenuBar ? "¥" + Fmt.money(snap.todayEarned, decimals: 0) : ""
    }

    func start() {
        guard fixedDate == nil else { return }
        timer?.invalidate()
        let t = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        let now = Date()
        let next = SalaryEngine.snapshot(store.settings, at: now)
        snap = next

        // 跨过零点：里程碑从头数，否则第二天要涨到昨天的金额才会飘字。
        let day = SalaryEngine.dayKey(now)
        if day != lastDayKey {
            lastDayKey = day
            lastMilestoneStep = 0
        }

        let step = Int(next.todayEarned / 10)
        if step > lastMilestoneStep, next.phase == .working {
            lastMilestoneStep = step
            flash("+ ¥\(step * 10)")
        }

        refreshMenuTitle()
    }

    /// 菜单栏金额只在整数元变化时才动，避免每 0.1 秒重排状态栏。
    func refreshMenuTitle() {
        let title = store.settings.showAmountInMenuBar
            ? "¥" + Fmt.money(snap.todayEarned, decimals: 0)
            : ""
        if title != menuTitle { menuTitle = title }
    }

    private func flash(_ text: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            milestone = text
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            guard let self, self.milestone == text else { return }
            withAnimation(.easeOut(duration: 0.35)) { self.milestone = nil }
        }
    }

    func update(_ mutate: (inout WorkSettings) -> Void) {
        var s = store.settings
        mutate(&s)
        store.settings = s
        snap = SalaryEngine.snapshot(s, at: fixedDate ?? Date())
        refreshMenuTitle()
    }

    func bumpWage(_ delta: Double) {
        update { $0.dailyWage = max(0, $0.dailyWage + delta) }
    }

    /// 今天请假 / 销假。
    func toggleLeaveToday() {
        let key = SalaryEngine.dayKey(fixedDate ?? Date())
        update { s in
            if s.leaveDays.contains(key) { s.leaveDays.remove(key) } else { s.leaveDays.insert(key) }
        }
    }

    // MARK: - 卡片尺寸

    var compactCardSize: CGSize {
        CGSize(width: Metrics.clampCompactWidth(store.settings.compactWidth),
               height: Metrics.compactSize.height)
    }

    var expandedCardSize: CGSize {
        CGSize(width: Metrics.clampExpandedWidth(store.settings.expandedWidth),
               height: Metrics.clampExpandedHeight(store.settings.expandedHeight))
    }

    func cardSize(expanded: Bool) -> CGSize {
        expanded ? expandedCardSize : compactCardSize
    }

    var cardSize: CGSize { cardSize(expanded: isExpanded) }

    /// 拖动右下角改尺寸：收起态只改宽度，展开态宽高都改。
    func resizeCard(to size: CGSize) {
        update { s in
            if isExpanded {
                s.expandedWidth = Double(Metrics.clampExpandedWidth(size.width))
                s.expandedHeight = Double(Metrics.clampExpandedHeight(size.height))
            } else {
                s.compactWidth = Double(Metrics.clampCompactWidth(size.width))
            }
        }
    }

    func resetCardSize() {
        update { s in
            s.compactWidth = Double(Metrics.compactSize.width)
            s.expandedWidth = Double(Metrics.expandedSize.width)
            s.expandedHeight = Double(Metrics.expandedSize.height)
        }
    }
}
