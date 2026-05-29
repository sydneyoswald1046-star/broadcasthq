import Combine
import Foundation

enum UserRole: String, Codable, CaseIterable {
    case admin
    case teamLead = "team_lead"
    case member
    
    var displayName: String {
        switch self {
        case .admin: return "Admin"
        case .teamLead: return "Director / Producer"
        case .member: return "Team Member"
        }
    }
}

enum PresenceStatus: String, Codable {
    case online, offline, busy
    
    var label: String {
        switch self {
        case .online: return "Online"
        case .busy: return "Busy"
        case .offline: return "Offline"
        }
    }
    
    var color: String {
        switch self {
        case .online: return "bhqGreen"
        case .busy: return "bhqYellow"
        case .offline: return "gray"
        }
    }
}

struct AppUser: Identifiable, Codable, Hashable {
    var id: String
    var email: String
    var displayName: String
    var role: UserRole
    var team: String
    var position: String
    var status: PresenceStatus
    var avatarUrl: String?
    var loginTime: Date?
    var phone: String?
    var joinedDate: Date?
    
    var initials: String {
        displayName.split(separator: " ")
            .prefix(2)
            .compactMap { $0.first.map(String.init) }
            .joined()
    }
    
    var loginTimeString: String {
        guard let loginTime = loginTime else { return "—" }
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: loginTime)
    }
    
    var joinedDateString: String {
        guard let joinedDate = joinedDate else { return "—" }
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: joinedDate)
    }
}

// MARK: - Sample Data (replace with Firestore later)
extension AppUser {
    static let samples: [AppUser] = [
        AppUser(id: "1", email: "marcus@bhq.com", displayName: "Marcus Johnson", role: .admin, team: "production", position: "Director", status: .online, loginTime: Calendar.current.date(bySettingHour: 8, minute: 30, second: 0, of: Date())),
        AppUser(id: "2", email: "sarah@bhq.com", displayName: "Sarah Kim", role: .member, team: "camera", position: "Camera 1", status: .online, loginTime: Calendar.current.date(bySettingHour: 8, minute: 45, second: 0, of: Date())),
        AppUser(id: "3", email: "david@bhq.com", displayName: "David Chen", role: .member, team: "camera", position: "Camera 2", status: .busy, loginTime: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())),
        AppUser(id: "4", email: "lisa@bhq.com", displayName: "Lisa Okafor", role: .teamLead, team: "audio", position: "Audio Engineer", status: .online, loginTime: Calendar.current.date(bySettingHour: 8, minute: 15, second: 0, of: Date())),
        AppUser(id: "5", email: "james@bhq.com", displayName: "James Wright", role: .member, team: "graphics", position: "Graphics Op", status: .offline, loginTime: nil),
        AppUser(id: "6", email: "maria@bhq.com", displayName: "Maria Santos", role: .teamLead, team: "production", position: "Tech Director", status: .online, loginTime: Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())),
        AppUser(id: "7", email: "andre@bhq.com", displayName: "Andre Williams", role: .member, team: "camera", position: "Camera 3", status: .online, loginTime: Calendar.current.date(bySettingHour: 9, minute: 10, second: 0, of: Date())),
        AppUser(id: "8", email: "priya@bhq.com", displayName: "Priya Patel", role: .member, team: "audio", position: "Audio Assist", status: .busy, loginTime: Calendar.current.date(bySettingHour: 9, minute: 5, second: 0, of: Date())),
    ]
}
