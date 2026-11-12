import SwiftUI

struct ShopView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.theme) private var theme
    @Binding var selection: AppSection
    @State private var filter: ShopCategory?

    init(selection: Binding<AppSection>, initialFilter: ShopCategory? = nil) {
        self._selection = selection
        self._filter = State(initialValue: initialFilter)
    }

    private var items: [ShopItem] {
        filter.map { ShopItem.items(in: $0) } ?? ShopItem.all
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(
                    kicker: "SECTION 04 / CATALOG",
                    title: "Spend it well.",
                    subtitle: "Coins come from focused time, not a credit card. Buy something that makes the desk feel like yours."
                ) {
                    coinPurse
                        .padding(.top, 4)
                }
                .reveal()

                categoryBar
                    .reveal(delay: 0.04)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 238), spacing: 14)], spacing: 14) {
                    ForEach(items) { item in
                        ShopCard(item: item)
                    }
                }
                .reveal(delay: 0.08)

                HStack(spacing: 6) {
                    Rectangle().fill(theme.accent).frame(width: 18, height: 1)
                    Text("Themes and cosmetics cost coins. Badges are earned, never sold.")
                        .font(Typeface.mono(8))
                        .tracking(0.6)
                        .foregroundStyle(theme.secondary)
                    Spacer()
                    Text("\(store.ownedItemIDs.count) / \(ShopItem.all.count) collected")
                        .font(Typeface.mono(8))
                        .foregroundStyle(theme.secondary)
                }
                .padding(.top, 4)
                .padding(.bottom, 14)
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)
            .frame(maxWidth: 1180)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: Coin purse

    private var coinPurse: some View {
        DarkPanel(padding: 0) { dark in
            HStack(spacing: 11) {
                CoinMark(size: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text("COIN PURSE")
                        .font(Typeface.mono(7, weight: .medium))
                        .tracking(1.4)
                        .foregroundStyle(dark.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(store.profile.coins)")
                            .font(Typeface.display(22, weight: .semibold))
                            .tracking(-0.5)
                            .foregroundStyle(dark.ink)
                            .contentTransition(.numericText(value: Double(store.profile.coins)))
                        Text("coins")
                            .font(Typeface.mono(8))
                            .foregroundStyle(dark.secondary)
                    }
                }
                Rectangle().fill(dark.line).frame(width: 1, height: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("TODAY")
                        .font(Typeface.mono(7, weight: .medium))
                        .tracking(1.2)
                        .foregroundStyle(dark.secondary)
                    Text("+\(store.todayCoins)")
                        .font(Typeface.mono(10, weight: .medium))
                        .foregroundStyle(dark.green)
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
        }
        .fixedSize()
        .animation(.easeOut(duration: 0.2), value: store.profile.coins)
    }

    // MARK: Categories

    private var categoryBar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 22) {
                categoryButton(nil, title: "All", icon: "square.grid.2x2")
                ForEach(ShopCategory.allCases) { category in
                    categoryButton(category, title: category.title, icon: category.glyph)
                }
                Spacer()
                Text("\(items.count) items")
                    .font(Typeface.mono(9))
                    .foregroundStyle(theme.secondary)
            }
            .padding(.bottom, 9)
            Hairline()
        }
    }

    private func categoryButton(_ category: ShopCategory?, title: String, icon: String) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.18)) { filter = category }
        } label: {
            VStack(spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: icon)
                        .font(.system(size: 9, weight: .medium))
                    Text(title)
                        .font(Typeface.body(12, weight: filter == category ? .semibold : .regular))
                }
                .foregroundStyle(filter == category ? theme.ink : theme.secondary)
                Rectangle()
                    .fill(filter == category ? theme.accent : .clear)
                    .frame(width: 18, height: 2)
            }
            .fixedSize()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(filter == category ? .isSelected : [])
    }

}

// MARK: - Card

