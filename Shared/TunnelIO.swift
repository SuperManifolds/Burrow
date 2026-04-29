import Foundation

/// Shared file I/O for tunnel log and transfer stats via the app group container.
nonisolated enum TunnelIO: Sendable {
    static let logFilename = "tunnel.log"
    static let statsFilename = "tunnel.stats"

    private static let containerURL = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: AppIdentifiers.appGroup)

    nonisolated static func readLog() -> String? {
        guard let url = containerURL?.appendingPathComponent(logFilename) else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    nonisolated static func readStats() -> (tx: UInt64, rx: UInt64)? {
        guard let url = containerURL?.appendingPathComponent(statsFilename),
              let data = try? Data(contentsOf: url),
              let stats = try? JSONDecoder().decode(TransferStats.self, from: data)
        else { return nil }
        return (tx: stats.tx, rx: stats.rx)
    }
}
