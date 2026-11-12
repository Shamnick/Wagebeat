import Foundation

enum DayPhase {
    case restDay
    case beforeWork
    case working
    case onBreak
    case afterWork

    var label: String {
        switch self {
        case .restDay: return "休息日"
        case .beforeWork: return "待开工"
        case .working: return "计薪中"
        case .onBreak: return "午休中"
        case .afterWork: return "已收工"
        }
    }
}

/// 某一瞬间的完整薪资快照。视图只读它，不做任何计算。
struct SalarySnapshot {
    var phase: DayPhase = .restDay

    var todayEarned: Double = 0
    var todayTarget: Double = 0
    var todayProgress: Double = 0

    /// 今天已经计薪的秒数（不含午休）
    var paidElapsed: Double = 0
    /// 距离打卡下班的真实剩余秒数
    var untilClockOut: Double = 0
    /// 距离开始计薪的秒数（未上班时有效）
    var untilClockIn: Double = 0

    var monthEarned: Double = 0
    var monthTarget: Double = 0
    var monthProgress: Double = 0
    var monthWorkdays: Int = 0
    var monthWorkdaysLeft: Int = 0
    var monthLabel: String = ""

    var perSecond: Double = 0
    var perHour: Double = 0

    var now: Date = Date()

    var note: String = ""
    var weekdayText: String = ""
    var dateText: String = ""

    /// 今天本来是工作日，但被标成了请假。
    var isLeave = false
    /// 距本月结束还能再赚多少（含今天的剩余部分）。
    var monthRemaining: Double { max(0, monthTarget - monthEarned) }
}

enum SalaryEngine {
    static let weekdayNames = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]

    /// 0.1 秒刷一次，日历和当月工作日列表都缓存住，不重复构造。
    private static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2
        return c
    }()

    private static var monthKey = ""
    private static var monthDays: [Int] = []

    /// "2026-11-12"，用来记住今天是否请假。
    static func dayKey(_ date: Date = Date(), _ cal: Calendar = calendar) -> String {
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func snapshot(_ s: WorkSettings, at date: Date = Date()) -> SalarySnapshot {
        let cal = calendar
        let comps = cal.dateComponents([.year, .month, .day, .weekday, .hour, .minute, .second], from: date)
        let weekday = comps.weekday ?? 1
        let nowSec = Double((comps.hour ?? 0) * 3600 + (comps.minute ?? 0) * 60 + (comps.second ?? 0))

        var snap = SalarySnapshot()
        snap.now = date
        snap.weekdayText = weekdayNames[(weekday - 1) % 7]
        snap.dateText = "\(comps.month ?? 0) 月 \(comps.day ?? 0) 日"
        snap.todayTarget = s.dailyWage
        snap.perSecond = s.perSecond
        snap.perHour = s.perHour
        snap.monthLabel = "\(comps.year ?? 0) 年 \(comps.month ?? 0) 月"

        let isWorkday = s.workdays.contains(weekday)
        let inS = Double(s.clockIn * 60)
        let brS = Double(s.breakStart * 60)
        let brE = Double(s.breakEnd * 60)
        let outS = Double(s.clockOut * 60)

        // 今日阶段
        let onLeave = s.leaveDays.contains(dayKey(date, cal))
        if !isWorkday || onLeave {
            snap.phase = .restDay
            snap.isLeave = isWorkday && onLeave
        } else if nowSec < inS {
            snap.phase = .beforeWork
            snap.untilClockIn = inS - nowSec
        } else if nowSec >= outS {
            snap.phase = .afterWork
        } else if s.hasBreak && nowSec >= brS && nowSec < brE {
            snap.phase = .onBreak
        } else {
            snap.phase = .working
        }

        // 今日已计薪秒数
        var elapsed: Double = 0
        for seg in s.paidSegments {
            let a = Double(seg.start)
            let b = Double(seg.end)
            elapsed += max(0, min(nowSec, b) - a)
        }
        snap.paidElapsed = elapsed
        snap.todayEarned = min(s.dailyWage, elapsed * s.perSecond)
        snap.todayProgress = s.dailyWage > 0 ? min(1, snap.todayEarned / s.dailyWage) : 0
        snap.untilClockOut = max(0, outS - nowSec)

        // 本月：已过完的工作日按整日计，今天按实时计。请假的日子不算。
        let today = comps.day ?? 1
        let days = workdaysInMonth(containing: date, cal: cal, workdays: s.workdays)
        var earned = 0.0
        var left = 0
        for d in days {
            let key = String(format: "%04d-%02d-%02d", comps.year ?? 0, comps.month ?? 0, d)
            if d == today {
                earned += snap.todayEarned
                if isWorkday && !onLeave { left += 1 }
            } else if s.leaveDays.contains(key) {
                continue
            } else if d < today {
                earned += s.dailyWage
            } else {
                left += 1
            }
        }
        // 一个月按几天计薪：默认取当月工作日数；填了就按填的算（销售、外包常用 21.75）
        let count = s.monthlyDays ?? max(1, days.count)
        let target = Double(count) * s.dailyWage
        snap.monthEarned = earned
        snap.monthTarget = target
        snap.monthProgress = target > 0 ? min(1, earned / target) : 0
        snap.monthWorkdays = count
        snap.monthWorkdaysLeft = max(0, left)
        snap.note = note(for: snap, s: s, isWorkday: isWorkday && !onLeave)
        return snap
    }

    /// 当月所有工作日（返回日号）。同一个月同一个工作日集合只算一次。
    static func workdaysInMonth(containing date: Date, cal: Calendar, workdays: Set<Int>) -> [Int] {
        let c = cal.dateComponents([.year, .month], from: date)
        let key = "\(c.year ?? 0)-\(c.month ?? 0)-\(workdays.sorted())"
        if key == monthKey, !monthDays.isEmpty { return monthDays }

        guard let interval = cal.dateInterval(of: .month, for: date) else { return [] }
        var out: [Int] = []
        var cursor = cal.startOfDay(for: interval.start)
        while cursor < interval.end {
            let wd = cal.component(.weekday, from: cursor)
            if workdays.contains(wd) { out.append(cal.component(.day, from: cursor)) }
            guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        monthKey = key
        monthDays = out
        return out
    }

    /// 一句话情绪价值。按时段与进度切换，不重复堆砌。
    private static func note(for snap: SalarySnapshot, s: WorkSettings, isWorkday: Bool) -> String {
        let money = Fmt.money(snap.todayEarned, decimals: 0)
        switch snap.phase {
        case .restDay:
            if snap.isLeave { return "今天请假。该休息的日子，就不算钱。" }
            return "今天不上班。不被打扰的时间，也是收入的一部分。"
        case .beforeWork:
            return "距离开工还有 \(Fmt.span(snap.untilClockIn))，先把自己照顾好。"
        case .onBreak:
            return "午休是带薪的，\(Fmt.span(snap.untilClockOut)) 之后自由。"
        case .afterWork:
            return "今天 ¥\(money) 已落袋。剩下的时间，属于你自己。"
        case .working:
            if snap.todayProgress < 0.15 { return "开工了。今天的第一杯咖啡，已经赚回来了。" }
            if snap.todayProgress < 0.45 { return "已经 ¥\(money)。稳一点，不必急。" }
            if snap.todayProgress < 0.75 { return "过半了。下午的每一分钟都是净收益。" }
            if snap.todayProgress < 0.95 { return "还剩 \(Fmt.shortSpan(snap.untilClockOut))，胜利在望。" }
            return "最后一小段，收尾漂亮一点。"
        }
    }
}
