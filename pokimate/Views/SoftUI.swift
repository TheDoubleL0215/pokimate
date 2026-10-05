import SwiftUI

/// Circular liquid-glass icon control used across menus and the table.
struct GlassIconButton: View {
    var systemImage: String
    var accessibilityLabel: String
    var action: () -> Void

    /// Matches setup stepped-value arrow buttons.
    private let size: CGFloat = 32

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(PokerTheme.textPrimary)
                .frame(width: size, height: size)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .frame(width: size, height: size)
        .accessibilityLabel(accessibilityLabel)
        .padding(.all, 8)
    }
}

/// Circular liquid-glass back control used across menus and the table.
struct GlassBackButton: View {
    var accessibilityLabel: String? = nil
    var action: () -> Void

    @EnvironmentObject private var l10n: LocalizationManager

    var body: some View {
        GlassIconButton(
            systemImage: "chevron.backward",
            accessibilityLabel: accessibilityLabel ?? l10n.t("a11y.back"),
            action: action
        )
    }
}

/// Same capsule look as the in-game Fold / Raise / Call buttons.
struct GameCapsuleButton: View {
    let title: String
    var fill: Color = PokerTheme.foldFill
    var text: Color = PokerTheme.brandBlue
    var enabled: Bool = true
    var compact: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: compact ? 14 : 16, weight: .heavy, design: .rounded))
                .foregroundStyle(enabled ? text : PokerTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .padding(.vertical, compact ? 12 : 16)
                .padding(.horizontal, 6)
                .background(Capsule().fill(fill))
                .overlay(
                    Capsule()
                        .strokeBorder(
                            (enabled ? text : PokerTheme.textSecondary).opacity(0.25),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }
}

struct GameCapsuleChip: View {
    let title: String
    let isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
                Text(title)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(isSelected ? PokerTheme.brandBlue : PokerTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(Capsule().fill(PokerTheme.foldFill))
                .overlay(
                    Capsule()
                        .strokeBorder(
                            isSelected
                                ? PokerTheme.brandBlue.opacity(0.45)
                                : PokerTheme.cardStroke,
                            lineWidth: isSelected ? 1.5 : 1
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

struct MenuPanel<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(PokerTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(PokerTheme.cardStroke, lineWidth: 1)
                    )
            )
    }
}

struct MenuToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    @EnvironmentObject private var l10n: LocalizationManager

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(PokerTheme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(PokerTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isOn.toggle()
                }
            } label: {
                Text(isOn ? l10n.t("common.on") : l10n.t("common.off"))
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(isOn ? PokerTheme.brandBlue : PokerTheme.textSecondary)
                    .frame(width: 52)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(PokerTheme.foldFill))
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                isOn ? PokerTheme.brandBlue.opacity(0.45) : PokerTheme.cardStroke,
                                lineWidth: 1
                            )
                    )
            }
            .buttonStyle(.plain)
        }
    }
}

struct MenuBackground: View {
    var body: some View {
        ZStack {
            PokerTheme.background.ignoresSafeArea()

            RadialGradient(
                colors: [
                    PokerTheme.brandBlue.opacity(0.18),
                    PokerTheme.brandBlue.opacity(0.05),
                    .clear
                ],
                center: .top,
                startRadius: 20,
                endRadius: 420
            )
            .ignoresSafeArea()
        }
    }
}
