import SwiftUI

struct TokensPreviewGrid: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s8) {
                SectionHeader("Brand ramp")
                SwatchRow(swatches: [
                    .init("50",  "#FDF6E8", Color.tally.brand50),
                    .init("100", "#FAE9C5", Color.tally.brand100),
                    .init("200", "#F4D38C", Color.tally.brand200),
                    .init("300", "#EEBC52", Color.tally.brand300),
                    .init("400★", "#E89B2F", Color.tally.brand400, accent: true),
                    .init("500", "#D4811B", Color.tally.brand500),
                    .init("600", "#B0660E", Color.tally.brand600),
                    .init("700", "#864C07", Color.tally.brand700),
                ])

                SectionHeader("Accent (semantic)")
                SwatchRow(swatches: [
                    .init("accent",       "→ brand-400", Color.tally.accent),
                    .init("accent-hover", "→ brand-500", Color.tally.accentHover),
                    .init("accent-press", "→ brand-600", Color.tally.accentPress),
                    .init("accent-soft",  "α dyn",       Color.tally.accentSoft),
                    .init("accent-on",    "#FFFFFF",     Color.tally.accentOn),
                    .init("focus-ring",   "→ brand-400", Color.tally.focusRing),
                ])

                SectionHeader("Status")
                SwatchRow(swatches: [
                    .init("success-soft",   "#E6F4EA", Color.tally.successSoft),
                    .init("success",        "#2E8B57", Color.tally.success),
                    .init("success-strong", "#1E5E3A", Color.tally.successStrong),
                    .init("warning-soft",   "#FDF1D6", Color.tally.warningSoft),
                    .init("warning",        "#D48417", Color.tally.warning),
                    .init("warning-strong", "#8A530A", Color.tally.warningStrong),
                    .init("danger-soft",    "#FBEAEA", Color.tally.dangerSoft),
                    .init("danger",         "#C8362B", Color.tally.danger),
                    .init("danger-strong",  "#8B221A", Color.tally.dangerStrong),
                ])

                SectionHeader("Warm-neutral ramp")
                SwatchRow(swatches: [
                    .init("0",   "#FFFFFF", Color.tally.n0),
                    .init("25",  "#FCFBF8", Color.tally.n25),
                    .init("50",  "#FAF9F7", Color.tally.n50),
                    .init("100", "#F4F2EC", Color.tally.n100),
                    .init("150", "#EDEAE3", Color.tally.n150),
                    .init("200", "#E8E5DE", Color.tally.n200),
                    .init("300", "#D8D3C8", Color.tally.n300),
                    .init("400", "#BAB3A4", Color.tally.n400),
                    .init("500", "#8E8779", Color.tally.n500),
                    .init("600", "#6B6557", Color.tally.n600),
                    .init("700", "#4A453A", Color.tally.n700),
                    .init("800", "#2E2A22", Color.tally.n800),
                    .init("900", "#1F1C16", Color.tally.n900),
                    .init("950", "#15130F", Color.tally.n950),
                ])

                SectionHeader("Surfaces (dynamic)")
                SwatchRow(swatches: [
                    .init("bg-app",      "dyn", Color.tally.bgApp),
                    .init("bg-sidebar",  "dyn", Color.tally.bgSidebar),
                    .init("bg-card",     "dyn", Color.tally.bgCard),
                    .init("bg-card-alt", "dyn", Color.tally.bgCardAlt),
                    .init("bg-popover",  "α",   Color.tally.bgPopover),
                    .init("bg-hover",    "α",   Color.tally.bgHover),
                    .init("bg-press",    "α",   Color.tally.bgPress),
                    .init("bg-selected", "dyn", Color.tally.bgSelected),
                ])

                SectionHeader("Foregrounds (dynamic)")
                SwatchRow(swatches: [
                    .init("fg-1",   "dyn", Color.tally.fg1,   textColor: Color.tally.bgApp),
                    .init("fg-2",   "dyn", Color.tally.fg2,   textColor: Color.tally.bgApp),
                    .init("fg-3",   "dyn", Color.tally.fg3,   textColor: Color.tally.bgApp),
                    .init("fg-4",   "dyn", Color.tally.fg4,   textColor: Color.tally.bgApp),
                    .init("fg-inv", "dyn", Color.tally.fgInv, textColor: Color.tally.fg1),
                ])

