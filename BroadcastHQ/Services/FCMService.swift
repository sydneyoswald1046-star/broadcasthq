import Combine
import FirebaseMessaging
import UIKit
import UserNotifications

class FCMService: NSObject, ObservableObject, MessagingDelegate, UNUserNotificationCenterDelegate {
    static let shared = FCMService()
    
    @Published var fcmToken: String?
    
    func setup() {
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        // Don't request permission here — PermissionsView handles it
    }
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
    
    // MARK: - FCM Token
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        DispatchQueue.main.async {
            self.fcmToken = token
        }
        // Save to Firestore when we have org context
        saveTokenIfReady(token)
    }
    
    func saveTokenToFirestore() {
        if let token = Messaging.messaging().fcmToken {
            saveTokenIfReady(token)
        }
    }
    
    private func saveTokenIfReady(_ token: String) {
        let orgCode = FirestoreService.shared.orgCode
        guard !orgCode.isEmpty else { return }
        
        // Find current user ID from UserDefaults or AuthState
        guard let userId = UserDefaults.standard.string(forKey: "currentUserId") else { return }
        
        Task {
            try? await FirestoreService.shared.saveFCMToken(userId: userId, token: token)
        }
    }
    
    // MARK: - Handle notifications when app is in foreground
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    // MARK: - Handle notification tap
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        // Post notification for deep linking
        NotificationCenter.default.post(
            name: .pushNotificationTapped,
            object: nil,
            userInfo: userInfo
        )
        
        completionHandler()
    }
}

// MARK: - AppDelegate for APNs

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ APNs registration failed: \(error)")
    }

    // Route the external-display scene to our dedicated delegate so a connected
    // Apple TV / HDMI screen renders the auditorium timer instead of mirroring the
    // phone. All other scenes (the main app) keep SwiftUI's default handling.
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if connectingSceneSession.role == .windowExternalDisplayNonInteractive {
            let config = UISceneConfiguration(name: "External Display", sessionRole: connectingSceneSession.role)
            config.delegateClass = ExternalDisplaySceneDelegate.self
            return config
        }
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let pushNotificationTapped = Notification.Name("pushNotificationTapped")
    static let replayWalkthrough = Notification.Name("replayWalkthrough")
}