struct ShopCard: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.theme) private var theme
    var item: ShopItem

    @State private var hovering = false
    @State private var pulse = false
    @State private var shake = false

    private var owned: Bool { store.owns(item) }
    private var equipped: Bool { store.isEquipped(item) }

    private var rarityColor: Color {
        switch item.rarity {
        case .common: theme.secondary
        case .rare: theme.green
        case .legendary: theme.accent
        }
    }

    private var decorFull: Bool {
        item.category == .decor && store.profile.equippedDecorIDs.count >= 3 && !equipped
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            preview
                .frame(height: 148)
                .frame(maxWidth: .infinity)
                .background(theme.raised.opacity(0.45))
                .overlay(alignment: .topLeading) {
                    Text(item.rarity.label.uppercased())
                        .font(Typeface.mono(7, weight: .medium))
                        .tracking(1.1)
                        .foregroundStyle(rarityColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(theme.surface.opacity(0.9))
                        .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(rarityColor.opacity(0.3), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                        .padding(10)
                }
                .overlay(alignment: .topTrailing) {
                    if owned {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 7, weight: .bold))
                            Text("OWNED")
                                .font(Typeface.mono(7, weight: .medium))
                                .tracking(0.8)
                        }
                        .foregroundStyle(theme.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(theme.surface.opacity(0.9))
                        .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(theme.green.opacity(0.3), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                        .padding(10)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    Text(String(format: "%02d", (ShopItem.all.firstIndex(where: { $0.id == item.id }) ?? 0) + 1))
                        .font(Typeface.mono(8))
                        .foregroundStyle(theme.secondary.opacity(0.55))
                        .padding(10)
                }

            Hairline()

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.name)
                        .font(Typeface.display(17, weight: .medium))
                        .tracking(-0.2)
                        .foregroundStyle(theme.ink)
                    Spacer()
                    if item.isEarnable {
                        HStack(spacing: 4) {
                            Image(systemName: owned ? "checkmark.seal.fill" : "lock.fill")
                                .font(.system(size: 7, weight: .semibold))
                            Text(owned ? "EARNED" : "EARN")
                                .font(Typeface.mono(8, weight: .medium))
                                .tracking(0.8)
                        }
                        .foregroundStyle(owned ? theme.green : theme.accent)
                    } else if item.price > 0 {
                        CoinAmount(amount: item.price, size: 10)
                    } else {
                        Text("INCLUDED")
                            .font(Typeface.mono(8, weight: .medium))
                            .tracking(0.8)
                            .foregroundStyle(theme.secondary)
                    }
                }
                Text(item.tagline)
                    .font(Typeface.body(11))
                    .foregroundStyle(theme.secondary)
                    .lineLimit(2)
                    .frame(minHeight: 30, alignment: .topLeading)

                if item.isEarnable && !owned {
                    earnRow
                } else if owned {
                    actionButton(title: equipped
                                 ? (item.category == .badges || item.category == .decor ? "Put back" : "In use")
                                 : (item.category == .decor && decorFull ? "Shelf full" : item.category == .decor ? "Place on shelf" : "Equip"),
                                 icon: equipped ? "checkmark" : "arrow.right",
                                 enabled: !(equipped && (item.category == .themes || item.category == .avatars)) && !decorFull) {
                        if equipped && (item.category == .badges || item.category == .decor) {
                            store.equip(item)
                        } else if !equipped {
                            store.equip(item)
                        }
                    }
                } else {
                    buyRow
                }
            }
            .padding(14)
        }
        .background(theme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(equipped ? theme.accent.opacity(0.55) : (hovering ? theme.ink.opacity(0.3) : theme.line), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .offset(x: shake ? 3 : 0)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.14), value: hovering)
        .animation(.easeInOut(duration: 0.06).repeatCount(5, autoreverses: true), value: shake)
    }

    private func actionButton(title: String, icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(title)
                    .font(Typeface.body(10.5, weight: .medium))
                Image(systemName: icon)
                    .font(.system(size: 8, weight: .semibold))
            }
            .foregroundStyle(enabled ? theme.ink : theme.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 28)
            .background(enabled ? theme.raised : .clear)
            .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(theme.line, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 2))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.6)
    }

    private var earnRow: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Text("EARN IT")
                    .font(Typeface.mono(7.5, weight: .medium))
                    .tracking(1)
                    .foregroundStyle(theme.accent)
                Spacer()
                if let achievementID = item.earnedByAchievementID,
                   let achievement = AchievementCatalog.find(achievementID) {
                    Text(store.progress(for: achievement).label)
                        .font(Typeface.mono(7))
                        .foregroundStyle(theme.secondary)
                        .lineLimit(1)
                }
            }
            Text(item.earnHint)
                .font(Typeface.body(9.5))
                .foregroundStyle(theme.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(height: 40)
        .background(theme.raised.opacity(0.35))
        .overlay(Rectangle().strokeBorder(theme.line, lineWidth: 1))
    }

    private var buyRow: some View {
        Button {
            buy()
        } label: {            HStack(spacing: 5) {
                Image(systemName: "bag")
                    .font(.system(size: 9, weight: .semibold))
                Text(store.profile.coins >= item.price ? "Buy" : "Buy · \(item.price - store.profile.coins) short")
                    .font(Typeface.body(10.5, weight: .semibold))
            }
            .foregroundStyle(store.profile.coins >= item.price ? theme.background : theme.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 28)
            .background(store.profile.coins >= item.price ? theme.ink : .clear)
            .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(theme.line, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 2))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("Buy \(item.name) for \(item.price) coins")
    }

    private func buy() {
        if store.buy(item) {
            withAnimation(.timingCurve(0.16, 0.84, 0.16, 1, duration: 0.32)) { pulse = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.22)) { pulse = false }
            }
        } else {
            shake.toggle()
        }
    }

    // MARK: Preview

    private var preview: some View {
        ZStack {
            registrationMarks
            ShopPreview(item: item, size: 92)
                .scaleEffect(pulse ? 1.06 : 1)
        }
    }

    private var registrationMarks: some View {
        ZStack {
            VStack {
                HStack {
                    cornerTick
                    Spacer()
                    cornerTick
                }
                Spacer()
                HStack {
                    cornerTick
                    Spacer()
                    cornerTick
                }
            }
            .padding(8)
        }
        .opacity(0.5)
    }

    private var cornerTick: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 6))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 6, y: 0))
        }
        .stroke(theme.secondary.opacity(0.6), lineWidth: 1)
        .frame(width: 6, height: 6)
    }
}

