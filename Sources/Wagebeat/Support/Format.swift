import Foundation

enum Fmt {
    static func money(_ value: Double, decimals: Int = 2) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = decimals
        f.maximumFractionDigits = decimals
        f.groupingSeparator = ","
        f.usesGroupingSeparator = true
        return f.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    /// 把金额拆成整数位与小数位，方便用两种字号排版。
    static func splitMoney(_ value: Double) -> (whole: String, fraction: String) {
        let parts = money(value).split(separator: ".", omittingEmptySubsequences: false)
        return (String(parts.first ?? "0"), parts.count > 1 ? String(parts[1]) : "00")
    }

    static func formatMinutes(_ minutes: Int) -> String {
        String(format: "%02d:%02d", (minutes / 60) % 24, minutes % 60)
    }

    /// 秒 -> "3 小时 41 分" / "41 分" / "0 分"
    static func span(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 && m > 0 { return "\(h) 小时 \(m) 分" }
        if h > 0 { return "\(h) 小时" }
        return "\(m) 分"
    }

    /// 秒 -> "2h 17m"，用于紧凑排版
    static func shortSpan(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}
