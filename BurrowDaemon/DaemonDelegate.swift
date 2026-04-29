import Foundation

/// Accepts incoming XPC connections from the Burrow app.
final class DaemonDelegate: NSObject, NSXPCListenerDelegate {
    func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection newConnection: NSXPCConnection
    ) -> Bool {
        // Verify the caller is signed by the same team.
        // Skipped when teamID is empty (ad-hoc signed debug builds)
        // so XPC works during development without Developer ID signing.
        if !teamID.isEmpty {
            let pid = newConnection.processIdentifier
            var code: SecCode?
            let attrs = [kSecGuestAttributePid: pid] as CFDictionary
            guard SecCodeCopyGuestWithAttributes(nil, attrs, [], &code) == errSecSuccess,
                  let code else {
                return false
            }

            var staticCode: SecStaticCode?
            guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess,
                  let staticCode else {
                return false
            }

            let requirement = "anchor apple generic and certificate leaf[subject.OU] = \"\(teamID)\""
            var req: SecRequirement?
            guard SecRequirementCreateWithString(requirement as CFString, [], &req) == errSecSuccess,
                  let req,
                  SecStaticCodeCheckValidity(staticCode, [], req) == errSecSuccess else {
                return false
            }
        }

        // Capture the connecting user's group container path for stats
        let uid = newConnection.effectiveUserIdentifier
        if TunnelService.shared.statsDirectory == nil,
           let pw = getpwuid(uid) {
            let home = String(cString: pw.pointee.pw_dir)
            let container = "\(home)/Library/Group Containers/\(AppIdentifiers.appGroup)"
            TunnelService.shared.statsDirectory = URL(fileURLWithPath: container)
        }

        let interface = NSXPCInterface(with: BurrowDaemonXPC.self)
        newConnection.exportedInterface = interface
        newConnection.exportedObject = TunnelService.shared
        newConnection.resume()
        return true
    }

    private lazy var teamID: String = {
        // Extract team ID from daemon's own code signature
        var myself: SecCode?
        SecCodeCopySelf([], &myself)
        guard let myself else { return "" }
        var staticSelf: SecStaticCode?
        SecCodeCopyStaticCode(myself, [], &staticSelf)
        guard let staticSelf else { return "" }
        var info: CFDictionary?
        SecCodeCopySigningInformation(staticSelf, [], &info)
        guard let dict = info as? [String: Any],
              let teamID = dict[kSecCodeInfoTeamIdentifier as String] as? String else {
            return ""
        }
        return teamID
    }()
}