// MARK: - Preview

struct ShopPreview: View {
    @Environment(\.theme) private var theme
    var item: ShopItem
    var size: CGFloat = 70

    var body: some View {
        switch item.category {
        case .themes:
            ThemeMiniature(theme: AppTheme.resolve(ThemeID(rawValue: item.payload) ?? .paper))
                .frame(width: size * 1.35, height: size * 0.92)
                .floatingShadow(theme)
        case .avatars:
            AvatarView(item: item, size: size * 0.78)
        case .badges:
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .strokeBorder(theme.ink.opacity(0.14), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                        .frame(width: size * 0.9, height: size * 0.9)
                    Image(systemName: item.payload)
                        .font(.system(size: size * 0.3, weight: .light))
                        .foregroundStyle(theme.accent)
                }
                BadgeView(item: item)
            }
        case .decor:
            VStack(spacing: 2) {
                Image(systemName: item.payload)
                    .font(.system(size: size * 0.5, weight: .light))
                    .foregroundStyle(theme.ink.opacity(0.8))
                    .frame(height: size * 0.6, alignment: .bottom)
                Rectangle()
                    .fill(theme.ink.opacity(0.35))
                    .frame(width: size * 1.1, height: 2)
                Rectangle()
                    .fill(theme.ink.opacity(0.12))
                    .frame(width: size * 0.8, height: 3)
            }
        }
    }
}

struct ThemeMiniature: View {
    var theme: AppTheme

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 1).fill(theme.accent).frame(width: 9, height: 3)
                RoundedRectangle(cornerRadius: 1).fill(theme.ink.opacity(0.25)).frame(width: 13, height: 2)
                RoundedRectangle(cornerRadius: 1).fill(theme.ink.opacity(0.25)).frame(width: 10, height: 2)
                Spacer()
            }
            .padding(7)
            .frame(width: 28)
            .background(theme.raised.opacity(0.7))
            Rectangle().fill(theme.line).frame(width: 1)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 1).fill(theme.ink.opacity(0.65)).frame(width: 24, height: 3)
                    Spacer()
                    Circle().fill(theme.accent).frame(width: 4, height: 4)
                }
                RoundedRectangle(cornerRadius: 2).fill(theme.surface).frame(height: 15)
                    .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(theme.line, lineWidth: 0.5))
                HStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 1).fill(theme.ink.opacity(0.2)).frame(width: 16, height: 12)
                    RoundedRectangle(cornerRadius: 1).fill(theme.accent.opacity(0.4)).frame(height: 12)
                }
                Spacer()
            }
            .padding(7)
        }
        .background(theme.background)
        .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(theme.ink.opacity(0.2), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 2))
    }
}
