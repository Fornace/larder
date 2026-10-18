import SwiftUI

// MARK: - Surfaces

/// One flat card: solid surface, hairline border, generous radius.
struct Card: ViewModifier {
    var padding: CGFloat = 18
    var radius: CGFloat = Theme.radius

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.surface, in: .rect(cornerRadius: radius))
            .overlay {
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(Theme.line, lineWidth: 1)
            }
    }
}

/// The one field look: surface fill, hairline border, 12pt radius.
struct FieldShell: ViewModifier {
    var radius: CGFloat = 12
    var padding: CGFloat = 11

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 13)
            .padding(.vertical, padding)
            .background(Theme.surface, in: .rect(cornerRadius: radius))
            .overlay {
                RoundedRectangle(cornerRadius: radius).strokeBorder(Theme.line, lineWidth: 1)
            }
    }
}

extension View {
    func fieldShell(radius: CGFloat = 12, padding: CGFloat = 11) -> some View {
        modifier(FieldShell(radius: radius, padding: padding))
    }

    func card(padding: CGFloat = 18, radius: CGFloat = Theme.radius) -> some View {
        modifier(Card(padding: padding, radius: radius))
    }

    func pageBackground() -> some View {
        background(Theme.canvas.ignoresSafeArea())
    }
}

// MARK: - Type

/// Small tracked capitals that label a block without shouting.
struct Eyebrow: View {
    let text: String
    var tint: Color = Theme.inkSoft

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.4)
            .foregroundStyle(tint)
    }
}

/// A serif screen title with an optional count beside it.
struct ScreenTitle: View {
    let title: String
    var detail: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .font(Theme.display(34))
                .foregroundStyle(Theme.ink)
            if let detail {
                Text(detail)
                    .font(Theme.number(15))
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Controls

struct PrimaryButtonStyle: ButtonStyle {
    var fill: Color = Theme.moss
    var ink: Color = Theme.canvas

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.body(15, weight: .semibold))
            .foregroundStyle(ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(fill.opacity(configuration.isPressed ? 0.78 : 1), in: .rect(cornerRadius: 14))
            .contentShape(.rect(cornerRadius: 14))
    }
}

struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.body(15, weight: .medium))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Theme.surface.opacity(configuration.isPressed ? 0.6 : 1), in: .rect(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.line, lineWidth: 1)
            }
            .contentShape(.rect(cornerRadius: 14))
    }
}

/// A label with a solid tint, used for quantities, aisles and expiry.
struct Chip: View {
    let text: String
    var tint: Color = Theme.inkSoft
    var filled: Bool = false

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(filled ? Theme.canvas : tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(filled ? tint : Color.clear, in: .capsule)
            .overlay {
                if !filled {
                    Capsule().strokeBorder(tint.opacity(0.45), lineWidth: 1)
                }
            }
    }
}

/// Two taps with a visible hairline between them. Tighter than the system `Stepper`
/// and with enough contrast that it does not read as an empty pill.
struct QuantityStepper: View {
    var onMinus: () -> Void
    var onPlus: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            step("minus", action: onMinus)
            Rectangle()
                .fill(Theme.inkSoft.opacity(0.35))
                .frame(width: 1, height: 15)
            step("plus", action: onPlus)
        }
        .fixedSize()
        .background(Theme.surfaceSunken, in: .capsule)
    }

    private func step(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(width: 31, height: 30)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

/// A thin flat meter. Filled portion is solid moss, the rest is the sunken surface.
struct Meter: View {
    var value: Double
    var tint: Color = Theme.moss

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.surfaceSunken)
                Capsule()
                    .fill(tint)
                    .frame(width: max(0, min(1, value)) * proxy.size.width)
            }
        }
        .frame(height: 6)
    }
}

// MARK: - Empty states

struct EmptyNote: View {
    let title: String
    let line: String
    var action: (title: String, run: () -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(Theme.title(22))
                .foregroundStyle(Theme.ink)
            Text(line)
                .font(Theme.body(15))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            if let action {
                Button(action: action.run) {
                    HStack(spacing: 6) {
                        Text(action.title)
                            .font(Theme.body(15, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Theme.moss)
                    .padding(.vertical, 3)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 22)
    }
}

// MARK: - Platform chrome

extension View {
    /// Inline navigation title everywhere, and a clean canvas behind.
    func larderChrome() -> some View {
        self.pageBackground().navigationTitle("")
    }
}

extension View {
    /// Inline titles are a phone idea. On a Mac the window title already says where you are.
    func inlineTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}

#if os(iOS)
typealias PlatformImage = UIImage
#else
typealias PlatformImage = NSImage
#endif
