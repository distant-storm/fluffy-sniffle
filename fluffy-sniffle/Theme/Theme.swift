import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

enum Theme {
    static let background = Color(hex: 0xFBF5E9)
    static let paper = Color(hex: 0xFFFCF5)
    static let field = Color(hex: 0xFFFFFF)
    static let ink = Color(hex: 0x2B2A4A)
    static let inkSoft = Color(hex: 0x6A6886)
    static let track = Color(hex: 0xECE6D8)
    static let headline = Color(hex: 0x7A63C9)
    static let headlineDeep = Color(hex: 0x4F3E9A)
    static let cornerRadius: CGFloat = 12
}

extension Font {
    static func pixel(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .monospaced, weight: weight)
    }
}

extension CardTint {
    var soft: Color {
        switch self {
        case .purple: return Color(hex: 0xEBE3F8)
        case .green: return Color(hex: 0xE2F1D8)
        case .yellow: return Color(hex: 0xFCF0CB)
        case .blue: return Color(hex: 0xDEE9F8)
        case .pink: return Color(hex: 0xFADFE3)
        case .teal: return Color(hex: 0xDAF1EC)
        }
    }

    var border: Color {
        switch self {
        case .purple: return Color(hex: 0x9C88DA)
        case .green: return Color(hex: 0x86B96F)
        case .yellow: return Color(hex: 0xE2BC4E)
        case .blue: return Color(hex: 0x7BA3DA)
        case .pink: return Color(hex: 0xE392A0)
        case .teal: return Color(hex: 0x6FBFB2)
        }
    }

    var strong: Color {
        switch self {
        case .purple: return Color(hex: 0x7A63C9)
        case .green: return Color(hex: 0x5E9E4A)
        case .yellow: return Color(hex: 0xD39A12)
        case .blue: return Color(hex: 0x4F7FC4)
        case .pink: return Color(hex: 0xD0647A)
        case .teal: return Color(hex: 0x3E9C8D)
        }
    }
}

// MARK: - Cards

struct PixelCard<Content: View>: View {
    let title: String
    let icon: String
    let tint: CardTint
    let trailing: String?
    let content: Content

    init(
        title: String,
        icon: String,
        tint: CardTint,
        trailing: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.tint = tint
        self.trailing = trailing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(tint.strong)
                Text(title.uppercased())
                    .font(.pixel(.subheadline, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let trailing {
                    Text(trailing.uppercased())
                        .font(.pixel(.caption2, weight: .bold))
                        .foregroundStyle(tint.strong)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.soft)

            Rectangle()
                .fill(tint.border)
                .frame(height: 2)

            content
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.paper)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .strokeBorder(tint.border, lineWidth: 2)
        )
    }
}

/// A small callout box like the tinted footers in the reference design.
struct Callout: View {
    let text: String
    var tint: CardTint
    var icon: String?

    var body: some View {
        HStack(spacing: 8) {
            Text(text.uppercased())
                .font(.pixel(.caption, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(tint.strong)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(tint.soft))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(tint.border, lineWidth: 1.5))
    }
}

// MARK: - Buttons

/// Chunky button with a hard shadow that "presses down" when tapped.
struct PixelButtonStyle: ButtonStyle {
    var fill: Color
    var foreground: Color = .white
    var fullWidth = true
    var depth: CGFloat = 4

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        return configuration.label
            .font(.pixel(.headline, weight: .bold))
            .textCase(.uppercase)
            .foregroundStyle(foreground)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .frame(maxWidth: fullWidth ? CGFloat.infinity : nil)
            .background(shape.fill(fill))
            .overlay(shape.strokeBorder(Theme.ink, lineWidth: 2))
            .background(shape.fill(Theme.ink).offset(y: pressed ? 0 : depth))
            .offset(y: pressed ? depth : 0)
            .padding(.bottom, depth)
            .animation(.spring(response: 0.22, dampingFraction: 0.5), value: pressed)
            .sensoryFeedback(.impact(weight: .light), trigger: pressed) { _, isPressed in isPressed }
    }
}

