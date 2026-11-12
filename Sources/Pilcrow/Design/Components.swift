import SwiftUI

// MARK: - Interaction

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.66 : 1)
            .offset(y: configuration.isPressed ? 1 : 0)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

// MARK: - Buttons

enum GFButtonKind { case primary, dark, outline, quiet }

struct GFButton: View {
    @Environment(\.theme) private var theme
    @State private var hovering = false

    var title: String
    var icon: String?
    var kind: GFButtonKind = .primary
    var compact = false
    var isEnabled = true
    var action: () -> Void

    init(_ title: String, icon: String? = nil, kind: GFButtonKind = .primary,
         compact: Bool = false, isEnabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.kind = kind
        self.compact = compact
        self.isEnabled = isEnabled
        self.action = action
    }

    private var foreground: Color {
        switch kind {
        case .primary: theme.accentInk
        case .dark: theme.background
        case .outline, .quiet: theme.ink
        }
    }

    private var background: Color {
        switch kind {
        case .primary:
            theme.accent.opacity(hovering ? 0.9 : 1)
        case .dark:
            theme.ink.opacity(hovering ? 0.88 : 1)
        case .outline:
            hovering ? theme.raised : .clear
        case .quiet:
            hovering ? theme.raised : .clear
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: compact ? 9 : 10, weight: .semibold))
                }
                Text(title)
                    .font(Typeface.mono(compact ? 9 : 10, weight: .medium))
                    .tracking(0.9)
                    .textCase(.uppercase)
                    .lineLimit(1)
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, compact ? 12 : 16)
            .frame(height: compact ? 28 : 36)
            .background(background)
            .overlay(
                Rectangle()
                    .strokeBorder(kind == .outline || kind == .quiet ? theme.line : .clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.40)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.10), value: hovering)
    }
}

struct GFIconButton: View {
    @Environment(\.theme) private var theme
    @State private var hovering = false
    var icon: String
    var label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(hovering ? theme.ink : theme.secondary)
                .frame(width: 30, height: 30)
                .background(hovering ? theme.raised : .clear)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .help(label)
        .accessibilityLabel(label)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }
}

// MARK: - Surfaces

struct Panel<Content: View>: View {
    @Environment(\.theme) private var theme
    var padding: CGFloat = 20
    var background: Color?
    var content: Content

    init(padding: CGFloat = 20, background: Color? = nil, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.background = background
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(background ?? theme.surface)
            .overlay(
                Rectangle()
                    .strokeBorder(theme.line, lineWidth: 1)
            )
    }
}

/// A deep-charcoal card. Used sparingly for the one piece of information that
/// should read as a specimen plate on the page. The content receives the dark
/// theme explicitly so inline colours stay correct.
struct DarkPanel<Content: View>: View {
    var padding: CGFloat = 20
    var content: (AppTheme) -> Content

    init(padding: CGFloat = 20, @ViewBuilder content: @escaping (AppTheme) -> Content) {
        self.padding = padding
        self.content = content
    }

    var body: some View {
        let dark = AppTheme.charcoal
        ZStack(alignment: .topLeading) {
            dark.background
            GridPaper()
                .environment(\.theme, dark)
                .opacity(0.55)
            content(dark)
                .environment(\.theme, dark)
                .padding(padding)
        }
        .overlay(
            Rectangle()
                .strokeBorder(dark.line, lineWidth: 1)
        )
    }
}

struct Hairline: View {
    @Environment(\.theme) private var theme
    var body: some View {
        Rectangle().fill(theme.line).frame(height: 1)
    }
}

// MARK: - Labels

struct MonoLabel: View {
    @Environment(\.theme) private var theme
    var text: String
    var dot = false

    var body: some View {
        HStack(spacing: 6) {
            if dot {
                Circle().fill(theme.accent).frame(width: 5, height: 5)
            }
            Text(text)
                .font(Typeface.mono(9.5, weight: .medium))
                .tracking(1.8)
                .textCase(.uppercase)
                .foregroundStyle(theme.secondary)
        }
    }
}

