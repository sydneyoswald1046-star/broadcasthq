import UserNotifications
import Combine
import SwiftUI

class PushNotificationService: ObservableObject {
    static let shared = PushNotificationService()
    
    @Published var hasPermission: Bool = false
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.hasPermission = granted
            }
            if let error = error {
                print("❌ Notification permission error: \(error)")
            }
        }
    }
    
    func checkPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.hasPermission = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - Send Local Notifications
    
    func sendTeamAlertNotification(from sender: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = "Team Alert"
        content.subtitle = sender
        content.body = message
        content.sound = .defaultCritical
        content.interruptionLevel = .timeSensitive
        
        let request = UNNotificationRequest(
            identifier: "teamAlert-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
    
    func sendMessageNotification(from sender: String, message: String, isDM: Bool) {
        let content = UNMutableNotificationContent()
        content.title = isDM ? sender : "Team Chat"
        content.subtitle = isDM ? "Direct Message" : sender
        content.body = message
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "message-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
    
    func sendSegmentChangeNotification(segmentTitle: String, changedBy: String) {
        let content = UNMutableNotificationContent()
        content.title = "Now Live"
        content.subtitle = segmentTitle
        content.body = "Changed by \(changedBy)"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "segment-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
    
    func sendBroadcastNotification(isLive: Bool) {
        let content = UNMutableNotificationContent()
        content.title = isLive ? "We're Live" : "Broadcast Ended"
        content.body = isLive ? "Get to your position" : "Great job team"
        content.sound = isLive ? .defaultCritical : .default
        if isLive { content.interruptionLevel = .timeSensitive }
        
        let request = UNNotificationRequest(
            identifier: "broadcast-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
    
    func sendEquipmentNotification(itemName: String, issue: String) {
        let content = UNMutableNotificationContent()
        content.title = "Gear Issue"
        content.subtitle = itemName
        content.body = issue
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "equipment-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
    
    func sendConferenceInviteNotification(roomName: String, fromName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Conference Invite"
        content.subtitle = fromName
        content.body = "You're invited to \(roomName)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "conference-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // Clear badge
    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }
}
