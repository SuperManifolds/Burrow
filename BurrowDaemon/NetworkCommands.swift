import Foundation

// MARK: - Shell Runner

private func run(_ path: String, _ arguments: [String]) -> (status: Int32, output: String) {
    let task = Process()
    let pipe = Pipe()
    task.executableURL = URL(fileURLWithPath: path)
    task.arguments = arguments
    task.standardOutput = pipe
    task.standardError = pipe
    do {
        try task.run()
    } catch {
        Log.network.error("Failed to run \(path): \(error.localizedDescription)")
        return (-1, "")
    }
    task.waitUntilExit()
    let output = String(
        data: pipe.fileHandleForReading.readDataToEndOfFile(),
        encoding: .utf8
    ) ?? ""
    return (task.terminationStatus, output)
}

@discardableResult
private func exec(_ path: String, _ arguments: [String]) -> Int32 {
    let result = run(path, arguments)
    if result.status != 0 {
        let cmd = ([path] + arguments).joined(separator: " ")
        Log.network.warning("\(cmd) exited with \(result.status)")
    }
    return result.status
}

// MARK: - Route

enum Route {
    private static let bin = "/sbin/route"

    @discardableResult
    static func addHost(_ ip: String, gateway: String) -> Int32 {
        exec(bin, ["-n", "add", "-host", ip, gateway])
    }

    @discardableResult
    static func deleteHost(_ ip: String) -> Int32 {
        exec(bin, ["-n", "delete", "-host", ip])
    }

    @discardableResult
    static func addNet(_ cidr: String, interface: String) -> Int32 {
        exec(bin, ["-n", "add", "-net", cidr, "-interface", interface])
    }

    @discardableResult
    static func deleteNet(_ cidr: String, interface: String) -> Int32 {
        exec(bin, ["-n", "delete", "-net", cidr, "-interface", interface])
    }

    static func defaultGateway() -> String? {
        let result = run(bin, ["-n", "get", "default"])
        return parseLine(from: result.output, prefix: "gateway:")
    }

    static func defaultInterface() -> String? {
        let result = run(bin, ["-n", "get", "default"])
        return parseLine(from: result.output, prefix: "interface:")
    }

    private static func parseLine(from output: String, prefix: String) -> String? {
        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix(prefix) {
                let value = trimmed.dropFirst(prefix.count)
                    .trimmingCharacters(in: .whitespaces)
                return value.isEmpty ? nil : value
            }
        }
        return nil
    }
}

// MARK: - NetworkSetup

enum NetworkSetup {
    private static let bin = "/usr/sbin/networksetup"

    @discardableResult
    static func setDNS(service: String, server: String) -> Int32 {
        exec(bin, ["-setdnsservers", service, server])
    }

    static func getDNS(service: String) -> String? {
        let result = run(bin, ["-getdnsservers", service])
        let firstLine = result.output
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "\n").first ?? ""
        // "There aren't any DNS Servers set on ..." means no custom DNS
        return firstLine.contains("aren't") ? nil : firstLine
    }

    private static let defaultService = "Wi-Fi"

    /// Detect the active network service name (e.g. "Wi-Fi", "Ethernet").
    static func activeService() -> String {
        guard let iface = Route.defaultInterface() else { return defaultService }

        let result = run(bin, ["-listallhardwareports"])
        var currentService: String?
        for line in result.output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("Hardware Port:") {
                currentService = String(trimmed.dropFirst("Hardware Port: ".count))
            } else if trimmed.hasPrefix("Device:") {
                let device = String(trimmed.dropFirst("Device: ".count))
                if device == iface, let service = currentService {
                    return service
                }
            }
        }
        return defaultService
    }
}

// MARK: - InterfaceConfig

enum InterfaceConfig {
    private static let bin = "/sbin/ifconfig"

    @discardableResult
    static func setMTU(_ interface: String, mtu: Int) -> Int32 {
        exec(bin, [interface, "mtu", "\(mtu)"])
    }

    @discardableResult
    static func setIPv4(_ interface: String, address: String) -> Int32 {
        exec(bin, [interface, "inet", address, address, "netmask", "255.255.255.255", "up"])
    }

    @discardableResult
    static func setIPv6(_ interface: String, address: String) -> Int32 {
        exec(bin, [interface, "inet6", address, "prefixlen", "128"])
    }
}

// MARK: - ProcessControl

enum ProcessControl {
    @discardableResult
    static func kill(name: String) -> Int32 {
        exec("/usr/bin/pkill", ["-9", "-x", name])
    }
}
