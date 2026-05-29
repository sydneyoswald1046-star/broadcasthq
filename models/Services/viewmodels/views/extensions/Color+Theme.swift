import SwiftUI

extension Color {
    // Core
    static let bhqBackground = Color.black
    static let bhqCard = Color(white: 0.11)
    static let bhqCardElevated = Color(white: 0.17)
    static let bhqSeparator = Color(white: 0.33).opacity(0.34)
    
    // Accent
    static let bhqTint = Color(red: 1.0, green: 0.27, blue: 0.23)        // #FF453A — broadcast red
    static let bhqGreen = Color(red: 0.19, green: 0.82, blue: 0.35)      // #30D158
    static let bhqYellow = Color(red: 1.0, green: 0.84, blue: 0.04)      // #FFD60A
    static let bhqBlue = Color(red: 0.04, green: 0.52, blue: 1.0)        // #0A84FF
    static let bhqPurple = Color(red: 0.75, green: 0.35, blue: 0.95)     // #BF5AF2
    static let bhqOrange = Color(red: 1.0, green: 0.62, blue: 0.04)      // #FF9F0A
    static let bhqCyan = Color(red: 0.39, green: 0.82, blue: 1.0)        // #64D2FF
}

// MARK: - Role Theme System
struct RoleTheme {
    let name: String
    let primary: Color          // Main accent
    let secondary: Color        // Lighter accent
    let gradient: [Color]       // Profile/header gradient
    let glow: Color             // Glow effects
    let badge: String           // Role badge text
    let icon: String            // SF Symbol for role
    
    // Admin — Gold Premium
    static let admin = RoleTheme(
        name: "Gold",
        primary: Color(red: 0.85, green: 0.70, blue: 0.30),       // Rich gold
        secondary: Color(red: 0.95, green: 0.82, blue: 0.45),     // Light gold
        gradient: [
            Color(red: 0.85, green: 0.70, blue: 0.30),
            Color(red: 0.72, green: 0.55, blue: 0.15),
            Color(red: 0.55, green: 0.40, blue: 0.10)
        ],
        glow: Color(red: 0.85, green: 0.70, blue: 0.30),
        badge: "ADMIN",
        icon: "crown.fill"
    )
    
    // Director — Emerald
    static let director = RoleTheme(
        name: "Emerald",
        primary: Color(red: 0.18, green: 0.75, blue: 0.47),       // Emerald green
        secondary: Color(red: 0.30, green: 0.85, blue: 0.58),     // Light emerald
        gradient: [
            Color(red: 0.18, green: 0.75, blue: 0.47),
            Color(red: 0.10, green: 0.58, blue: 0.35),
            Color(red: 0.06, green: 0.40, blue: 0.22)
        ],
        glow: Color(red: 0.18, green: 0.75, blue: 0.47),
        badge: "DIRECTOR",
        icon: "film.fill"
    )
    
    // Producer — Jasper
    static let producer = RoleTheme(
        name: "Jasper",
        primary: Color(red: 0.80, green: 0.35, blue: 0.20),       // Jasper red-brown
        secondary: Color(red: 0.90, green: 0.48, blue: 0.30),     // Light jasper
        gradient: [
            Color(red: 0.80, green: 0.35, blue: 0.20),
            Color(red: 0.65, green: 0.25, blue: 0.12),
            Color(red: 0.48, green: 0.18, blue: 0.08)
        ],
        glow: Color(red: 0.80, green: 0.35, blue: 0.20),
        badge: "PRODUCER",
        icon: "theatermasks.fill"
    )
    
    // Default — no special theme for regular members
    static let member = RoleTheme(
        name: "Standard",
        primary: Color.secondary,
        secondary: Color.secondary.opacity(0.7),
        gradient: [Color(.systemFill), Color(.systemFill)],
        glow: Color.clear,
        badge: "MEMBER",
        icon: "person.fill"
    )
    
    // Get theme for user
    static func forUser(_ user: AppUser) -> RoleTheme {
        switch user.role {
        case .admin:
            return .admin
        case .teamLead:
            // Distinguish director vs producer by position
            let pos = user.position.lowercased()
            if pos.contains("producer") || pos.contains("production") || pos.contains("tech director") {
                return .producer
            } else {
                return .director
            }
        case .member:
            return .member
        }
    }
}