                SectionHeader("Borders & dividers (dynamic)")
                SwatchRow(swatches: [
                    .init("border",        "dyn", Color.tally.border),
                    .init("border-strong", "dyn", Color.tally.borderStrong),
                    .init("divider",       "dyn", Color.tally.divider),
                ])

                SectionHeader("Type scale")
                TypeSamples()

                SectionHeader("Spacing scale")
                SpacingSamples()

                SectionHeader("Radius scale")
                RadiusSamples()

                SectionHeader("Motion")
                MotionSamples()
            }
            .padding(Spacing.s6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 760, height: 1100)
        .background(Color.tally.bgApp)
    }
}

// MARK: - Section header

private struct SectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title.uppercased())
            .font(.tally.micro)
            .tracking(Font.tallyTracking.caps)
            .foregroundStyle(Color.tally.fg3)
    }
}

// MARK: - Swatches

private struct Swatch: Identifiable {
    let id = UUID()
    let label: String
    let hex: String
    let color: Color
    let accent: Bool
    let textColor: Color

    init(
        _ label: String,
        _ hex: String,
        _ color: Color,
        accent: Bool = false,
        textColor: Color? = nil
    ) {
        self.label = label
        self.hex = hex
        self.color = color
        self.accent = accent
        self.textColor = textColor ?? Self.defaultTextColor(forHex: hex)
    }

    private static func defaultTextColor(forHex hex: String) -> Color {
        guard hex.hasPrefix("#"),
              hex.count == 7,
              let value = UInt32(hex.dropFirst(), radix: 16)
        else {
            return Color.tally.fg1
        }

        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        let luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
        return luma > 0.55 ? Color.tally.n900 : Color.tally.n0
    }
}

private struct SwatchRow: View {
    let swatches: [Swatch]
    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: Spacing.s2), count: 8)
        LazyVGrid(columns: columns, alignment: .leading, spacing: Spacing.s2) {
            ForEach(swatches) { s in
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: Radius.r6, style: .continuous)
                        .fill(s.color)
                        .frame(height: 64)
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.r6, style: .continuous)
                                .strokeBorder(s.accent ? Color.tally.fg1 : Color.tally.border, lineWidth: s.accent ? 2 : 0.5)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.label).font(.tally.mono).foregroundStyle(s.textColor)
                        Spacer()
                        Text(s.hex).font(.tally.mono).foregroundStyle(s.textColor.opacity(0.85))
                    }
                    .padding(6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .frame(height: 64)
            }
        }
    }
}

// MARK: - Type

private struct TypeSamples: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s4) {
            sample(".mega", Font.tally.mega, tracking: Font.tallyTracking.mega, text: "12.4")
            sample(".display", Font.tally.display, tracking: Font.tallyTracking.display, text: "GB")
            sample(".title-1", Font.tally.title1, tracking: Font.tallyTracking.title1, text: "本月用了 12.4 GB")
            sample(".title-2", Font.tally.title2, tracking: Font.tallyTracking.title2, text: "Top 10 apps")
            sample(".title-3", Font.tally.title3, tracking: Font.tallyTracking.title3, text: "Section heading")
            sample(".body", Font.tally.body, tracking: Font.tallyTracking.body, text: "這個月用了 12.4 GB 流量")
            sample(".body-em", Font.tally.bodyEm, tracking: Font.tallyTracking.body, text: "強調文字 emphasis text")
            sample(".callout", Font.tally.callout, tracking: Font.tallyTracking.callout, text: "Smaller helper copy")
            sample(".caption", Font.tally.caption, tracking: Font.tallyTracking.caption, text: "Caption / footnote")
            sample(".micro", Font.tally.micro, tracking: Font.tallyTracking.caps, text: "MICRO LABEL")
            sample(".mono", Font.tally.mono, tracking: Font.tallyTracking.mono, text: "10010110.42 KB/s")
        }
    }

    private func sample(_ name: String, _ font: Font, tracking: CGFloat, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.s4) {
            Text(name)
                .font(.tally.mono)
                .foregroundStyle(Color.tally.fg3)
                .frame(width: 80, alignment: .leading)
            Text(text)
                .font(font)
                .tracking(tracking)
                .foregroundStyle(Color.tally.fg1)
        }
    }
}