struct TagLabel: View {
    @Environment(\.theme) private var theme
    var text: String
    var icon: String?
    var tint: Color?

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon).font(.system(size: 8, weight: .semibold))
            }
            Text(text)
                .font(Typeface.mono(8.5, weight: .medium))
                .tracking(1.1)
                .textCase(.uppercase)
        }
        .foregroundStyle(tint ?? theme.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background((tint ?? theme.ink).opacity(0.06))
        .overlay(Rectangle().strokeBorder((tint ?? theme.ink).opacity(0.18), lineWidth: 1))
    }
}

struct StatusTag: View {
    @Environment(\.theme) private var theme
    var text: String
    var color: Color?

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color ?? theme.green).frame(width: 5, height: 5)
            Text(text)
                .font(Typeface.mono(8.5, weight: .medium))
                .tracking(1.1)
                .textCase(.uppercase)
                .foregroundStyle(theme.secondary)
        }
    }
}

// MARK: - Coins

struct CoinMark: View {
    @Environment(\.theme) private var theme
    var size: CGFloat = 18

    var body: some View {
        ZStack {
            Circle().fill(theme.accent)
            Circle().strokeBorder(theme.accentInk.opacity(0.28), lineWidth: max(1, size * 0.055))
                .padding(size * 0.1)
            Text("G")
                .font(Typeface.display(size * 0.52, weight: .bold))
                .foregroundStyle(theme.accentInk)
                .offset(y: -size * 0.02)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct CoinAmount: View {
    @Environment(\.theme) private var theme
    var amount: Int
    var size: CGFloat = 14
    var muted = false

    var body: some View {
        HStack(spacing: 5) {
            CoinMark(size: size + 2)
            Text("\(amount)")
                .font(Typeface.mono(size, weight: .medium))
                .foregroundStyle(muted ? theme.secondary : theme.ink)
                .contentTransition(.numericText(value: Double(amount)))
                .animation(.easeOut(duration: 0.2), value: amount)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(amount) coins")
    }
}

// MARK: - Theme swatch

/// A compact, layout-safe palette sample for chips and rows.
struct ThemeSwatch: View {
    var theme: AppTheme

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                Rectangle()
                    .fill(theme.raised)
                    .frame(width: max(12, geo.size.width * 0.24))
                VStack(alignment: .leading, spacing: max(2, geo.size.height * 0.07)) {
                    Rectangle()
                        .fill(theme.accent)
                        .frame(width: max(10, geo.size.width * 0.30), height: 2)
                    Rectangle()
                        .fill(theme.ink.opacity(0.30))
                        .frame(width: max(12, geo.size.width * 0.40), height: 1.5)
                    Rectangle()
                        .fill(theme.ink.opacity(0.16))
                        .frame(width: max(9, geo.size.width * 0.28), height: 1.5)
                    Spacer(minLength: 0)
                }
                .padding(max(4, geo.size.height * 0.13))
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.background)
            }
            .overlay(Rectangle().strokeBorder(theme.ink.opacity(0.22), lineWidth: 1))
        }
    }
}

// MARK: - Avatars

struct AvatarView: View {
    @Environment(\.theme) private var theme
    var item: ShopItem?
    var size: CGFloat = 40
    var showStatus = false

    init(item: ShopItem?, size: CGFloat = 40, showStatus: Bool = false) {
        self.item = item
        self.size = size
        self.showStatus = showStatus
    }

    private var parts: (glyph: String, shape: String) {
        let pieces = (item?.payload ?? "hammer.fill|circle").split(separator: "|")
        return (String(pieces.first ?? "hammer.fill"), pieces.count > 1 ? String(pieces[1]) : "circle")
    }

    private var tint: Color {
        switch item?.id ?? "" {
        case "avatar_sprout": theme.green
        case "avatar_owl": theme.ink
        case "avatar_moth": theme.accent
        case "avatar_terminal": theme.green
        default: theme.accent
        }
    }

