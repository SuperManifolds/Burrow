import Foundation
import OSLog
import UserNotifications

/// Posts macOS notifications for VPN connection state changes.
@MainActor
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {

    static let connectedCategory = "CONNECTED"
    static let disconnectedCategory = "DISCONNECTED"
    static let disconnectAction = "DISCONNECT_ACTION"
    static let reconnectAction = "RECONNECT_ACTION"

    var onDisconnect: (() async -> Void)?
    var onReconnect: (() async -> Void)?

    private let center = UNUserNotificationCenter.current()
    private var isAuthorized = false

    override init() {
        super.init()
        center.delegate = self

        let disconnect = UNNotificationAction(
            identifier: Self.disconnectAction,
            title: String(localized: "Disconnect")
        )
        let reconnect = UNNotificationAction(
            identifier: Self.reconnectAction,
            title: String(localized: "Reconnect")
        )

        center.setNotificationCategories([
            UNNotificationCategory(
                identifier: Self.connectedCategory,
                actions: [disconnect],
                intentIdentifiers: []
            ),
            UNNotificationCategory(
                identifier: Self.disconnectedCategory,
                actions: [reconnect],
                intentIdentifiers: []
            )
        ])

        Task { await requestPermission() }
    }

    // MARK: - Public API

    func postConnected(location: String?, hostname: String?) {
        guard isAuthorized else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Connected")
        content.body = location ?? String(localized: "VPN tunnel active")
        if let hostname { content.subtitle = hostname }
        content.categoryIdentifier = Self.connectedCategory
        content.sound = nil
        post(content, id: "connection-state")
    }

    func postDisconnected(userInitiated: Bool) {
        guard isAuthorized else { return }
        let content = UNMutableNotificationContent()
        if userInitiated {
            content.title = String(localized: "VPN Disconnected")
        } else {
            content.title = String(localized: "VPN Connection Lost")
            content.body = String(localized: "The VPN connection dropped unexpectedly.")
        }
        content.categoryIdentifier = Self.disconnectedCategory
        content.sound = userInitiated ? nil : .default
        post(content, id: "connection-state")
    }

    func postConnectionFailed(error: String) {
        guard isAuthorized else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Connection Failed")
        content.body = error
        content.sound = .default
        post(content, id: "connection-state")
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionID = response.actionIdentifier
        Task { @MainActor in
            switch actionID {
                case Self.disconnectAction:
                    await onDisconnect?()
                case Self.reconnectAction:
                    await onReconnect?()
                default:
                    break
            }
            completionHandler()
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner])
    }

    // MARK: - Private

    private func requestPermission() async {
        do {
            isAuthorized = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            Log.notifications.error("Permission request failed: \(error)")
        }
    }

    private func post(_ content: UNMutableNotificationContent, id: String) {
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        center.add(request)
    }
}
