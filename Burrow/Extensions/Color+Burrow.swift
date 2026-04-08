import SwiftUI

extension ShapeStyle where Self == Color {
    /// Color reflecting the current connection status.
    static func connectionStatus(_ status: ConnectionStatus) -> Color {
        switch status {
            case .connected:
                return Color(.systemGreen)
            case .connecting, .disconnecting:
                return Color(.systemOrange)
            case .disconnected:
                return Color(.systemGray)
        }
    }

    /// Color reflecting ping latency quality.
    static func ping(_ ms: Int) -> Color {
        switch ms {
            case ..<25:     Color(.systemGreen)
            case ..<50:     Color(.systemMint)
            case ..<80:     Color(.systemTeal)
            case ..<120:    Color(.systemYellow)
            case ..<180:    Color(.systemOrange)
            case ..<250:    Color(.systemPink)
            default:        Color(.systemRed)
        }
    }
}
