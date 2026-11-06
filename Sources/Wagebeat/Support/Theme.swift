import SwiftUI

/// 主题全部是浅色系，每个主题自带一组渐变主色（accent），
/// 背景、描边、光斑都由主色派生，切换时整块面板一起变。
enum ThemeID: String, Codable, CaseIterable {
    case aurora
    case peach
    case lilac
    case mint
    case pearl
    case ink

    var title: String {
        switch self {
        case .aurora: return "极光"
        case .peach: return "蜜桃"
        case .lilac: return "香芋"
        case .mint: return "薄荷"
        case .pearl: return "珍珠"
        case .ink: return "曜石"
        }
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

/// 一套配色。所有视图都只按语义槽位取色，不判断具体主题。
/// `gold` / `goldBright` / `goldDim` 是历史命名，现在代表「主色 / 主色亮部 / 主色淡影」。
struct Palette {
    let id: ThemeID

    let top: Color
    let bottom: Color
    let text: Color
    let subtext: Color
    let faint: Color

    let gold: Color
    let goldBright: Color
    let goldDim: Color

    /// 背景上的两团柔光，负责"炫彩"的观感
    let glowA: Color
    let glowB: Color

    let stroke: Color
    let track: Color
    let tile: Color

    let working: Color
    let resting: Color
    let idle: Color

    var isDark: Bool { id == .ink }

    /// 主色渐变，供进度条、图标等高光部件使用
    var accentGradient: LinearGradient {
        LinearGradient(colors: [goldBright, gold], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static let aurora = Palette(
        id: .aurora,
        top: Color(hex: 0xFBFCFF),
        bottom: Color(hex: 0xE7EDFF),
        text: Color(hex: 0x1A1C2B),
        subtext: Color(hex: 0x1A1C2B, alpha: 0.56),
        faint: Color(hex: 0x1A1C2B, alpha: 0.30),
        gold: Color(hex: 0x6C63F0),
        goldBright: Color(hex: 0x4FC3F7),
        goldDim: Color(hex: 0x6C63F0, alpha: 0.14),
        glowA: Color(hex: 0x7E6BFF),
        glowB: Color(hex: 0x6FD8FF),
        stroke: Color(hex: 0x2B2F55, alpha: 0.09),
        track: Color(hex: 0x2B2F55, alpha: 0.09),
        tile: Color.white.opacity(0.55),
        working: Color(hex: 0x2AA7A0),
        resting: Color(hex: 0xF08A5D),
        idle: Color(hex: 0x8B90A8)
    )

    static let peach = Palette(
        id: .peach,
        top: Color(hex: 0xFFFBF8),
        bottom: Color(hex: 0xFFE7DC),
        text: Color(hex: 0x2C1B16),
        subtext: Color(hex: 0x2C1B16, alpha: 0.56),
        faint: Color(hex: 0x2C1B16, alpha: 0.30),
        gold: Color(hex: 0xF2714E),
        goldBright: Color(hex: 0xFFB25E),
        goldDim: Color(hex: 0xF2714E, alpha: 0.14),
        glowA: Color(hex: 0xFF8A6B),
        glowB: Color(hex: 0xFFC96B),
        stroke: Color(hex: 0x6B3A28, alpha: 0.10),
        track: Color(hex: 0x6B3A28, alpha: 0.09),
        tile: Color.white.opacity(0.58),
        working: Color(hex: 0x2E9E72),
        resting: Color(hex: 0xD9822B),
        idle: Color(hex: 0x9C8B85)
    )

    static let lilac = Palette(
        id: .lilac,
        top: Color(hex: 0xFDFAFF),
        bottom: Color(hex: 0xF0E2FF),
        text: Color(hex: 0x231A33),
        subtext: Color(hex: 0x231A33, alpha: 0.56),
        faint: Color(hex: 0x231A33, alpha: 0.30),
        gold: Color(hex: 0x9A6BF0),
        goldBright: Color(hex: 0xE68BE0),
        goldDim: Color(hex: 0x9A6BF0, alpha: 0.14),
        glowA: Color(hex: 0xA97BFF),
        glowB: Color(hex: 0xFF9BD5),
        stroke: Color(hex: 0x3D2A5C, alpha: 0.09),
        track: Color(hex: 0x3D2A5C, alpha: 0.09),
        tile: Color.white.opacity(0.55),
        working: Color(hex: 0x3C9F86),
        resting: Color(hex: 0xC97B3E),
        idle: Color(hex: 0x958CA8)
    )

    static let mint = Palette(
        id: .mint,
        top: Color(hex: 0xF8FFFC),
        bottom: Color(hex: 0xDBF5EC),
        text: Color(hex: 0x14231F),
        subtext: Color(hex: 0x14231F, alpha: 0.56),
        faint: Color(hex: 0x14231F, alpha: 0.30),
        gold: Color(hex: 0x18B98A),
        goldBright: Color(hex: 0x7DE8B8),
        goldDim: Color(hex: 0x18B98A, alpha: 0.14),
        glowA: Color(hex: 0x3AD6A8),
        glowB: Color(hex: 0xA8E86B),
        stroke: Color(hex: 0x18362E, alpha: 0.09),
        track: Color(hex: 0x18362E, alpha: 0.09),
        tile: Color.white.opacity(0.55),
        working: Color(hex: 0x10997A),
        resting: Color(hex: 0xD08A35),
        idle: Color(hex: 0x88978F)
    )

    static let pearl = Palette(
        id: .pearl,
        top: Color(hex: 0xFCFBF7),
        bottom: Color(hex: 0xEDE7DA),
        text: Color(hex: 0x1B1D22),
        subtext: Color(hex: 0x1B1D22, alpha: 0.55),
        faint: Color(hex: 0x1B1D22, alpha: 0.30),
        gold: Color(hex: 0xA87B32),
        goldBright: Color(hex: 0xD8B36A),
        goldDim: Color(hex: 0xA87B32, alpha: 0.14),
        glowA: Color(hex: 0xE8C786),
        glowB: Color(hex: 0xC7D6E8),
        stroke: Color.black.opacity(0.09),
        track: Color.black.opacity(0.09),
        tile: Color.white.opacity(0.5),
        working: Color(hex: 0x2E9E72),
        resting: Color(hex: 0xC07B26),
        idle: Color(hex: 0x8C9099)
    )

    static let ink = Palette(
        id: .ink,
        top: Color(hex: 0x191C23),
        bottom: Color(hex: 0x0A0B0F),
        text: Color(hex: 0xF6F2E9),
        subtext: Color(hex: 0xF6F2E9, alpha: 0.56),
        faint: Color(hex: 0xF6F2E9, alpha: 0.28),
        gold: Color(hex: 0xE9C787),
        goldBright: Color(hex: 0xF8E7C2),
        goldDim: Color(hex: 0xE9C787, alpha: 0.16),
        glowA: Color(hex: 0xE9C787),
        glowB: Color(hex: 0x5C7ACC),
        stroke: Color.white.opacity(0.085),
        track: Color.white.opacity(0.085),
        tile: Color.white.opacity(0.045),
        working: Color(hex: 0x6FE3AE),
        resting: Color(hex: 0xF2B76A),
        idle: Color(hex: 0x8B909B)
    )

    static func of(_ id: ThemeID) -> Palette {
        switch id {
        case .aurora: return .aurora
        case .peach: return .peach
        case .lilac: return .lilac
        case .mint: return .mint
        case .pearl: return .pearl
        case .ink: return .ink
        }
    }
}

enum Metrics {
    /// 卡片本身的尺寸。视图按这个尺寸布局、离屏渲染也用它。
    static let compactSize = CGSize(width: 186, height: 46)
    static let expandedSize = CGSize(width: 330, height: 330)
    static let cornerCompact: CGFloat = 15
    static let cornerExpanded: CGFloat = 26
    static let padding: CGFloat = 20

    /// 窗口在卡片四周留出的透明留白，用来容纳卡片自己画的柔和投影。
    /// 关掉系统窗口阴影后，边缘就不会再出现那圈灰黑色描边。
    static let windowInset: CGFloat = 20

    // MARK: - 自由缩放范围

    static let minCompactWidth: CGFloat = 160
    static let maxCompactWidth: CGFloat = 460
    static let minExpandedWidth: CGFloat = 270
    static let maxExpandedWidth: CGFloat = 560
    static let minExpandedHeight: CGFloat = 340
    static let maxExpandedHeight: CGFloat = 400

    /// 收起态窄到这个宽度以下就藏起「距下班」，只留金额和状态点。
    static let compactTimeThreshold: CGFloat = 182
    /// 拉过这条线就换成本月累计，空间不浪费。
    static let compactMonthThreshold: CGFloat = 300

    static func clampCompactWidth(_ v: CGFloat) -> CGFloat {
        min(max(v, minCompactWidth), maxCompactWidth)
    }

    static func clampExpandedWidth(_ v: CGFloat) -> CGFloat {
        min(max(v, minExpandedWidth), maxExpandedWidth)
    }

    static func clampExpandedHeight(_ v: CGFloat) -> CGFloat {
        min(max(v, minExpandedHeight), maxExpandedHeight)
    }

    static let compactWindow = compactWindow(width: compactSize.width)
    static let expandedWindow = expandedWindow(width: expandedSize.width, height: expandedSize.height)

    static func compactWindow(width: CGFloat) -> CGSize {
        CGSize(width: width + windowInset * 2, height: compactSize.height + windowInset * 2)
    }

    static func expandedWindow(width: CGFloat, height: CGFloat) -> CGSize {
        CGSize(width: width + windowInset * 2, height: height + windowInset * 2)
    }

    /// 圆角随尺寸轻微放大，大卡片不会显得太方。
    static func corner(forCompactWidth w: CGFloat) -> CGFloat {
        let t = (w - minCompactWidth) / max(1, maxCompactWidth - minCompactWidth)
        return cornerCompact + min(max(t, 0), 1) * 7
    }
}
