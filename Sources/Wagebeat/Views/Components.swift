import SwiftUI

/// 卡片底：多层渐变 + 两团主题色柔光 + 顶部高光描边。
struct CardBackground: View {
    let palette: Palette
    let corner: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
        shape
            .fill(
                LinearGradient(
                    colors: [palette.top, palette.bottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                // 左上柔光：主题亮色
                RadialGradient(
                    colors: [palette.glowA.opacity(palette.isDark ? 0.18 : 0.34), .clear],
                    center: UnitPoint(x: 0.05, y: -0.02),
                    startRadius: 2,
                    endRadius: 210
                )
                .clipShape(shape)
            )
            .overlay(
                // 右下柔光：主题副色，负责"炫彩"
                RadialGradient(
                    colors: [palette.glowB.opacity(palette.isDark ? 0.16 : 0.30), .clear],
                    center: UnitPoint(x: 1.0, y: 1.02),
                    startRadius: 2,
                    endRadius: 200
                )
                .clipShape(shape)
            )
            .overlay(
                // 中下方一层极淡的主色，让渐变过渡不死
                RadialGradient(
                    colors: [palette.gold.opacity(palette.isDark ? 0.06 : 0.10), .clear],
                    center: UnitPoint(x: 0.55, y: 0.65),
                    startRadius: 2,
                    endRadius: 150
                )
                .clipShape(shape)
            )
            .overlay(
                shape.strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(palette.isDark ? 0.20 : 0.95),
                            Color.white.opacity(palette.isDark ? 0.04 : 0.22),
                            palette.glowB.opacity(palette.isDark ? 0.05 : 0.22)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.9
                )
            )
            .shadow(color: palette.gold.opacity(palette.isDark ? 0.10 : 0.16), radius: 16, y: 8)
            .shadow(color: .black.opacity(palette.isDark ? 0.40 : 0.10), radius: 5, y: 2)
    }
}

/// 细环进度。紧凑态用来替代文字，一眼看出今天走了多少。
struct ProgressRing: View {
    let progress: Double
    let palette: Palette
    var size: CGFloat = 26
    var lineWidth: CGFloat = 2.6

    var body: some View {
        ZStack {
            Circle()
                .stroke(palette.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(
                    AngularGradient(
                        colors: [palette.gold.opacity(0.45), palette.goldBright, palette.glowB, palette.gold],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: palette.glowB.opacity(0.5), radius: 3)
        }
        .frame(width: size, height: size)
    }
}

/// 主进度条：细、带金色光点，刻度极克制。
struct WageBar: View {
    let progress: Double
    let palette: Palette
    var height: CGFloat = 5

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let p = max(0, min(1, progress))
            ZStack(alignment: .leading) {
                Capsule().fill(palette.track)

                ForEach([0.25, 0.5, 0.75], id: \.self) { t in
                    Rectangle()
                        .fill(palette.faint.opacity(0.55))
                        .frame(width: 1, height: height + 3)
                        .offset(x: w * t - 0.5)
                }

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [palette.gold, palette.goldBright, palette.glowB],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(height, w * p))
                    .shadow(color: palette.gold.opacity(0.45), radius: 5)

                Circle()
                    .fill(palette.goldBright)
                    .frame(width: height + 2, height: height + 2)
                    .shadow(color: palette.glowB.opacity(0.9), radius: 6)
                    .offset(x: max(0, w * p - (height + 2) / 2))
                    .opacity(p > 0.002 ? 1 : 0)
            }
            .frame(height: height)
        }
        .frame(height: height)
    }
}

/// 小图标按钮，悬停时浮起。
struct GhostButton: View {
    let symbol: String
    let palette: Palette
    var size: CGFloat = 22
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(hovering ? palette.text : palette.subtext)
                .frame(width: size, height: size)
                .background(
                    Circle().fill(palette.text.opacity(hovering ? 0.10 : 0))
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// 阶段小胶囊：一个呼吸的圆点 + 文案。
struct PhaseChip: View {
    let phase: DayPhase
    let palette: Palette

    private var color: Color {
        switch phase {
        case .working: return palette.working
        case .onBreak: return palette.resting
        case .beforeWork, .afterWork: return palette.gold
        case .restDay: return palette.idle
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
                .shadow(color: color.opacity(0.9), radius: 4)
            Text(phase.label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(palette.subtext)
                .fixedSize()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(palette.text.opacity(0.055))
        )
        .overlay(
            Capsule().strokeBorder(palette.stroke, lineWidth: 0.7)
        )
    }
}

/// 底部统计小块。
struct StatTile: View {
    let title: String
    let value: String
    let palette: Palette

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 8.5, weight: .medium))
                .foregroundStyle(palette.faint)
                .fixedSize()
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(palette.text.opacity(0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(palette.tile)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(palette.stroke, lineWidth: 0.7)
        )
    }
}

/// 金额主展示：整数位大、小数位小，金色渐变。
struct HeroMoney: View {
    let value: Double
    let palette: Palette
    var wholeSize: CGFloat = 44

    var body: some View {
        let parts = Fmt.splitMoney(value)
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            Text("¥")
                .font(.system(size: wholeSize * 0.46, weight: .medium, design: .rounded))
                .foregroundStyle(palette.gold.opacity(0.75))
                .baselineOffset(wholeSize * 0.28)

            Text(parts.whole)
                .font(.system(size: wholeSize, weight: .semibold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [palette.goldBright, palette.gold, palette.glowB],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("." + parts.fraction)
                .font(.system(size: wholeSize * 0.44, weight: .medium, design: .rounded))
                .foregroundStyle(palette.gold.opacity(0.62))
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.55)
        .shadow(color: palette.gold.opacity(palette.isDark ? 0.28 : 0.12), radius: 12, y: 2)
    }
}
