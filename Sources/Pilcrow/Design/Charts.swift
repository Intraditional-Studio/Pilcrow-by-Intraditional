import SwiftUI

// MARK: - Weekly focus chart

struct FocusChart: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var days: [DayFocus]
    var goalSeconds: TimeInterval
    var height: CGFloat = 132

    @State private var hovered: DayFocus?
    @State private var appeared = false

    private var maxValue: Double {
        max(goalSeconds, days.map(\.seconds).max() ?? 0, 60)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                MonoLabel(text: hovered == nil ? "focus / minutes" : "focus / \(hovered!.date.formatted(.dateTime.weekday(.wide)))", dot: false)
                Spacer()
                Text(hovered.map { $0.seconds.focusLabel } ?? "\(Int(goalSeconds / 60))m goal")
                    .font(Typeface.mono(10, weight: .medium))
                    .foregroundStyle(hovered == nil ? theme.secondary : theme.ink)
            }

            ZStack(alignment: .bottom) {
                GeometryReader { geo in
                    let goalY = geo.size.height - (goalSeconds / maxValue) * geo.size.height
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: goalY))
                        path.addLine(to: CGPoint(x: geo.size.width, y: goalY))
                    }
                    .stroke(theme.ink.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                }

                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(days) { day in
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(barColor(for: day))
                                .frame(height: barHeight(day))
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .onHover { inside in
                            hovered = inside ? day : nil
                        }
                        .accessibilityElement()
                        .accessibilityLabel("\(day.date.formatted(.dateTime.weekday(.wide))), \(day.seconds.focusLabel), \(day.commits) commits")
                    }
                }
            }
            .frame(height: height)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.45), value: appeared)
            .onAppear { appeared = true }

            HStack(spacing: 8) {
                ForEach(days) { day in
                    Text(day.date.formatted(.dateTime.weekday(.narrow)))
                        .font(Typeface.mono(9, weight: .medium))
                        .foregroundStyle(day.date.isSameDay(as: Date()) ? theme.accent : theme.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func barHeight(_ day: DayFocus) -> CGFloat {
        let ratio = day.seconds / maxValue
        let base = max(3, CGFloat(ratio) * height)
        return appeared || reduceMotion ? base : 3
    }

    private func barColor(for day: DayFocus) -> Color {
        if hovered?.date == day.date { return theme.accent }
        if day.date.isSameDay(as: Date()) { return theme.accent.opacity(0.9) }
        return day.seconds > 0 ? theme.ink.opacity(0.24) : theme.ink.opacity(0.07)
    }
}

// MARK: - Contribution grid

struct ContributionDay: Identifiable {
    var id: Date { date }
    let date: Date
    let seconds: TimeInterval
}

struct ContributionGrid: View {
    @Environment(\.theme) private var theme
    var days: [ContributionDay]
    var weeks: Int = 14

    private let cell: CGFloat = 11
    private let gap: CGFloat = 3

    private var columns: [[ContributionDay]] {
        stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<min($0 + 7, days.count)]) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                MonoLabel(text: "last \(weeks) weeks")
                Spacer()
                Text("less · more")
                    .font(Typeface.mono(9, weight: .regular))
                    .foregroundStyle(theme.secondary)
            }

            HStack(alignment: .top, spacing: gap) {
                ForEach(Array(columns.enumerated()), id: \.offset) { _, week in
                    VStack(spacing: gap) {
                        ForEach(0..<7, id: \.self) { row in
                            if row < week.count {
                                let day = week[row]
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(cellColor(day))
                                    .frame(width: cell, height: cell)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 2)
                                            .strokeBorder(theme.ink.opacity(0.05), lineWidth: 1)
                                    )
                                    .accessibilityLabel("\(day.date.formatted(date: .abbreviated, time: .omitted)): \(day.seconds.focusLabel)")
                            } else {
                                Color.clear.frame(width: cell, height: cell)
                            }
                        }
                    }
                }
            }
        }
    }

    private func cellColor(_ day: ContributionDay) -> Color {
        if day.seconds <= 0 { return theme.ink.opacity(0.055) }
        let level = min(4, max(1, Int((day.seconds / 5400).rounded(.up))))
        return theme.accent.opacity([0.2, 0.38, 0.6, 0.85][level - 1])
    }
}

// MARK: - Goal ring

struct GoalRing<Center: View>: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var progress: Double
    var size: CGFloat = 92
    var lineWidth: CGFloat = 7
    @ViewBuilder var center: Center

    var body: some View {
        ZStack {
            Circle()
                .stroke(theme.ink.opacity(0.09), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(theme.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .timingCurve(0.16, 0.84, 0.16, 1, duration: 0.6), value: progress)
            center
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Daily goal \(Int(progress * 100)) percent complete")
    }
}

// MARK: - Spark bars

struct SparkBars: View {
    @Environment(\.theme) private var theme
    var values: [Double]
    var tint: Color?

    var body: some View {
        let maxValue = max(1, values.max() ?? 1)
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                RoundedRectangle(cornerRadius: 1)
                    .fill(index == values.count - 1 ? (tint ?? theme.accent) : (tint ?? theme.ink).opacity(0.18))
                    .frame(width: 3, height: max(2, CGFloat(value / maxValue) * 28))
            }
        }
        .frame(height: 28, alignment: .bottom)
        .accessibilityHidden(true)
    }
}
