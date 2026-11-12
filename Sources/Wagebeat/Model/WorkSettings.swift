import Foundation
import Combine

/// 一天里的计薪规则：几点上班、午休多久、几点下班、一天多少钱。
/// 全部用“距零点的分钟数”存储，避免时区/夏令时把简单问题搞复杂。
struct WorkSettings: Codable, Equatable {
    var dailyWage: Double = 294
    var clockIn: Int = 9 * 60
    var breakStart: Int = 12 * 60
    var breakEnd: Int = 14 * 60
    var clockOut: Int = 19 * 60
    var hasBreak: Bool = true
    /// Calendar 的 weekday：1 = 周日 … 7 = 周六。默认周一到周五。
    var workdays: Set<Int> = [2, 3, 4, 5, 6]
    /// 每月计薪天数；为空时按当月实际工作日自动计算。
    var monthlyDays: Int? = nil
    /// 请假的日子（"2026-11-12"），不计薪也不计入本月。
    var leaveDays: Set<String> = []
    var theme: ThemeID = .aurora
    var pinned: Bool = true
    /// 菜单栏图标旁显示今日金额。
    var showAmountInMenuBar: Bool = false
    /// 登录时自动启动。
    var launchAtLogin: Bool = false

    /// 卡片尺寸，可自由拉伸后记住。
    var compactWidth: Double = 186
    var expandedWidth: Double = 330
    var expandedHeight: Double = 330

    init() {}

    /// 老版本存档里没有尺寸字段，缺哪个用默认值补哪个，不让整份设置回退。
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dailyWage = try c.decodeIfPresent(Double.self, forKey: .dailyWage) ?? 294
        clockIn = try c.decodeIfPresent(Int.self, forKey: .clockIn) ?? 9 * 60
        breakStart = try c.decodeIfPresent(Int.self, forKey: .breakStart) ?? 12 * 60
        breakEnd = try c.decodeIfPresent(Int.self, forKey: .breakEnd) ?? 14 * 60
        clockOut = try c.decodeIfPresent(Int.self, forKey: .clockOut) ?? 19 * 60
        hasBreak = try c.decodeIfPresent(Bool.self, forKey: .hasBreak) ?? true
        workdays = try c.decodeIfPresent(Set<Int>.self, forKey: .workdays) ?? [2, 3, 4, 5, 6]
        monthlyDays = try c.decodeIfPresent(Int.self, forKey: .monthlyDays)
        leaveDays = try c.decodeIfPresent(Set<String>.self, forKey: .leaveDays) ?? []
        theme = try c.decodeIfPresent(ThemeID.self, forKey: .theme) ?? .aurora
        pinned = try c.decodeIfPresent(Bool.self, forKey: .pinned) ?? true
        showAmountInMenuBar = try c.decodeIfPresent(Bool.self, forKey: .showAmountInMenuBar) ?? false
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        compactWidth = try c.decodeIfPresent(Double.self, forKey: .compactWidth) ?? 186
        expandedWidth = try c.decodeIfPresent(Double.self, forKey: .expandedWidth) ?? 330
        expandedHeight = try c.decodeIfPresent(Double.self, forKey: .expandedHeight) ?? 330
    }

    var breakMinutes: Int { hasBreak ? max(0, breakEnd - breakStart) : 0 }
    var paidMinutes: Int { max(1, clockOut - clockIn - breakMinutes) }
    var paidSeconds: Double { Double(paidMinutes) * 60 }
    var perSecond: Double { dailyWage / paidSeconds }
    var perHour: Double { perSecond * 3600 }

    /// 有效计薪区间（秒），午休被挖掉。
    var paidSegments: [(start: Int, end: Int)] {
        let a = clockIn * 60
        let b = (hasBreak ? breakStart : clockIn) * 60
        let c = (hasBreak ? breakEnd : clockIn) * 60
        let d = clockOut * 60
        var out: [(Int, Int)] = []
        if b > a { out.append((a, b)) }
        if d > c { out.append((c, d)) }
        return out
    }

    var isValid: Bool {
        clockIn < clockOut
            && (!hasBreak || (clockIn <= breakStart && breakStart <= breakEnd && breakEnd <= clockOut))
            && dailyWage >= 0
    }
}

final class SettingsStore: ObservableObject {
    private static let key = "wagebeat.settings.v2"

    private let persisted: Bool

    @Published var settings: WorkSettings {
        didSet { persist() }
    }

    init(persisted: Bool = true) {
        self.persisted = persisted
        if persisted,
           let data = UserDefaults.standard.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode(WorkSettings.self, from: data) {
            settings = decoded
        } else {
            settings = WorkSettings()
        }
    }

    private func persist() {
        guard persisted else { return }
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }
}
