import SwiftUI

/// Connect/Disconnect toggle button.
struct ConnectButton: View {
    let isActive: Bool
    let isDisabled: Bool
    let onConnect: () -> Void
    let onDisconnect: () -> Void

    var body: some View {
        Button {
            if isActive {
                onDisconnect()
            } else {
                onConnect()
            }
        } label: {
            Text(isActive ? String(localized: "Disconnect") : String(localized: "Connect"))
                .frame(minWidth: 140)
        }
        .buttonStyle(.borderedProminent)
        .tint(isActive ? .red : .accentColor)
        .controlSize(.large)
        .hoverScale()
        .disabled(isDisabled)
    }
}

#if DEBUG
#Preview("Connect") {
    ConnectButton(
        isActive: false,
        isDisabled: false,
        onConnect: {},
        onDisconnect: {}
    )
    .padding()
}

#Preview("Disconnect") {
    ConnectButton(
        isActive: true,
        isDisabled: false,
        onConnect: {},
        onDisconnect: {}
    )
    .padding()
}
#endif
