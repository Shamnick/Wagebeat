import SwiftUI

/// 收起态：一枚小小的长条，像安静的桌面饰品。
struct CompactView: View {
    @ObservedObject var model: AppModel
    @State private var hovering = false

    private var p: Palette { model.palette }
    private var snap: SalarySnapshot { model.snap }

    var body: some View {
        let parts = Fmt.splitMoney(snap.todayEarned)

        Button {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                model.isExpanded = true
            }
        } label: {
            HStack(spacing: 10) {
                ProgressRing(progress: snap.todayProgress, palette: p, size: 25, lineWidth: 2.5)

                HStack(alignment: .firstTextBaseline, spacing: 0.5) {
                    Text("¥")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(p.gold.opacity(0.75))
                        .baselineOffset(5)
                    Text(parts.whole)
                        .font(.system(size: 19, weight: .semibold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [p.gold, p.glowB],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text("." + parts.fraction)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(p.subtext)
                }
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)

                Spacer(minLength: 4)

                HStack(spacing: 4) {
                    if snap.phase == .working || snap.phase == .onBreak {
                        Text(Fmt.shortSpan(snap.untilClockOut))
                            .font(.system(size: 9.5, weight: .medium, design: .rounded))
                            .foregroundStyle(p.subtext.opacity(0.9))
                            .monospacedDigit()
                            .fixedSize()
                    }
                    Circle()
                        .fill(statusColor)
                        .frame(width: 5, height: 5)
                        .shadow(color: statusColor.opacity(0.9), radius: 4)
                }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                CardBackground(palette: p, corner: Metrics.cornerCompact)
                    .opacity(hovering ? 1 : 0.94)
            )
            .overlay(alignment: .bottom) {
                // 底部一线极细的进度，收起时也能“看见”时间在走
                GeometryReader { geo in
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [p.gold.opacity(0.15), p.gold, p.goldBright],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geo.size.width * snap.todayProgress), height: 1.6)
                        .shadow(color: p.gold.opacity(0.5), radius: 3)
                }
                .frame(height: 1.6)
                .padding(.horizontal, 16)
                .padding(.bottom, 6.5)
                .opacity(snap.todayProgress > 0.01 ? 1 : 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("点击展开 · 拖动可吸附到任意位置")
    }

    private var statusColor: Color {
        switch snap.phase {
        case .working: return p.working
        case .onBreak: return p.resting
        case .beforeWork, .afterWork: return p.gold
        case .restDay: return p.idle
        }
    }
}
