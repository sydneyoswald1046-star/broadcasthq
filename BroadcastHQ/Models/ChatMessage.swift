import Combine
import Foundation

struct ChatMessage: Identifiable, Codable {
    var id: String
    var senderId: String
    var senderName: String
    var teamId: String?
    var recipientId: String?
    var text: String
    var type: String // "text" or "ptt_audio"
    var broadcastId: String?
    var timestamp: Date
    
    var isDM: Bool { recipientId != nil }
    
    var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: timestamp)
    }
    
    var senderInitials: String {
        senderName.split(separator: " ")
            .prefix(2)
            .compactMap { $0.first.map(String.init) }
            .joined()
    }
}

// MARK: - Sample Data
extension ChatMessage {
    static let samples: [ChatMessage] = [
        ChatMessage(id: "1", senderId: "1", senderName: "Marcus Johnson", teamId: "production", text: "Standby — worship set transition in 30 seconds", type: "text", broadcastId: "b1", timestamp: Date()),
        ChatMessage(id: "2", senderId: "2", senderName: "Sarah Kim", teamId: "camera", text: "Camera 1 locked, ready for close-up", type: "text", broadcastId: "b1", timestamp: Date()),
        ChatMessage(id: "3", senderId: "4", senderName: "Lisa Okafor", teamId: "audio", text: "Vocals hot. Drums need +2dB on fader 7", type: "text", broadcastId: "b1", timestamp: Date()),
        ChatMessage(id: "4", senderId: "1", senderName: "Marcus Johnson", teamId: "production", text: "Graphics — prep announcement slides now", type: "text", broadcastId: "b1", timestamp: Date()),
        ChatMessage(id: "5", senderId: "7", senderName: "Andre Williams", teamId: "camera", text: "Cam 3 moving to balcony position", type: "text", broadcastId: "b1", timestamp: Date()),
    ]
}
