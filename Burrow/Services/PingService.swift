import Foundation
import Network
import os

/// Measures TCP handshake latency to relay servers off the main actor.
final class PingService: Sendable {

    /// Measure latency to multiple hosts, 20 at a time. Returns only successful results.
    func measureAll(_ targets: [(id: String, host: String)], port: UInt16 = 443) async -> [(String, Int)] {
        await withTaskGroup(of: (String, Int?).self) { group in
            var results: [(String, Int)] = []
            var index = 0

            for _ in 0..<min(20, targets.count) {
                let target = targets[index]
                index += 1
                group.addTask { (target.id, await self.measure(host: target.host, port: port)) }
            }

            for await (id, ms) in group {
                if let ms { results.append((id, ms)) }
                if index < targets.count {
                    let target = targets[index]
                    index += 1
                    group.addTask { (target.id, await self.measure(host: target.host, port: port)) }
                }
            }

            return results
        }
    }

    /// Measure TCP handshake time to a single host. Returns nil on timeout.
    private func measure(host: String, port: UInt16, timeout: Duration = .seconds(3)) async -> Int? {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return nil }
        let connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp)
        let start = ContinuousClock.now
        let resumed = OSAllocatedUnfairLock(initialState: false)

        return await withCheckedContinuation { continuation in
            connection.stateUpdateHandler = { state in
                guard case .ready = state else { return }
                let alreadyResumed = resumed.withLock { val -> Bool in
                    if val { return true }
                    val = true
                    return false
                }
                guard !alreadyResumed else { return }
                let ms = Int((ContinuousClock.now - start) / .milliseconds(1))
                connection.cancel()
                continuation.resume(returning: ms)
            }

            connection.start(queue: .global(qos: .utility))

            // Timeout
            DispatchQueue.global().asyncAfter(deadline: .now() + Double(timeout.components.seconds)) {
                let alreadyResumed = resumed.withLock { val -> Bool in
                    if val { return true }
                    val = true
                    return false
                }
                guard !alreadyResumed else { return }
                connection.cancel()
                continuation.resume(returning: nil)
            }
        }
    }
}
