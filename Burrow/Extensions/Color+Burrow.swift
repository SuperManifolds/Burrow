import SwiftUI

extension Color {
    /// Burrow's muted teal accent color — conveys security without being garish.
    static let burrowAccent = Color("AccentColor")

    /// Soft green for connected state.
    static let burrowConnected = Color(red: 0.30, green: 0.75, blue: 0.55)

    /// Neutral gray for disconnected state.
    static let burrowDisconnected = Color(red: 0.55, green: 0.55, blue: 0.58)

    /// Warning amber for connection issues.
    static let burrowWarning = Color(red: 0.95, green: 0.75, blue: 0.30)

    /// Error red for failures.
    static let burrowError = Color(red: 0.90, green: 0.35, blue: 0.35)
}

extension ShapeStyle where Self == Color {
    /// Color reflecting the current connection status.
    static func connectionStatus(_ status: ConnectionStatus) -> Color {
        switch status {
        case .connected:
            return .burrowConnected
        case .connecting, .disconnecting:
            return .burrowWarning
        case .disconnected:
            return .burrowDisconnected
        }
    }
}
