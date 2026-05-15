import SwiftUI

public struct PearlCard<Content: View>: View {
    public let title: String
    public let icon: String
    @ViewBuilder public let content: Content

    public init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.linearGradient(colors: [.white, PearlTheme.diamond], startPoint: .top, endPoint: .bottom))
                Text(title)
                    .font(.footnote.smallCaps())
                    .foregroundStyle(.secondary)
            }
            content
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.15), PearlTheme.diamond.opacity(0.45)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: .black.opacity(0.45), radius: 22, x: 0, y: 18)
    }
}