// MARK: - Spacing

private struct SpacingSamples: View {
    private let items: [(String, CGFloat)] = [
        ("s1 / 4",   Spacing.s1),
        ("s2 / 8",   Spacing.s2),
        ("s3 / 12",  Spacing.s3),
        ("s4 / 16",  Spacing.s4),
        ("s5 / 20",  Spacing.s5),
        ("s6 / 24",  Spacing.s6),
        ("s8 / 32",  Spacing.s8),
        ("s10 / 40", Spacing.s10),
        ("s12 / 48", Spacing.s12),
        ("s16 / 64", Spacing.s16),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            ForEach(items, id: \.0) { name, value in
                HStack(spacing: Spacing.s3) {
                    Text(name)
                        .font(.tally.mono)
                        .foregroundStyle(Color.tally.fg3)
                        .frame(width: 96, alignment: .leading)
                    Rectangle()
                        .fill(Color.tally.brand400)
                        .frame(width: value, height: 12)
                }
            }
        }
    }
}

// MARK: - Radius

private struct RadiusSamples: View {
    private let items: [(String, CGFloat)] = [
        ("r2",   Radius.r2),
        ("r4",   Radius.r4),
        ("r6",   Radius.r6),
        ("r8",   Radius.r8),
        ("r10",  Radius.r10),
        ("r12",  Radius.r12),
        ("full", Radius.full),
    ]

    var body: some View {
        HStack(spacing: Spacing.s4) {
            ForEach(items, id: \.0) { name, value in
                VStack(spacing: Spacing.s2) {
                    RoundedRectangle(cornerRadius: value, style: .continuous)
                        .fill(Color.tally.bgCard)
                        .overlay(
                            RoundedRectangle(cornerRadius: value, style: .continuous)
                                .strokeBorder(Color.tally.border, lineWidth: 1)
                        )
                        .frame(width: 64, height: 48)
                    Text(name).font(.tally.mono).foregroundStyle(Color.tally.fg3)
                }
            }
        }
    }
}

// MARK: - Motion

private struct MotionSamples: View {
    @State private var toggled = false

    private let trackWidth:  CGFloat = 260
    private let circleSize:  CGFloat = 18
    private let trackInset:  CGFloat = 4

    private let items: [(String, Animation)] = [
        ("hover (150ms)",   Motion.hover),
        ("state (200ms)",   Motion.state),
        ("popover (280ms)", Motion.popover),
        ("view (320ms)",    Motion.view),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            Button("Toggle (\(toggled ? "right" : "left"))") {
                toggled.toggle()
            }
            .font(.tally.body)

            ForEach(items, id: \.0) { name, animation in
                HStack(spacing: Spacing.s3) {
                    Text(name)
                        .font(.tally.mono)
                        .foregroundStyle(Color.tally.fg3)
                        .frame(width: 96, alignment: .leading)
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: Radius.r6, style: .continuous)
                            .fill(Color.tally.bgCard)
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.r6, style: .continuous)
                                    .strokeBorder(Color.tally.border, lineWidth: 1)
                            )
                            .frame(height: 24)
                        Circle()
                            .fill(Color.tally.accent)
                            .frame(width: circleSize, height: circleSize)
                            .padding(.leading, toggled ? trackWidth - circleSize - trackInset : trackInset)
                            .animation(animation, value: toggled)
                    }
                    .frame(width: trackWidth)
                }
            }
        }
    }
}

#Preview("Tokens — Light") {
    TokensPreviewGrid().preferredColorScheme(.light)
}

#Preview("Tokens — Dark") {
    TokensPreviewGrid().preferredColorScheme(.dark)
}
