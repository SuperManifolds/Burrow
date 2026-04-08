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
            case ..<50:     Color(.systemGreen)
            case ..<100:    Color(.systemMint)
            case ..<150:    Color(.systemTeal)
            case ..<200:    Color(.systemYellow)
            case ..<300:    Color(.systemOrange)
            case ..<500:    Color(.systemPink)
            default:        Color(.systemRed)
        }
    }
}
