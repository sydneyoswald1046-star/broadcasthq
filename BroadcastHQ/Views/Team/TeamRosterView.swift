import SwiftUI

struct TeamRosterView: View {
    let members: [AppUser]
    let equipment: [Equipment]
    @State private var filterStatus: String = "all"
    
    private var filtered: [AppUser] {
        switch filterStatus {
        case "online": return members.filter { $0.status == .online }
        case "busy": return members.filter { $0.status == .busy }
        case "offline": return members.filter { $0.status == .offline }
        default: return members
        }
    }
    
    private var onlineCount: Int { members.filter { $0.status == .online }.count }
    private var busyCount: Int { members.filter { $0.status == .busy }.count }
    private var offlineCount: Int { members.filter { $0.status == .offline }.count }
    
    private func equipmentFor(member: AppUser) -> [Equipment] {
        equipment.filter { $0.assignedTo == member.displayName }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                statusSummary
                filterPills
                memberList
            }
            .padding(.vertical)
        }
        .background(Color.bhqBackground)
        .navigationTitle("Team Roster")
        .navigationBarTitleDisplayMode(.large)
    }
    
    // MARK: - Status Summary
    private var statusSummary: some View {
        HStack(spacing: 10) {
            StatCard(value: "\(onlineCount)", label: "Online", color: .bhqGreen)
            StatCard(value: "\(busyCount)", label: "Busy", color: .bhqYellow)
            StatCard(value: "\(offlineCount)", label: "Offline", color: Color(.systemGray3))
        }
        .padding(.horizontal)
    }
    
    // MARK: - Filter Pills
    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                filterChip("All (\(members.count))", id: "all")
                filterChip("Online (\(onlineCount))", id: "online")
                filterChip("Busy (\(busyCount))", id: "busy")
                filterChip("Offline (\(offlineCount))", id: "offline")
            }
            .padding(.horizontal, 16)
        }
    }
    
    private func filterChip(_ label: String, id: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                filterStatus = id
            }
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(filterStatus == id ? Color.black : Color.secondary)
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .background(filterStatus == id ? Color.white : Color(.systemFill))
                .clipShape(Capsule())
        }
    }
    
    // MARK: - Member List
    private var memberList: some View {
        VStack(spacing: 0) {
            ForEach(Array(filtered.enumerated()), id: \.element.id) { index, member in
                NavigationLink(destination: MemberDetailView(member: member)) {
                    memberCard(member: member)
                }
                .buttonStyle(.plain)
                
                if index < filtered.count - 1 {
                    Divider().padding(.leading, 64)
                }
            }
        }
        .background(Color.bhqCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
    
    // MARK: - Member Card
    private func memberCard(member: AppUser) -> some View {
        let gear = equipmentFor(member: member)
        let team = Team.find(member.team)
        
        return VStack(alignment: .leading, spacing: 10) {
            // Top row: avatar, name, status
            HStack(spacing: 12) {
                // Avatar
                ZStack(alignment: .bottomTrailing) {
                    Text(member.initials)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(team?.color ?? Color.secondary)
                        .frame(width: 42, height: 42)
                        .background((team?.color ?? Color.gray).opacity(0.15))
                        .clipShape(Circle())
                    
                    StatusIndicator(status: member.status, size: 10)
                        .overlay(
                            Circle()
                                .stroke(Color.bhqCard, lineWidth: 2)
                        )
                }
                
                // Name & role
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(member.displayName)
                            .font(.system(size: 16, weight: .semibold))
                        
                        if member.role == .admin {
                            roleBadge("Admin", color: Color.bhqPurple)
                        } else if member.role == .teamLead {
                            roleBadge("Lead", color: Color.bhqBlue)
                        }
                    }
                    
                    Text(member.position)
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                }
                
                Spacer()
                
                // Team badge + chevron
                HStack(spacing: 8) {
                    if let team = team {
                        Text(team.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(team.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(team.color.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.secondary.opacity(0.4))
                }
            }
            
            // Info rows
            VStack(spacing: 6) {
                // Login time
                infoRow(icon: "clock", label: "Logged in", value: member.loginTimeString)
                
                // Equipment
                if gear.isEmpty {
                    infoRow(icon: "wrench.and.screwdriver", label: "Equipment", value: "None assigned")
                } else {
                    ForEach(gear) { item in
                        equipmentRow(item: item)
                    }
                }
            }
            .padding(.leading, 54)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Role Badge
    private func roleBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
    
    // MARK: - Info Row
    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(Color.secondary)
                .frame(width: 16)
            
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Color.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.primary)
        }
    }
    
    // MARK: - Equipment Row
    private func equipmentRow(item: Equipment) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 12))
                .foregroundStyle(Color.secondary)
                .frame(width: 16)
            
            Text(item.name)
                .font(.system(size: 13))
                .foregroundStyle(Color.primary)
            
            Text(item.type)
                .font(.system(size: 11))
                .foregroundStyle(Color.secondary)
            
            Spacer()
            
            if item.hasIssue {
                Text(item.condition.rawValue.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(item.condition == .missing ? Color.bhqYellow : Color.bhqTint)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background((item.condition == .missing ? Color.bhqYellow : Color.bhqTint).opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            } else {
                Text("OK")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.bhqGreen)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.bhqGreen.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
        }
    }
}

#Preview {
    NavigationStack {
        TeamRosterView(members: AppUser.samples, equipment: Equipment.samples)
    }
    .preferredColorScheme(.dark)
}

