import SwiftUI

/// 收起态：一枚小小的长条，像安静的桌面饰品。
struct CompactView: View {
    @ObservedObject var model: AppModel
    @State private var hovering = false

    private var p: Palette { model.palette }
    private var snap: SalarySnapshot { model.snap }

    var body: some View {
        let parts = Fmt.splitMoney(snap.todayEarned)

        ZStack(alignment: .bottomTrailing) {
            Button {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                    model.isExpanded = true
                }
            } label: {
                HStack(spacing: 10) {
                    ProgressRing(progress: snap.todayProgress, palette: p, size: 25, lineWidth: 2.5)

                    HStack(alignment: .firstTextBaseline, spacing: 0.5) {
                        Text("¥")
                            .font(.system(size: 10 * moneyScale, weight: .medium, design: .rounded))
                            .foregroundStyle(p.gold.opacity(0.75))
                            .baselineOffset(5)
                        Text(parts.whole)
                            .font(.system(size: 19 * moneyScale, weight: .semibold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [p.gold, p.glowB],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Text("." + parts.fraction)
                            .font(.system(size: 10 * moneyScale, weight: .medium, design: .rounded))
                            .foregroundStyle(p.subtext)
                    }
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                    Spacer(minLength: 4)

                    HStack(spacing: 4) {
                        if showsMonth {
                            Text("本月 ¥" + Fmt.money(snap.monthEarned, decimals: 0))
                                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                                .foregroundStyle(p.subtext.opacity(0.85))
                                .monospacedDigit()
                                .fixedSize()
                                .padding(.trailing, 3)
                        }
                        if showsRemaining, snap.phase == .working || snap.phase == .onBreak {
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
                    // 给右下角的手柄让出位置，文字不会压到手柄上
                    .padding(.trailing, 8)
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    CardBackground(palette: p, corner: corner)
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

            ResizeGrip(palette: p, lit: hovering)
                .padding(5)
                .opacity(hovering ? 1 : 0.45)
        }
        .onHover { hovering = $0 }
        .help("点击展开 · 拖动可吸附到任意位置 · 右下角拖拽调整宽度")
    }

    private var corner: CGFloat {
        Metrics.corner(forCompactWidth: model.compactCardSize.width)
    }

    /// 宽度分三档：极窄只看钱，中等看距下班，拉宽后换成本月累计。
    private var showsRemaining: Bool {
        let w = model.compactCardSize.width
        return w >= Metrics.compactTimeThreshold && w < Metrics.compactMonthThreshold
    }

    private var showsMonth: Bool {
        model.compactCardSize.width >= Metrics.compactMonthThreshold
    }

    /// 卡片拉宽后金额也略微长大，视觉上不至于空荡。
    private var moneyScale: CGFloat {
        let w = model.compactCardSize.width
        let t = (w - Metrics.minCompactWidth) / max(1, Metrics.maxCompactWidth - Metrics.minCompactWidth)
        return 0.94 + min(max(t, 0), 1) * 0.2
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
