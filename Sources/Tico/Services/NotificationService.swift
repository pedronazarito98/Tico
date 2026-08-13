import Foundation
import UserNotifications

protocol NotificationDelivering {
    func deliver(title: String, body: String) async throws
}

enum NotificationServiceError: LocalizedError, Equatable {
    case authorizationDenied

    var errorDescription: String? {
        "As notificações não foram autorizadas."
    }
}

final class NotificationService: NotificationDelivering {
    typealias AuthorizationRequester = () async throws -> Bool
    typealias RequestDeliverer = (UNNotificationRequest) async throws -> Void

    private let requestAuthorization: AuthorizationRequester
    private let deliverRequest: RequestDeliverer

    init(
        requestAuthorization: @escaping AuthorizationRequester = {
            try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        },
        deliverRequest: @escaping RequestDeliverer = {
            try await UNUserNotificationCenter.current().add($0)
        }
    ) {
        self.requestAuthorization = requestAuthorization
        self.deliverRequest = deliverRequest
    }

    func deliver(title: String, body: String) async throws {
        guard try await requestAuthorization() else {
            throw NotificationServiceError.authorizationDenied
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        try await deliverRequest(request)
    }
}