    var body: some View {
        ZStack {
            shape
                .fill(theme.raised)
            shape
                .fill(tint.opacity(0.15))
            shape
                .stroke(tint.opacity(0.55), lineWidth: 1)

            // tiny registration tick, like a maker's mark
            Circle()
                .fill(theme.accent)
                .frame(width: size * 0.1, height: size * 0.1)
                .offset(x: size * 0.33, y: -size * 0.33)

            Image(systemName: parts.glyph)
                .font(.system(size: size * 0.38, weight: .medium))
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
        .overlay(alignment: .bottomTrailing) {
            if showStatus {
                Circle()
                    .fill(theme.green)
                    .overlay(Circle().strokeBorder(theme.surface, lineWidth: 2))
                    .frame(width: size * 0.26, height: size * 0.26)
                    .offset(x: 1, y: 1)
            }
        }
        .accessibilityLabel(item?.name ?? "Avatar")
    }

    private var shape: AnyShape {
        switch parts.shape {
        case "hexagon": AnyShape(HexagonShape())
        case "squircle": AnyShape(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
        case "diamond": AnyShape(DiamondShape())
        default: AnyShape(Circle())
        }
    }
}

struct AnyShape: Shape, @unchecked Sendable {
    private let builder: (CGRect) -> Path

    init<S: Shape>(_ shape: S) {
        builder = { shape.path(in: $0) }
    }

    func path(in rect: CGRect) -> Path { builder(rect) }
}

struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        for index in 0..<6 {
            let angle = (Double(index) / 6.0) * .pi * 2 - .pi / 2
            let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

struct DiamondShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

struct BadgeView: View {
    @Environment(\.theme) private var theme
    var item: ShopItem
    var compact = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: item.payload)
                .font(.system(size: compact ? 9 : 10, weight: .semibold))
            if !compact {
                Text(item.name)
                    .font(Typeface.mono(9, weight: .medium))
                    .tracking(0.8)
                    .textCase(.uppercase)
            }
        }
        .foregroundStyle(theme.accent)
        .padding(.horizontal, compact ? 4 : 7)
        .padding(.vertical, compact ? 3 : 4)
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(theme.accent.opacity(0.4), lineWidth: 1)
        )
        .background(theme.accent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 2))
    }
}

// MARK: - Logo

