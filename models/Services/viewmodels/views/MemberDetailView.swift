import SwiftUI

struct MemberDetailView: View {
    let member: AppUser
    @State private var showDirectMessage: Bool = false
    
    private var team: Team? { Team.find(member.team) }
    private var theme: RoleTheme { RoleTheme.forUser(member) }
    private var isPrivileged: Bool { member.role == .admin || member.role == .teamLead }
    private var memberEquipment: [Equipment] {
        Equipment.samples.filter { $0.assignedTo == member.displayName }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                profileHeader
                statusBadge
                messageButton
                infoSection
                equipmentSection
            }
            .padding(.vertical)
        }
        .background(Color.bhqBackground)
        .navigationTitle(member.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showDirectMessage) {
            DirectMessageView(member: member)
        }
    }
    
    // MARK: - Profile Header
    private var profileHeader: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: isPrivileged ? theme.gradient : [team?.color ?? Color.bhqTint, (team?.color ?? Color.bhqTint).opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .overlay {
                        Text(member.initials)
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(Color.white)
                    }
                    .overlay(
                        Circle().stroke(
                            isPrivileged
                                ? LinearGradient(colors: [theme.secondary, theme.primary], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [statusColor, statusColor], startPoint: .top, endPoint: .bottom),
                            lineWidth: isPrivileged ? 3 : 2
                        )
                        .frame(width: 108, height: 108)
                    )
                    .shadow(color: isPrivileged ? theme.glow.opacity(0.25) : Color.clear, radius: 10)
                
                Circle()
                    .fill(statusColor)
                    .frame(width: 20, height: 20)
                    .overlay(Circle().stroke(Color.black, lineWidth: 3))
            }
            
            Text(member.displayName)
                .font(.system(size: 24, weight: .bold))
            
            // Themed role badge
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: theme.icon)
                        .font(.system(size: 10, weight: .bold))
                    Text(theme.badge)
                        .font(.system(size: 12, weight: .bold))
                        .tracking(0.5)
                }
                .foregroundStyle(theme.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    LinearGradient(colors: [theme.primary.opacity(0.15), theme.primary.opacity(0.08)],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .overlay(
                    Capsule().stroke(theme.primary.opacity(isPrivileged ? 0.3 : 0), lineWidth: 0.5)
                )
                .clipShape(Capsule())
                
                if let team = team {
                    HStack(spacing: 4) {
                        Image(systemName: team.icon).font(.system(size: 10))
                        Text(team.name).font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(team.color)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(team.color.opacity(0.15))
                    .clipShape(Capsule())
                }
            }
            
            // Theme label
            if isPrivileged {
                Text("\(theme.name) Theme")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.primary.opacity(0.6))
                    .tracking(1)
            }
            
            Text(member.position)
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
    
    private var statusColor: Color {
        switch member.status {
        case .online: return Color.bhqGreen
        case .busy: return Color.bhqYellow
        case .offline: return Color(.systemGray3)
        }
    }
    
    // MARK: - Status Badge
    private var statusBadge: some View {
        HStack(spacing: 8) {
            Circle().fill(statusColor).frame(width: 10, height: 10)
            Text(member.status == .online ? "Online" : member.status == .busy ? "Busy" : "Offline")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(statusColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(statusColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
    
    // MARK: - Message Button
    private var messageButton: some View {
        Button { showDirectMessage = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "message.fill").font(.system(size: 16, weight: .semibold))
                Text("Message \(member.displayName.split(separator: " ").first ?? "")").font(.system(size: 16, weight: .semibold))
                Spacer()
                Image(systemName: "mic.fill").font(.system(size: 14)).foregroundStyle(Color.white.opacity(0.7))
                Text("PTT").font(.system(size: 12, weight: .bold)).foregroundStyle(Color.white.opacity(0.7))
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 20).padding(.vertical, 14)
            .background(LinearGradient(colors: [Color.bhqBlue, Color.bhqBlue.opacity(0.8)], startPoint: .leading, endPoint: .trailing))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal)
    }
    
    // MARK: - Info Section
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("INFORMATION").font(.footnote).foregroundStyle(Color.secondary).padding(.horizontal)
            VStack(spacing: 0) {
                infoRow(icon: "envelope.fill", label: "Email", value: member.email)
                Divider().padding(.leading, 52)
                infoRow(icon: "person.badge.shield.checkmark", label: "Role", value: member.role.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                Divider().padding(.leading, 52)
                infoRow(icon: "person.3.fill", label: "Team", value: member.team.capitalized)
                Divider().padding(.leading, 52)
                infoRow(icon: "briefcase.fill", label: "Position", value: member.position)
                Divider().padding(.leading, 52)
                infoRow(icon: "clock", label: "Last Seen", value: member.loginTimeString)
            }
            .background(Color.bhqCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }
    
    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 14)).foregroundStyle(Color.secondary)
                .frame(width: 28, height: 28).background(Color(.systemFill)).clipShape(RoundedRectangle(cornerRadius: 6))
            Text(label).font(.body).foregroundStyle(Color.secondary)
            Spacer()
            Text(value).font(.body).foregroundStyle(Color.primary).lineLimit(1)
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
    }
    
    // MARK: - Equipment Section
    private var equipmentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ASSIGNED EQUIPMENT").font(.footnote).foregroundStyle(Color.secondary).padding(.horizontal)
            if memberEquipment.isEmpty {
                HStack {
                    Image(systemName: "tray").foregroundStyle(Color.secondary)
                    Text("No equipment assigned").font(.subheadline).foregroundStyle(Color.secondary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 20)
                .background(Color.bhqCard).clipShape(RoundedRectangle(cornerRadius: 12)).padding(.horizontal)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(memberEquipment.enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: 12) {
                            Image(systemName: "wrench.and.screwdriver").font(.system(size: 14)).foregroundStyle(Color.secondary)
                                .frame(width: 28, height: 28).background(Color(.systemFill)).clipShape(RoundedRectangle(cornerRadius: 6))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.name).font(.body)
                                Text(item.type).font(.subheadline).foregroundStyle(Color.secondary)
                            }
                            Spacer()
                            if item.hasIssue {
                                Text(item.condition.rawValue.uppercased())
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(item.condition == .missing ? Color.bhqYellow : Color.bhqTint)
                                    .padding(.horizontal, 6).padding(.vertical, 3)
                                    .background((item.condition == .missing ? Color.bhqYellow : Color.bhqTint).opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            } else {
                                Text("OK").font(.system(size: 10, weight: .semibold)).foregroundStyle(Color.bhqGreen)
                                    .padding(.horizontal, 6).padding(.vertical, 3)
                                    .background(Color.bhqGreen.opacity(0.15)).clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 11)
                        if index < memberEquipment.count - 1 { Divider().padding(.leading, 52) }
                    }
                }
                .background(Color.bhqCard).clipShape(RoundedRectangle(cornerRadius: 12)).padding(.horizontal)
            }
        }
    }
}

#Preview {
    NavigationStack {
        MemberDetailView(member: AppUser.samples[0])
    }
    .preferredColorScheme(.dark)
}
