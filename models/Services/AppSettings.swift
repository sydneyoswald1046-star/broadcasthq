import Combine
import SwiftUI

class AppSettings: ObservableObject {
    // Appearance
    @AppStorage("textSize") var textSize: Double = 1.0
    @AppStorage("accentColor") var accentColorKey: String = "red"
    @AppStorage("showLiveBorder") var showLiveBorder: Bool = true
    @AppStorage("animationsEnabled") var animationsEnabled: Bool = true
    @AppStorage("showAvatars") var showAvatars: Bool = true
    @AppStorage("compactMode") var compactMode: Bool = false
    
    // Notifications
    @AppStorage("notif_broadcastAlerts") var broadcastAlerts: Bool = true
    @AppStorage("notif_segmentChanges") var segmentChanges: Bool = true
    @AppStorage("notif_teamMessages") var teamMessages: Bool = true
    @AppStorage("notif_directMessages") var directMessages: Bool = true
    @AppStorage("notif_equipmentAlerts") var equipmentAlerts: Bool = true
    @AppStorage("notif_memberUpdates") var memberUpdates: Bool = false
    @AppStorage("notif_pttAlerts") var pttAlerts: Bool = true
    @AppStorage("notif_sound") var soundEnabled: Bool = true
    @AppStorage("notif_vibration") var vibrationEnabled: Bool = true
    
    var accentColor: Color {
        switch accentColorKey {
        case "blue": return Color.bhqBlue
        case "green": return Color.bhqGreen
        case "purple": return Color.bhqPurple
        case "orange": return Color.bhqOrange
        default: return Color.bhqTint
        }
    }
    
    var dynamicTypeSize: DynamicTypeSize {
        switch textSize {
        case 0.8: return .small
        case 0.9: return .medium
        case 1.0: return .large
        case 1.1: return .xLarge
        case 1.2: return .xxLarge
        case 1.3: return .xxxLarge
        default: return .large
        }
    }
    
    var spacing: CGFloat {
        compactMode ? 8 : 16
    }
    
    var cardPadding: CGFloat {
        compactMode ? 10 : 16
    }
    
    var avatarSize: CGFloat {
        compactMode ? 28 : 36
    }
}
