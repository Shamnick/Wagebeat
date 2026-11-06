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
    var theme: ThemeID = .aurora
    var pinned: Bool = true
    var showInMenuBar: Bool = true

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
