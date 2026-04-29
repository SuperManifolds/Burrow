import Foundation
import ServiceManagement

/// BurrowDaemon — LaunchDaemon that manages a gotatun-cli process for
/// high-performance WireGuard tunneling via direct utun access.
///
/// Communicates with the Burrow app via XPC (Mach service).

let delegate = DaemonDelegate()
let listener = NSXPCListener(machServiceName: AppIdentifiers.daemonBundleID)
listener.delegate = delegate
listener.resume()

// Periodically check if the parent app still exists.
// If the user deletes Burrow.app, the daemon cleans up and exits.
Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
    guard !parentAppExists() else { return }
    Log.daemon.info("Parent app no longer exists, shutting down")
    TunnelService.shared.disconnect { }
    try? SMAppService.daemon(
        plistName: "\(AppIdentifiers.daemonBundleID).plist"
    ).unregister()
    exit(0)
}

Log.daemon.info("Started")
RunLoop.current.run()

private func parentAppExists() -> Bool {
    var pathBuf = [CChar](repeating: 0, count: Int(MAXPATHLEN))
    var size = UInt32(MAXPATHLEN)
    guard _NSGetExecutablePath(&pathBuf, &size) == 0 else { return true }

    var url = URL(fileURLWithPath: String(cString: pathBuf)).standardized
    while url.pathComponents.count > 1 {
        url = url.deletingLastPathComponent()
        if url.lastPathComponent.hasSuffix(".app") {
            return FileManager.default.fileExists(atPath: url.path)
        }
    }
    // Can't determine — assume it exists to avoid false positives
    return true
}