/// Gentle squash for tappable cards and chips.
struct SquishStyle: ButtonStyle {
    var scale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        return configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .brightness(configuration.isPressed ? -0.03 : 0)
            .animation(.spring(response: 0.28, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

struct ChipButton: View {
    let label: String
    let isOn: Bool
    var tint: CardTint
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        Button(action: action) {
            HStack(spacing: 4) {
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .black))
                        .transition(.scale.combined(with: .opacity))
                }
                Text(label.uppercased())
                    .font(.pixel(.caption, weight: .bold))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .foregroundStyle(isOn ? Color.white : Theme.ink)
            .background(shape.fill(isOn ? tint.strong : Theme.field))
            .overlay(shape.strokeBorder(isOn ? Theme.ink : tint.border, lineWidth: isOn ? 2 : 1.5))
            .scaleEffect(isOn ? 1.04 : 1)
        }
        .buttonStyle(SquishStyle(scale: 0.9))
        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: isOn)
        .sensoryFeedback(.selection, trigger: isOn)
    }
}

// MARK: - Progress

/// Segmented bar styled after the "stats" bars in the reference.
struct SegmentBar: View {
    let fraction: Double
    var segments = 12

    private var color: Color {
        if fraction > 0.5 { return CardTint.green.strong }
        if fraction > 0.2 { return CardTint.yellow.strong }
        return CardTint.pink.strong
    }

    var body: some View {
        let filled = Int((fraction * Double(segments)).rounded(.up))
        HStack(spacing: 2) {
            ForEach(0..<segments, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(index < filled ? color : Theme.track)
            }
        }
        .frame(height: 10)
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Theme.field))
        .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(Theme.ink.opacity(0.55), lineWidth: 1.5))
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: filled)
        .accessibilityElement()
        .accessibilityLabel("Time left")
        .accessibilityValue("\(Int((fraction * 100).rounded())) percent")
    }
}

// MARK: - Layout

/// Wraps children onto new lines, like text.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            widest = max(widest, x + size.width)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Fields

struct FieldLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.pixel(.caption2, weight: .bold))
            .foregroundStyle(Theme.inkSoft)
    }
}

struct PixelTextField: View {
    let label: String
    let prompt: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var capitalization: TextInputAutocapitalization = .sentences
    var prefix: String?

    @FocusState var focused: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        VStack(alignment: .leading, spacing: 5) {
            FieldLabel(text: label)
            HStack(spacing: 6) {
                if let prefix {
                    Text(prefix)
                        .font(.pixel(.body, weight: .bold))
                        .foregroundStyle(Theme.inkSoft)
                }
                TextField(prompt, text: $text)
                    .font(.pixel(.body))
                    .foregroundStyle(Theme.ink)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(capitalization)
                    .autocorrectionDisabled(keyboard != .default)
                    .focused($focused)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(shape.fill(Theme.field))
            .overlay(shape.strokeBorder(focused ? Theme.headline : Theme.ink.opacity(0.25), lineWidth: focused ? 2 : 1.5))
            .animation(.easeOut(duration: 0.15), value: focused)
        }
    }
}

// MARK: - Formatting

enum PriceFormat {
    static var currencyCode: String { Locale.current.currency?.identifier ?? "GBP" }

    static var currencySymbol: String { Locale.current.currencySymbol ?? "£" }

    static func display(_ value: Decimal) -> String {
        value.formatted(.currency(code: currencyCode))
    }

    /// Plain number for editing, e.g. "312.40" (uses the locale's decimal separator).
    static func editable(_ value: Decimal) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)).grouping(.never))
    }

    /// Accepts input like "£1,312.40" or "312,40" depending on locale.
    static func parse(_ text: String) -> Decimal? {
        let separator = Locale.current.decimalSeparator ?? "."
        var cleaned = ""
        for character in text {
            if character.isNumber {
                cleaned.append(character)
            } else if String(character) == separator {
                cleaned.append(".")
            }
        }
        guard !cleaned.isEmpty else { return nil }
        return Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX"))
    }
}

extension Date {
    var cardFormat: String {
        formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year())
    }

    var shortCardFormat: String {
        formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }
}
