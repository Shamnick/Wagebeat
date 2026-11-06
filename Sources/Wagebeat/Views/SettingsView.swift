import SwiftUI

/// 设置页：为了塞进正方形面板，统一用「左标签 / 右控件」的单行布局，
/// 不再有滚动，避免任何裁剪风险。
struct SettingsView: View {
    @ObservedObject var model: AppModel

    private var p: Palette { model.palette }
    private var s: WorkSettings { model.settings }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Spacer(minLength: 10)

            VStack(spacing: 11) {
                wageRow
                timeRow
                breakRow
                weekdayRow
                themeRow
            }

            Spacer(minLength: 10)

            footer
        }
        .padding(Metrics.padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 7) {
            GhostButton(symbol: "chevron.left", palette: p, size: 21) {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    model.showSettings = false
                }
            }

            Text("设置")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(p.text)

            Spacer(minLength: 0)

            GhostButton(symbol: s.pinned ? "pin.fill" : "pin.slash", palette: p, size: 21) {
                model.update { $0.pinned.toggle() }
                PanelController.shared.applyPin()
            }
            .help(s.pinned ? "已置顶，点击取消" : "未置顶，点击置顶")

            GhostButton(symbol: "arrow.counterclockwise", palette: p, size: 21) {
                withAnimation { model.update { $0 = WorkSettings() } }
            }
            .help("恢复默认")

            GhostButton(symbol: "chevron.up", palette: p, size: 21) {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                    model.isExpanded = false
                }
            }
        }
    }

    // MARK: - Rows

    private var wageRow: some View {
        row("日薪") {
            HStack(spacing: 2) {
                Text("¥" + Fmt.money(s.dailyWage, decimals: 0))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(p.text)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                GhostButton(symbol: "minus", palette: p, size: 19) { model.bumpWage(-10) }
                GhostButton(symbol: "plus", palette: p, size: 19) { model.bumpWage(10) }
            }
        }
    }

    private var timeRow: some View {
        row("上下班") {
            HStack(spacing: 5) {
                TimeChip(minutes: s.clockIn, palette: p) {
                    model.update { $0.clockIn = wrap($0.clockIn + 30) }
                }
                Text("—")
                    .font(.system(size: 9))
                    .foregroundStyle(p.faint)
                TimeChip(minutes: s.clockOut, palette: p) {
                    model.update { $0.clockOut = wrap($0.clockOut + 30) }
                }
            }
        }
    }

    private var breakRow: some View {
        row("午休") {
            HStack(spacing: 5) {
                MiniSwitch(on: s.hasBreak, palette: p) {
                    model.update { $0.hasBreak.toggle() }
                }
                if s.hasBreak {
                    TimeChip(minutes: s.breakStart, palette: p) {
                        model.update { $0.breakStart = wrap($0.breakStart + 30) }
                    }
                    Text("—")
                        .font(.system(size: 9))
                        .foregroundStyle(p.faint)
                    TimeChip(minutes: s.breakEnd, palette: p) {
                        model.update { $0.breakEnd = wrap($0.breakEnd + 30) }
                    }
                } else {
                    Text("连续计薪")
                        .font(.system(size: 9))
                        .foregroundStyle(p.faint)
                }
            }
        }
    }

    private var weekdayRow: some View {
        row("工作日") {
            HStack(spacing: 3) {
                ForEach([2, 3, 4, 5, 6, 7, 1], id: \.self) { wd in
                    DayDot(
                        label: String(SalaryEngine.weekdayNames[wd - 1].suffix(1)),
                        active: s.workdays.contains(wd),
                        palette: p
                    ) {
                        model.update { st in
                            if st.workdays.contains(wd) {
                                if st.workdays.count > 1 { st.workdays.remove(wd) }
                            } else {
                                st.workdays.insert(wd)
                            }
                        }
                    }
                }
            }
        }
    }

    private var themeRow: some View {
        row("主题") {
            HStack(spacing: 0) {
                HStack(spacing: 6) {
                    ForEach(ThemeID.allCases, id: \.self) { id in
                        ThemeSwatch(id: id, active: s.theme == id, palette: p) {
                            withAnimation(.easeInOut(duration: 0.26)) {
                                model.update { $0.theme = id }
                            }
                        }
                    }
                }

                Spacer(minLength: 6)

                Text(s.theme.title)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(p.subtext)
                    .contentTransition(.opacity)
                    .frame(width: 24, alignment: .trailing)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Rectangle()
                .fill(p.stroke)
                .frame(height: 0.7)

            HStack(spacing: 0) {
                Text("\(Fmt.shortSpan(s.paidSeconds)) / 天 · 时薪 ¥\(Fmt.money(s.perHour, decimals: 1))")
                    .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(p.faint)
                Spacer(minLength: 0)
                Text("v1.1")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(p.faint.opacity(0.6))
            }
        }
    }

    // MARK: - Helpers

    private func row<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(p.faint)
                .frame(width: 42, alignment: .leading)
            Spacer(minLength: 0)
            content()
        }
        .frame(height: 26)
    }

    private func wrap(_ m: Int) -> Int { (m % (24 * 60) + 24 * 60) % (24 * 60) }
}

/// 更小的开关，和整体排版同一套材质。
struct MiniSwitch: View {
    let on: Bool
    let palette: Palette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Capsule()
                .fill(on ? palette.gold.opacity(0.85) : palette.track)
                .frame(width: 24, height: 13)
                .overlay(alignment: on ? .trailing : .leading) {
                    Circle()
                        .fill(on ? (palette.isDark ? Color(hex: 0x0A0B0F) : .white) : palette.subtext)
                        .frame(width: 9, height: 9)
                        .padding(.horizontal, 2)
                }
                .overlay(
                    Capsule().strokeBorder(palette.stroke, lineWidth: 0.7)
                )
                .animation(.spring(response: 0.24, dampingFraction: 0.8), value: on)
        }
        .buttonStyle(.plain)
    }
}

struct TimeChip: View {
    let minutes: Int
    let palette: Palette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(Fmt.formatMinutes(minutes))
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundStyle(palette.text.opacity(0.92))
                .contentTransition(.numericText())
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous).fill(palette.tile)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(palette.stroke, lineWidth: 0.7)
                )
        }
        .buttonStyle(.plain)
        .help("点击 +30 分钟")
    }
}

struct DayDot: View {
    let label: String
    let active: Bool
    let palette: Palette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(active ? (palette.isDark ? Color(hex: 0x0A0B0F) : .white) : palette.faint)
                .frame(width: 18, height: 18)
                .background(Circle().fill(active ? palette.gold : .clear))
                .overlay(
                    Circle().strokeBorder(active ? .clear : palette.stroke, lineWidth: 0.7)
                )
        }
        .buttonStyle(.plain)
    }
}

struct ThemeSwatch: View {
    let id: ThemeID
    let active: Bool
    let palette: Palette
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        let target = Palette.of(id)
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [target.top, target.bottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [target.goldBright, target.gold],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 6.5, height: 6.5)
            }
            .frame(width: 17, height: 17)
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(
                        active ? target.gold.opacity(0.9) : palette.stroke,
                        lineWidth: active ? 1.4 : 0.7
                    )
            )
            .shadow(color: target.gold.opacity(active ? 0.45 : 0), radius: 5)
            .scaleEffect(hovering ? 1.12 : 1)
            .animation(.spring(response: 0.26, dampingFraction: 0.7), value: active)
            .animation(.easeOut(duration: 0.15), value: hovering)
            .frame(width: 21, height: 21)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(id.title)
    }
}
