import OSLog

/// Centralized loggers for the Burrow app and daemon.
enum Log {
    static let tunnel = Logger(subsystem: AppIdentifiers.bundleID, category: "tunnel")
    static let connection = Logger(subsystem: AppIdentifiers.bundleID, category: "connection")
    static let account = Logger(subsystem: AppIdentifiers.bundleID, category: "account")
    static let relays = Logger(subsystem: AppIdentifiers.bundleID, category: "relays")
    static let api = Logger(subsystem: AppIdentifiers.bundleID, category: "api")
    static let notifications = Logger(subsystem: AppIdentifiers.bundleID, category: "notifications")
    static let daemon = Logger(subsystem: AppIdentifiers.daemonBundleID, category: "daemon")
    static let network = Logger(subsystem: AppIdentifiers.daemonBundleID, category: "network")
}
