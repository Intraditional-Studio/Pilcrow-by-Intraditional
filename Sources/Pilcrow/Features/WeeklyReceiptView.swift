import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// A designed, shareable summary of one week. The same content is available as
/// a PNG (rendered off-screen at 2×) and as Markdown for a standup or a note.
struct WeeklyReceiptView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    var weekOffset: Int

    @State private var exportedMessage: String?

    private var week: WeekSummary { store.week(offset: weekOffset) }
    private var days: [DayFocus] { store.days(offset: weekOffset) }
    private var insights: ReportInsights {
        ReportInsights(sessions: week.sessions, previous: store.week(offset: weekOffset - 1).sessions)
    }
    private var dateRange: String {
        guard let first = days.first?.date, let last = days.last?.date else { return "" }
        return "\(first.formatted(.dateTime.month(.abbreviated).day())) – \(last.formatted(.dateTime.month(.abbreviated).day()))"
    }
    private var bestDay: DayFocus? {
        guard let best = days.max(by: { $0.seconds < $1.seconds }), best.seconds > 0 else { return nil }
        return best
    }
    private var topRepos: [(repo: Repository, commits: Int)] {
        var counts: [String: Int] = [:]
        for session in week.sessions {
            for event in session.events where event.kind == .commit {
                counts[event.repoID, default: 0] += 1
            }
        }
        return counts.compactMap { id, count in
            store.repository(withID: id).map { ($0, count) }
        }.sorted { $0.1 > $1.1 }.prefix(3).map { $0 }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                receiptCard
                    .padding(26)
            }
            .frame(maxHeight: .infinity)

            Hairline()

            HStack(spacing: 10) {
                if let exportedMessage {
                    Text(exportedMessage)
                        .font(Typeface.mono(8))
                        .foregroundStyle(theme.green)
                }
                Spacer()
                GFButton("Copy Markdown", icon: "doc.on.doc", kind: .outline, compact: true) {
                    copyMarkdown()
                }
                GFButton("Export PNG", icon: "square.and.arrow.down", kind: .dark, compact: true) {
                    exportPNG()
                }
                GFButton("Done", kind: .primary, compact: true) {
                    dismiss()
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
        }
        .frame(width: 660, height: 780)
        .background(theme.background)
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(theme.secondary)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(12)
        }
    }

    // MARK: The card

    private var receiptCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                HStack(spacing: 9) {
                    PilcrowMark(size: 22)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("PILCROW")
                            .font(Typeface.mono(9, weight: .medium))
                            .tracking(1.6)
                            .foregroundStyle(theme.ink)
                        Text("WEEKLY RECEIPT")
                            .font(Typeface.mono(7))
                            .tracking(1.4)
                            .foregroundStyle(theme.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(dateRange.uppercased())
                        .font(Typeface.mono(8, weight: .medium))
                        .tracking(0.8)
                        .foregroundStyle(theme.secondary)
                    Text(weekOffset == 0 ? "THIS WEEK" : weekOffset == -1 ? "LAST WEEK" : "WEEK \(weekOffset)")
                        .font(Typeface.mono(7))
                        .foregroundStyle(theme.secondary.opacity(0.7))
                }
            }

            Rectangle().fill(theme.ink).frame(height: 1)

            VStack(alignment: .leading, spacing: 6) {
                Text("TOTAL FOCUS")
                    .font(Typeface.mono(7.5, weight: .medium))
                    .tracking(1.4)
                    .foregroundStyle(theme.secondary)
                Text(week.focus > 0 ? week.focus.focusLabel : "0m")
                    .font(Typeface.display(52, weight: .semibold))
                    .tracking(-1.8)
                    .foregroundStyle(theme.ink)
                Text(insightLine)
                    .font(Typeface.body(11.5))
                    .foregroundStyle(theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 0) {
                receiptStat("\(week.sessions.filter(\.isCompleted).count)", "sessions")
                Rectangle().fill(theme.line).frame(width: 1, height: 34)
                receiptStat("\(week.commits)", "commits")
                Rectangle().fill(theme.line).frame(width: 1, height: 34)
                receiptStat("\(week.files)", "files")
                Rectangle().fill(theme.line).frame(width: 1, height: 34)
                receiptStat("\(week.coins)", "coins")
            }
            .padding(.vertical, 4)

            Hairline()

            VStack(alignment: .leading, spacing: 10) {
                Text("THE WEEK, DAY BY DAY")
                    .font(Typeface.mono(7.5, weight: .medium))
                    .tracking(1.2)
                    .foregroundStyle(theme.secondary)
                HStack(alignment: .bottom, spacing: 7) {
                    ForEach(days) { day in
                        VStack(spacing: 4) {
                            Text(day.seconds > 0 ? "\(Int(day.seconds / 60))" : "·")
                                .font(Typeface.mono(7, weight: .medium))
                                .foregroundStyle(day.seconds > 0 ? theme.ink : theme.secondary.opacity(0.5))
                            RoundedRectangle(cornerRadius: 1)
                                .fill(day.seconds > 0 ? theme.accent : theme.ink.opacity(0.06))
                                .frame(width: 26, height: max(4, barHeight(day)))
                            Text(day.date.formatted(.dateTime.weekday(.narrow)))
                                .font(Typeface.mono(7))
                                .foregroundStyle(theme.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !topRepos.isEmpty {
                Hairline()
                VStack(alignment: .leading, spacing: 7) {
                    Text("WHERE IT LANDED")
                        .font(Typeface.mono(7.5, weight: .medium))
                        .tracking(1.2)
                        .foregroundStyle(theme.secondary)
                    ForEach(topRepos, id: \.repo.id) { entry in
                        HStack {
                            Image(systemName: entry.repo.symbol)
                                .font(.system(size: 9))
                                .foregroundStyle(theme.secondary)
                            Text(entry.repo.name)
                                .font(Typeface.body(11, weight: .medium))
                                .foregroundStyle(theme.ink)
                            Spacer()
                            Text("\(entry.commits) \(entry.commits == 1 ? "commit" : "commits")")
                                .font(Typeface.mono(8))
                                .foregroundStyle(theme.secondary)
                        }
                    }
                }
            }

            if let bestDay {
                HStack(spacing: 8) {
                    Image(systemName: "sun.max")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(theme.accent)
                    Text("Peak day · \(bestDay.date.formatted(.dateTime.weekday(.wide))) · \(bestDay.seconds.focusLabel)")
                        .font(Typeface.body(10.5))
                        .foregroundStyle(theme.ink)
                }
            }

            if !insights.tags.isEmpty {
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(insights.tags.prefix(6)) { tag in
                        Text("#\(tag.tag) · \(tag.seconds.focusLabel)")
                            .font(Typeface.mono(8))
                            .foregroundStyle(theme.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(theme.accentSoft)
                    }
                }
            }

            Rectangle().fill(theme.ink).frame(height: 1)

            HStack(alignment: .firstTextBaseline) {
                Text("BY INTRADITIONAL")
                    .font(Typeface.mono(7))
                    .tracking(1.4)
                    .foregroundStyle(theme.secondary)
                Spacer()
                Text("PILCROW / FIELD NOTES")
                    .font(Typeface.mono(7))
                    .tracking(1.2)
                    .foregroundStyle(theme.secondary.opacity(0.7))
            }
        }
        .padding(30)
        .background(theme.surface)
        .overlay(Rectangle().strokeBorder(theme.line, lineWidth: 1))
    }

    private func receiptStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Typeface.display(18, weight: .semibold))
                .foregroundStyle(theme.ink)
            Text(label)
                .font(Typeface.mono(7))
                .textCase(.uppercase)
                .tracking(0.7)
                .foregroundStyle(theme.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func barHeight(_ day: DayFocus) -> CGFloat {
        let peak = max(1, days.map(\.seconds).max() ?? 1)
        return CGFloat(day.seconds / peak) * 46 + 4
    }

    private var insightLine: String {
        if week.sessions.isEmpty { return "A quiet week. Rest counts too." }
        let completed = week.sessions.filter(\.isCompleted).count
        let deep = week.sessions.filter { $0.accumulatedSeconds >= 50 * 60 }.count
        return "\(completed) \(completed == 1 ? "sitting" : "sittings"), \(deep) past fifty minutes. \(week.commits) commits left the working tree."
    }

    // MARK: Export

    private func copyMarkdown() {
        let text = markdown
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        withAnimation(.easeOut(duration: 0.2)) { exportedMessage = "Markdown copied." }
    }

    private var markdown: String {
        var lines: [String] = [
            "# Pilcrow — Weekly Receipt",
            "",
            "**\(dateRange)** · \(weekOffset == 0 ? "this week" : weekOffset == -1 ? "last week" : "week \(weekOffset)")",
            "",
            "## \(week.focus > 0 ? week.focus.focusLabel : "0m") focused",
            "",
            "- Sessions: \(week.sessions.filter(\.isCompleted).count)",
            "- Commits: \(week.commits)",
            "- Files changed: \(week.files)",
            "- Lines touched: \(week.additions + week.deletions)",
            "- Coins earned: \(week.coins)",
            "",
            "### Days"
        ]
        for day in days {
            let label = day.date.formatted(.dateTime.weekday(.wide))
            lines.append("- \(label): \(day.seconds > 0 ? day.seconds.focusLabel : "—")\(day.commits > 0 ? ", \(day.commits) commits" : "")")
        }
        if !topRepos.isEmpty {
            lines.append("")
            lines.append("### Repositories")
            for entry in topRepos {
                lines.append("- \(entry.repo.fullName): \(entry.commits) commits")
            }
        }
        if !insights.tags.isEmpty {
            lines.append("")
            lines.append("### Tags")
            for tag in insights.tags {
                lines.append("- #\(tag.tag): \(tag.sessions) sessions, \(tag.seconds.focusLabel)")
            }
        }
        if let bestDay {
            lines.append("")
            lines.append("**Peak day:** \(bestDay.date.formatted(.dateTime.weekday(.wide))) · \(bestDay.seconds.focusLabel)")
        }
        lines.append("")
        lines.append("_\(insightLine)_")
        return lines.joined(separator: "\n")
    }

    private func exportPNG() {
        let content = receiptCard
            .frame(width: 640)
            .environment(\.theme, theme)
            .environmentObject(store)
            .padding(28)
            .background(theme.background)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        guard let image = renderer.nsImage else {
            exportedMessage = "Could not render the receipt."
            return
        }
        guard let data = pngData(from: image) else {
            exportedMessage = "Could not encode the receipt."
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "Pilcrow-Receipt-\(dateRange.replacingOccurrences(of: " ", with: "")).png"
        panel.canCreateDirectories = true
        panel.title = "Export weekly receipt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try data.write(to: url)
            withAnimation(.easeOut(duration: 0.2)) { exportedMessage = "PNG saved." }
        } catch {
            exportedMessage = "Save failed: \(error.localizedDescription)"
        }
    }

    private func pngData(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
