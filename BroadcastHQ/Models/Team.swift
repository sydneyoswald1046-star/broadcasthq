import SwiftUI

struct Team: Identifiable, Hashable {
    var id: String
    var name: String
    var color: Color
    var icon: String // SF Symbol name
    
    static let all: [Team] = [
        Team(id: "photography", name: "Photography", color: .bhqBlue, icon: "camera.fill"),
        Team(id: "broadcast", name: "Broadcast", color: .bhqTint, icon: "antenna.radiowaves.left.and.right"),
        Team(id: "projection", name: "Projection", color: .bhqPurple, icon: "rectangle.on.rectangle"),
        Team(id: "choir", name: "Choir", color: .bhqGreen, icon: "music.mic"),
        Team(id: "lights", name: "Lights", color: .bhqYellow, icon: "lightbulb.fill"),
    ]
    
    static func find(_ id: String) -> Team? {
        // Map old "choirlead" to "choir" for existing users
        let normalizedId = id == "choirlead" ? "choir" : id
        return all.first { $0.id == normalizedId }
    }
}
