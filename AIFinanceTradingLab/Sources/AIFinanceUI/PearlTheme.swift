import SwiftUI

public enum PearlTheme {
    public static let diamond = Color(red: 0.60, green: 0.92, blue: 1.00)
    public static let gold = Color(red: 0.88, green: 0.72, blue: 0.32)
    public static let rosemary = Color(red: 0.20, green: 0.37, blue: 0.28)
    public static let silver = Color.white.opacity(0.12)
    public static let ink = Color(red: 0.06, green: 0.08, blue: 0.13)
    public static let boardGradient = LinearGradient(
        colors: [Color.black, rosemary.opacity(0.28)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
