import Foundation
import UIKit
import UserNotifications
import FirebaseMessaging

final class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate, MessagingDelegate {
    static let shared = NotificationService()
    @Published private(set) var deviceToken: String?

    private override init() {
        super.init()
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorization() async throws {
        let settings = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        guard settings else { return }
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        // handle deep links for orders and runs
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        deviceToken = fcmToken
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid,
              let token = fcmToken else { return }
        Task {
            try? await AuthService.shared.updatePushToken(token, for: uid)
        }
    }
}
