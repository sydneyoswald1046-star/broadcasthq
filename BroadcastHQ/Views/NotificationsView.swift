import SwiftUI

enum NotificationType: String {
    case alert, segment, equipment, member, message, broadcast
    
    var icon: String {
        switch self {
        case .alert: return "bolt.fill"
        case .segment: return "forward.end.fill"
        case .equipment: return "gearshape.fill"
        case .member: return "person.crop.circle.fill"
        case .message: return "bubble.left.fill"
        case .broadcast: return "dot.radiowaves.left.and.right"
        }
    }
    
    var color: Color {
        switch self {
        case .alert: return Color.bhqTint
        case .segment: return Color.bhqBlue
        case .equipment: return Color.bhqYellow
        case .member: return Color.bhqGreen
        case .message: return Color.purple
        case .broadcast: return Color.bhqTint
        }
    }
}

struct AppNotification: Identifiable {
    let id: String
    let type: NotificationType
    let title: String
    let body: String
    let time: Date
    var isRead: Bool
    
    var timeString: String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: time, relativeTo: Date())
    }
}

struct NotificationsView: View {
    @EnvironmentObject var authState: AuthState
    @Environment(\.dismiss) var dismiss
    @State private var notifications: [AppNotification] = []
    @State private var isLoading: Bool = true
    
    private var unreadCount: Int { notifications.filter { !$0.isRead }.count }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .padding(.top, 40)
                } else if notifications.isEmpty {
                    emptyState
                } else {
                    if unreadCount > 0 { unreadHeader }
                    
                    VStack(spacing: 0) {
                        ForEach(Array(notifications.enumerated()), id: \.element.id) { index, notif in
                            notificationRow(notif: notif)
                            if index < notifications.count - 1 {
                                Divider().padding(.leading, 64)
                            }
                        }
                    }
                    .background(Color.bhqCard)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .background(Color.bhqBackground)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if unreadCount > 0 {
                    Button { markAllRead() } label: {
                        Text("Read All")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.bhqBlue)
                    }
                }
            }
        }
        .onAppear { buildNotifications() }
        .onChange(of: authState.teamAlertHistory.count) { _, _ in buildNotifications() }
        .onChange(of: authState.messages.count) { _, _ in buildNotifications() }
    }
    
    // MARK: - Build from real data
    private func buildNotifications() {
        var items: [AppNotification] = []
        
        // Team alerts
        for alert in authState.teamAlertHistory {
            items.append(AppNotification(
                id: "alert-\(alert.id)",
                type: .alert,
                title: "Team Alert",
                body: "\(alert.senderName): \(alert.message)",
                time: alert.timestamp,
                isRead: alert.read
            ))
        }
        
        // Recent DMs to me (last 20)
        let myId = authState.currentUser?.id ?? ""
        let myDMs = authState.messages.filter { $0.recipientId == myId }.suffix(20)
        for msg in myDMs {
            items.append(AppNotification(
                id: "dm-\(msg.id)",
                type: .message,
                title: "DM from \(msg.senderName)",
                body: msg.text,
                time: msg.timestamp,
                isRead: true
            ))
        }
        
        // Recent team messages mentioning my position (last 10)
        let myPosition = authState.currentUser?.position ?? ""
        let mentions = authState.messages.filter {
            $0.recipientId == nil && $0.senderId != myId && $0.text.localizedCaseInsensitiveContains(myPosition)
        }.suffix(5)
        for msg in mentions {
            items.append(AppNotification(
                id: "mention-\(msg.id)",
                type: .message,
                title: "Mentioned by \(msg.senderName)",
                body: msg.text,
                time: msg.timestamp,
                isRead: true
            ))
        }
        
        // Segment change alerts
        if let segAlert = authState.activeAlert {
            items.append(AppNotification(
                id: "seg-\(segAlert.id)",
                type: .segment,
                title: "Segment: \(segAlert.type.rawValue)",
                body: "\(segAlert.changedBy) — \(segAlert.segmentTitle)",
                time: segAlert.timestamp,
                isRead: false
            ))
        }
        
        // Broadcast state change
        if authState.isBroadcastLive, let startTime = authState.broadcastStartTime {
            items.append(AppNotification(
                id: "broadcast-live",
                type: .broadcast,
                title: "Broadcast Started",
                body: "Your team is now live",
                time: startTime,
                isRead: true
            ))
        }
        
        // Sort by time, newest first
        items.sort { $0.time > $1.time }
        
        withAnimation(.easeOut(duration: 0.2)) {
            notifications = items
            isLoading = false
        }
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 40)
            Image(systemName: "bell")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Color.secondary.opacity(0.25))
            Text("No Notifications")
                .font(.system(size: 18, weight: .semibold))
            Text("Alerts, messages, and broadcast updates\nwill show up here.")
                .font(.system(size: 14))
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Unread Header
    private var unreadHeader: some View {
        HStack(spacing: 8) {
            Circle().fill(Color.bhqTint).frame(width: 8, height: 8)
            Text("\(unreadCount) unread")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.bhqTint)
            Spacer()
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Notification Row
    private func notificationRow(notif: AppNotification) -> some View {
        Button { markRead(notif.id) } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: notif.type.icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(notif.type.color)
                    .frame(width: 36, height: 36)
                    .background(notif.type.color.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(notif.title)
                            .font(.system(size: 14, weight: notif.isRead ? .regular : .semibold))
                            .foregroundStyle(Color.primary)
                        Spacer()
                        Text(notif.timeString)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.secondary.opacity(0.5))
                    }
                    Text(notif.body)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                if !notif.isRead {
                    Circle()
                        .fill(Color.bhqTint)
                        .frame(width: 8, height: 8)
                        .padding(.top, 6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(notif.isRead ? Color.clear : Color.bhqTint.opacity(0.03))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Actions
    private func markRead(_ id: String) {
        if let index = notifications.firstIndex(where: { $0.id == id }) {
            withAnimation { notifications[index].isRead = true }
            
            let notif = notifications[index]
            var targetTab: String?
            
            if notif.id.hasPrefix("dm-") {
                let msgId = String(notif.id.dropFirst(3))
                if let msg = authState.messages.first(where: { $0.id == msgId }) {
                    authState.deepLinkDMUserId = msg.senderId
                    targetTab = "dms"
                }
            } else if notif.type == .message {
                targetTab = "comms"
            } else if notif.type == .segment || notif.type == .broadcast {
                targetTab = "dashboard"
            } else if notif.type == .equipment {
                targetTab = "equipment"
            }
            
            if let targetTab = targetTab {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    authState.deepLinkTab = targetTab
                }
            }
        }
    }
    
    private func markAllRead() {
        withAnimation {
            for i in notifications.indices { notifications[i].isRead = true }
        }
    }
}

#Preview {
    NavigationStack { NotificationsView().environmentObject(AuthState()) }.preferredColorScheme(.dark)
}
