import Foundation

enum ConferenceAccessMode: String, Codable {
    case open
    case invite
}

struct ConferenceParticipant: Identifiable, Codable, Hashable {
    var id: String { userId }
    var userId: String
    var displayName: String
    var joinedAt: Date
    var lastSeen: Date
}

struct ConferenceRoom: Identifiable, Codable {
    var id: String
    var name: String
    var createdBy: String
    var createdByName: String
    var createdAt: Date
    var accessMode: ConferenceAccessMode
    var invitedUserIds: [String]
    var participants: [ConferenceParticipant]
    var isActive: Bool

    var participantCount: Int { participants.count }
    var isEmpty: Bool { participants.isEmpty }

    func isUserInvited(_ userId: String) -> Bool {
        accessMode == .open || createdBy == userId || invitedUserIds.contains(userId)
    }
}
