import SwiftUI

/// Three flat dots, no gradient, that say "the model is writing".
struct Pulse: View {
    @State private var phase = 0.0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Theme.inkSoft)
                    .frame(width: 4, height: 4)
                    .opacity(0.25 + 0.75 * max(0, sin(phase - Double(index) * 0.8)))
            }
        }
        .task {
            withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}
