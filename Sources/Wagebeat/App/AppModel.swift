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

    var settings: WorkSettings { store.settings }
    var palette: Palette { Palette.of(store.settings.theme) }

    init(store: SettingsStore = SettingsStore(), fixedDate: Date? = nil) {
        self.store = store
        self.fixedDate = fixedDate
        self.snap = SalaryEngine.snapshot(store.settings, at: fixedDate ?? Date())
        self.lastMilestoneStep = Int(snap.todayEarned / 10)
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
        let next = SalaryEngine.snapshot(store.settings, at: Date())
        snap = next

        let step = Int(next.todayEarned / 10)
        if step > lastMilestoneStep, next.phase == .working {
            lastMilestoneStep = step
            flash("+ ¥\(step * 10)")
        }
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
    }

    func bumpWage(_ delta: Double) {
        update { $0.dailyWage = max(0, $0.dailyWage + delta) }
    }
}