struct PilcrowMark: View {
    @Environment(\.theme) private var theme
    var size: CGFloat = 24

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                .fill(theme.ink)
            Canvas { context, canvas in
                let inset = canvas.width * 0.19
                let box = CGRect(
                    x: inset,
                    y: inset,
                    width: canvas.width - inset * 2,
                    height: canvas.height - inset * 2
                )
                let glyphW = box.height * 0.69
                let glyphH = box.height
                let x = box.midX - glyphW / 2
                let y = box.midY - glyphH / 2
                let stroke = glyphW * 0.255
                let bowlH = glyphH * 0.5

                // The left stem is the paragraph's mast; the bowl and its right leg
                // are the loop — drawn in signal orange so the mark reads as ¶.
                var mast = Path()
                mast.addRoundedRect(
                    in: CGRect(x: x, y: y, width: stroke, height: glyphH),
                    cornerSize: CGSize(width: stroke * 0.35, height: stroke * 0.35)
                )
                context.fill(mast, with: .color(theme.background))

                var leg = Path()
                leg.addRoundedRect(
                    in: CGRect(
                        x: x + glyphW - stroke,
                        y: y + glyphH * 0.32,
                        width: stroke,
                        height: glyphH * 0.68
                    ),
                    cornerSize: CGSize(width: stroke * 0.35, height: stroke * 0.35)
                )
                context.fill(leg, with: .color(theme.accent))

                let bowl = CGRect(
                    x: x + stroke,
                    y: y,
                    width: glyphW - stroke,
                    height: bowlH
                ).insetBy(dx: stroke / 2, dy: stroke / 2)
                context.stroke(
                    Path(roundedRect: bowl, cornerRadius: glyphW * 0.2),
                    with: .color(theme.accent),
                    lineWidth: stroke
                )
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Grid background

struct GridPaper: View {
    @Environment(\.theme) private var theme
    var body: some View {
        Canvas { context, size in
            let minor: CGFloat = 24
            let major: CGFloat = 120
            var minorPath = Path()
            var majorPath = Path()

            var x: CGFloat = 0
            while x < size.width {
                let isMajor = abs(x.truncatingRemainder(dividingBy: major)) < 0.5
                if isMajor {
                    majorPath.move(to: CGPoint(x: x, y: 0))
                    majorPath.addLine(to: CGPoint(x: x, y: size.height))
                } else {
                    minorPath.move(to: CGPoint(x: x, y: 0))
                    minorPath.addLine(to: CGPoint(x: x, y: size.height))
                }
                x += minor
            }

            var y: CGFloat = 0
            while y < size.height {
                let isMajor = abs(y.truncatingRemainder(dividingBy: major)) < 0.5
                if isMajor {
                    majorPath.move(to: CGPoint(x: 0, y: y))
                    majorPath.addLine(to: CGPoint(x: size.width, y: y))
                } else {
                    minorPath.move(to: CGPoint(x: 0, y: y))
                    minorPath.addLine(to: CGPoint(x: size.width, y: y))
                }
                y += minor
            }

            context.stroke(minorPath, with: .color(theme.ink.opacity(theme.isDark ? 0.028 : 0.022)), lineWidth: 0.5)
            context.stroke(majorPath, with: .color(theme.ink.opacity(theme.isDark ? 0.055 : 0.042)), lineWidth: 0.5)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Drafting marks

/// Corner registration ticks. A small nod to technical drawings.
struct RegistrationMarks: View {
    @Environment(\.theme) private var theme
    var inset: CGFloat = 8
    var length: CGFloat = 6

    var body: some View {
        ZStack {
            VStack {
                HStack { tick(rotation: 0); Spacer(); tick(rotation: 90) }
                Spacer()
                HStack { tick(rotation: 270); Spacer(); tick(rotation: 180) }
            }
            .padding(inset)
        }
        .opacity(0.45)
        .accessibilityHidden(true)
    }

    private func tick(rotation: Double) -> some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: length))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: length, y: 0))
        }
        .stroke(theme.ink, lineWidth: 0.8)
        .frame(width: length, height: length)
        .rotationEffect(.degrees(rotation))
    }
}

// MARK: - Motion

struct RevealModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isSnapshotting) private var snapshotting
    @State private var shown = false
    var delay: Double

    func body(content: Content) -> some View {
        content
            .opacity(shown || snapshotting ? 1 : 0)
            .offset(y: shown || reduceMotion || snapshotting ? 0 : 12)
            .mask(alignment: .bottom) {
                Rectangle()
                    .scaleEffect(y: shown || reduceMotion || snapshotting ? 1 : 0.72, anchor: .bottom)
            }
            .onAppear {
                guard !shown else { return }
                if reduceMotion || snapshotting {
                    shown = true
                } else {
                    withAnimation(.timingCurve(0.16, 0.84, 0.16, 1, duration: 0.52).delay(delay)) {
                        shown = true
                    }
                }
            }
    }
}

private struct SnapshottingKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isSnapshotting: Bool {
        get { self[SnapshottingKey.self] }
        set { self[SnapshottingKey.self] = newValue }
    }
}

extension View {
    func reveal(delay: Double = 0) -> some View {
        modifier(RevealModifier(delay: delay))
    }

    func panelHover(_ hovering: Bool, theme: AppTheme) -> some View {
        overlay(
            Rectangle()
                .strokeBorder(hovering ? theme.ink.opacity(0.26) : .clear, lineWidth: 1)
        )
        .animation(.easeOut(duration: 0.12), value: hovering)
    }
}
