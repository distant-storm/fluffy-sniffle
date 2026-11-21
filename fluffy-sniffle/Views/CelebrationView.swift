import SwiftUI

/// Star burst + "RENEWED!" banner shown each time `trigger` changes.
struct CelebrationView: View {
    let trigger: Int
    @State var shown: Int?

    var body: some View {
        ZStack {
            if let shown {
                CelebrationBurst()
                    .id(shown)
                    .transition(.opacity)
            }
        }
        .allowsHitTesting(false)
        .sensoryFeedback(.success, trigger: trigger)
        .onChange(of: trigger) { _, newValue in
            shown = newValue
            Task {
                try? await Task.sleep(for: .seconds(1.6))
                if shown == newValue {
                    withAnimation(.easeOut(duration: 0.3)) { shown = nil }
                }
            }
        }
        .accessibilityHidden(true)
    }
}

private struct CelebrationBurst: View {
    @State var exploded = false
    let count = 16

    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { index in
                let angle = Double(index) / Double(count) * 2 * Double.pi
                let distance: Double = index.isMultiple(of: 2) ? 150 : 110
                Image(systemName: index.isMultiple(of: 2) ? "star.fill" : "sparkle")
                    .font(.system(size: index.isMultiple(of: 3) ? 26 : 18, weight: .bold))
                    .foregroundStyle(color(for: index))
                    .offset(
                        x: exploded ? CGFloat(cos(angle) * distance) : 0,
                        y: exploded ? CGFloat(sin(angle) * distance) : 0
                    )
                    .scaleEffect(exploded ? 1 : 0.2)
                    .rotationEffect(.degrees(exploded ? 180 : 0))
                    .opacity(exploded ? 0 : 1)
                    .animation(.easeOut(duration: 1.1), value: exploded)
            }

            HStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(CardTint.yellow.strong)
                Text("RENEWED!")
                    .foregroundStyle(Theme.ink)
            }
            .font(.system(size: 28, weight: .black, design: .monospaced))
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(CardTint.yellow.soft))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.ink, lineWidth: 3))
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.ink).offset(y: 5))
            .scaleEffect(exploded ? 1 : 0.3)
            .rotationEffect(.degrees(exploded ? 0 : -8))
            .animation(.spring(response: 0.45, dampingFraction: 0.5), value: exploded)
        }
        // Deferred so the first frame renders collapsed and the change animates.
        .task { exploded = true }
    }

    private func color(for index: Int) -> Color {
        switch index % 3 {
        case 0: return CardTint.yellow.strong
        case 1: return CardTint.purple.strong
        default: return CardTint.pink.strong
        }
    }
}
