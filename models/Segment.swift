import Foundation

enum SegmentStatus: String, Codable {
    case upcoming = "upcoming"
    case live = "live"
    case completed = "completed"
}

struct Segment: Identifiable {
    var id: String
    var order: Int
    var title: String
    var duration: Int // seconds
    var assignedRole: String
    var status: SegmentStatus
    var notes: String
    var description: String
    
    var formattedDuration: String {
        Segment.formatTime(duration)
    }
    
    static func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return s > 0 ? "\(m):\(String(format: "%02d", s))" : "\(m):00"
    }
}

extension Segment {
    static let samples: [Segment] = [
        Segment(id: "s1", order: 0, title: "Welcome & Opening", duration: 300, assignedRole: "Camera 1", status: .upcoming, notes: "Wide shot opening", description: "Start with wide shot of stage, slowly zoom to pastor. Hold steady."),
        Segment(id: "s2", order: 1, title: "Worship Set", duration: 1200, assignedRole: "Camera 2", status: .upcoming, notes: "Follow worship leader", description: "Track worship leader movements. Cut between band members on cue from director."),
        Segment(id: "s3", order: 2, title: "Announcements", duration: 300, assignedRole: "Graphics", status: .upcoming, notes: "Lower thirds ready", description: "Display announcement slides. Have QR codes ready for giving and events."),
        Segment(id: "s4", order: 3, title: "Message", duration: 2400, assignedRole: "Camera 1", status: .upcoming, notes: "Teleprompter on", description: "Primary shot on speaker. Cut to scripture slides when referenced. Watch for sermon illustrations."),
        Segment(id: "s5", order: 4, title: "Altar Call", duration: 600, assignedRole: "Camera 2", status: .upcoming, notes: "Soft lighting", description: "Wide shot of altar area. Dim lighting transition. Soft focus on prayer team."),
        Segment(id: "s6", order: 5, title: "Offering", duration: 300, assignedRole: "Graphics", status: .upcoming, notes: "QR codes & giving info", description: "Display giving information, PayPal/CashApp details, QR codes on screen."),
        Segment(id: "s7", order: 6, title: "Closing & Benediction", duration: 180, assignedRole: "Camera 1", status: .upcoming, notes: "Wide pull-out shot", description: "Final wide shot. Slowly pull out as pastor gives benediction. Fade to logo."),
    ]
}

