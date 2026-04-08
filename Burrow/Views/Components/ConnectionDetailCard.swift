import SwiftUI

/// A small info card for displaying connection details (IP, protocol, latency, transfer).
struct ConnectionDetailCard<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            content()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
    }
}

#if DEBUG
#Preview {
    HStack(spacing: 10) {
        ConnectionDetailCard(label: "IP Address") {
            Text("185.213.154.68")
                .font(.callout)
                .fontWeight(.semibold)
        }
        ConnectionDetailCard(label: "Protocol") {
            Text("WireGuard")
                .font(.callout)
                .fontWeight(.semibold)
        }
        ConnectionDetailCard(label: "Latency") {
            HStack(spacing: 4) {
                Text("24 ms")
                    .font(.callout)
                    .fontWeight(.semibold)
                Text("Excellent")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.systemGreen).opacity(0.2))
                    .foregroundStyle(Color(.systemGreen))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        ConnectionDetailCard(label: "Transfer") {
            HStack(spacing: 8) {
                Text("↑ 1.12 GB")
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(Color(.systemGreen))
                Text("↓ 340 MB")
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(Color(.systemBlue))
            }
        }
    }
    .fixedSize(horizontal: false, vertical: true)
    .padding()
    .frame(width: 700)
}
#endif
