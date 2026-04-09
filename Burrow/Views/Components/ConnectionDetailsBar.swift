import SwiftUI

/// Bottom bar showing IP address, protocol, latency, and transfer stats.
struct ConnectionDetailsBar: View {
    let ipAddress: String?
    let ping: Int?
    let transferTx: UInt64
    let transferRx: UInt64

    @State private var copiedIP = false

    var body: some View {
        HStack(spacing: 10) {
            ConnectionDetailCard(label: String(localized: "IP Address")) {
                HStack(spacing: 6) {
                    Text(ipAddress ?? "—")
                        .font(.callout)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                    Image(systemName: copiedIP ? "checkmark" : "doc.on.doc")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .onTapGesture {
                if let ip = ipAddress {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(ip, forType: .string)
                    copiedIP = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        copiedIP = false
                    }
                }
            }
            .overlay(alignment: .top) {
                if copiedIP {
                    Text("Copied!")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.accent, in: RoundedRectangle(cornerRadius: 4))
                        .foregroundStyle(.white)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .offset(y: -24)
                }
            }
            .animation(.spring(duration: 0.3), value: copiedIP)
            .onHover { hovering in
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }

            ConnectionDetailCard(label: String(localized: "Protocol")) {
                Text("WireGuard")
                    .font(.callout)
                    .fontWeight(.semibold)
            }

            ConnectionDetailCard(label: String(localized: "Latency")) {
                if let ping {
                    HStack(spacing: 4) {
                        Text("\(ping) ms")
                            .font(.callout)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                        Text(latencyLabel(ping))
                            .font(.caption2)
                            .fontWeight(.medium)
                            .fixedSize()
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.ping(ping).opacity(0.2))
                            .foregroundStyle(Color.ping(ping))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                } else {
                    Text("—")
                        .font(.callout)
                        .fontWeight(.semibold)
                }
            }

            ConnectionDetailCard(label: String(localized: "Transfer")) {
                HStack(spacing: 8) {
                    Text("↑ \(ConnectionViewModel.formattedBytes(transferTx))")
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(Color(.systemGreen))
                    Text("↓ \(ConnectionViewModel.formattedBytes(transferRx))")
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(Color(.systemBlue))
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal)
    }

    private func latencyLabel(_ ms: Int) -> String {
        switch ms {
            case ..<50: String(localized: "Excellent")
            case ..<100: String(localized: "Great")
            case ..<150: String(localized: "Good")
            case ..<200: String(localized: "Fair")
            case ..<300: String(localized: "Slow")
            default: String(localized: "Poor")
        }
    }
}

#if DEBUG
#Preview {
    ConnectionDetailsBar(
        ipAddress: "185.213.154.68",
        ping: 24,
        transferTx: 1_207_959_552,
        transferRx: 356_515_840
    )
    .frame(width: 700)
    .padding()
}
#endif
