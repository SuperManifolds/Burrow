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
}
