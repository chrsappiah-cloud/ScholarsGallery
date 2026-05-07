import SwiftUI

public struct GalleryProminentButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background {
                if isEnabled {
                    GalleryGradients.primaryButton
                } else {
                    LinearGradient(
                        colors: [Color.white.opacity(0.10), Color.white.opacity(0.06)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: GalleryPalette.accent.opacity(isEnabled ? 0.30 : 0), radius: 12, y: 4)
            .scaleEffect(configuration.isPressed && isEnabled ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
