import SwiftUI

/// 展开态：一块正方形的小仪表盘。
struct ExpandedView: View {
    @ObservedObject var model: AppModel

    private var p: Palette { model.palette }
    private var snap: SalarySnapshot { model.snap }

    var body: some View {
        ZStack {
            if model.showSettings {
                SettingsView(model: model)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity
                    ))
            } else {
                dashboard
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .leading)),
                        removal: .opacity
                    ))
            }

            if let milestone = model.milestone {
                MilestoneToast(text: milestone, palette: p)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .frame(width: Metrics.expandedSize.width, height: Metrics.expandedSize.height)
        .background(CardBackground(palette: p, corner: Metrics.cornerExpanded))
        .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerExpanded, style: .continuous))
    }

    // MARK: - Dashboard

    private var dashboard: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Spacer().frame(height: 15)

            hero

            Spacer().frame(height: 9)

            progressBlock

            Spacer().frame(height: 13)

            HStack(spacing: 7) {
                StatTile(title: "时薪", value: "¥" + Fmt.money(snap.perHour, decimals: 1), palette: p)
                StatTile(title: "每秒", value: "¥" + Fmt.money(snap.perSecond, decimals: 3), palette: p)
                StatTile(title: clockValueTitle, value: clockValue, palette: p)
            }

            Spacer().frame(height: 13)

            monthBlock

            Spacer(minLength: 10)

            noteRow
        }
        .padding(Metrics.padding)
    }

    private var header: some View {
        HStack(spacing: 7) {
            Text(snap.dateText)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(p.subtext)
            Text(snap.weekdayText)
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(p.faint)

            PhaseChip(phase: snap.phase, palette: p)

            Spacer(minLength: 0)

            GhostButton(symbol: "slider.horizontal.3", palette: p, size: 21) {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    model.showSettings = true
                }
            }
            GhostButton(symbol: "chevron.up", palette: p, size: 21) {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                    model.isExpanded = false
                }
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(heroCaption)
                .font(.system(size: 9.5, weight: .semibold))
                .tracking(1.1)
                .foregroundStyle(p.faint)

            HeroMoney(value: snap.todayEarned, palette: p, wholeSize: 44)
                .padding(.top, 2)
        }
    }

    private var heroCaption: String {
        switch snap.phase {
        case .restDay: return "今日不必计薪"
        case .beforeWork: return "今日尚未开始"
        default: return "今日已入账"
        }
    }

    private var progressBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            WageBar(progress: snap.todayProgress, palette: p, height: 5)

            HStack {
                Text("\(Fmt.percent(snap.todayProgress)) · ¥\(Fmt.money(snap.todayEarned, decimals: 0)) / ¥\(Fmt.money(snap.todayTarget, decimals: 0))")
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(p.subtext)

                Spacer(minLength: 4)

                Text(tailText)
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(p.gold.opacity(0.85))
            }
        }
    }

    private var tailText: String {
        switch snap.phase {
        case .beforeWork:
            return "\(Fmt.shortSpan(snap.untilClockIn)) 后开工"
        case .working, .onBreak:
            return "还有 \(Fmt.shortSpan(snap.untilClockOut))"
        case .afterWork:
            return "满勤"
        case .restDay:
            return "—"
        }
    }

    private var clockValueTitle: String {
        switch snap.phase {
        case .beforeWork: return "距开工"
        case .working, .onBreak: return "距下班"
        case .afterWork: return "今日工时"
        case .restDay: return "已休息"
        }
    }

    private var clockValue: String {
        switch snap.phase {
        case .beforeWork: return Fmt.shortSpan(snap.untilClockIn)
        case .working, .onBreak: return Fmt.shortSpan(snap.untilClockOut)
        case .afterWork: return Fmt.shortSpan(model.settings.paidSeconds)
        case .restDay: return "—"
        }
    }

    private var monthBlock: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("本月")
                    .font(.system(size: 9.5, weight: .semibold))
                    .tracking(1.0)
                    .foregroundStyle(p.faint)

                Text("¥" + Fmt.money(snap.monthEarned, decimals: 0))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(p.text.opacity(0.95))
                    .monospacedDigit()

                Text("/ ¥" + Fmt.money(snap.monthTarget, decimals: 0))
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(p.faint)

                Spacer(minLength: 0)

                Text("剩 \(snap.monthWorkdaysLeft) 个工作日")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(p.faint)
            }

            WageBar(progress: snap.monthProgress, palette: p, height: 3)
        }
    }

    private var noteRow: some View {
        HStack(alignment: .top, spacing: 7) {
            RoundedRectangle(cornerRadius: 1)
                .fill(
                    LinearGradient(
                        colors: [p.gold.opacity(0.7), p.gold.opacity(0.08)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 1.5, height: 22)

            Text(snap.note)
                .font(.system(size: 10.5, weight: .regular))
                .foregroundStyle(p.subtext)
                .lineSpacing(2.5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// 里程碑飘字，短暂出现后自己消失。
struct MilestoneToast: View {
    let text: String
    let palette: Palette

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(palette.isDark ? Color(hex: 0x0A0B0F) : .white)
            .padding(.horizontal, 11)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(
                    LinearGradient(
                        colors: [palette.goldBright, palette.gold],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            )
            .shadow(color: palette.gold.opacity(0.5), radius: 10, y: 3)
            .padding(.top, 54)
    }
}
