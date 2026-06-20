import SwiftUI

struct TeamRosterView: View {
    let members: [AppUser]
    let equipment: [Equipment]
    @State private var filterStatus: String = "all"

    private var filtered: [AppUser] {
        switch filterStatus {
        case "online":  return members.filter { $0.status == .online }
        case "busy":    return members.filter { $0.status == .busy }
        case "offline": return members.filter { $0.status == .offline }
        default:        return members
        }
    }

    private var onlineCount:  Int { members.filter { $0.status == .online  }.count }
    private var busyCount:    Int { members.filter { $0.status == .busy    }.count }
    private var offlineCount: Int { members.filter { $0.status == .offline }.count }

    private func equipmentFor(member: AppUser) -> [Equipment] {
        equipment.filter { $0.assignedTo == member.displayName }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                statsRow
                filterPills
                memberCards
            }
            .padding(.vertical, 16)
        }
        .background(Color.bhqBackground)
        .navigationTitle("Team Roster")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 10) {
            premiumStatCard(
                value: "\(onlineCount)",
                label: "Online",
                color: .bhqGreen,
                icon: "circle.fill"
            )
            premiumStatCard(
                value: "\(busyCount)",
                label: "Busy",
                color: .bhqYellow,
                icon: "circle.fill"
            )
            premiumStatCard(
                value: "\(offlineCount)",
                label: "Offline",
                color: Color(.systemGray3),
                icon: "circle.fill"
            )
            premiumStatCard(
                value: "\(members.count)",
                label: "Total",
                color: .bhqBlue,
                icon: "person.2.fill"
            )
        }
        .padding(.horizontal, 16)
    }

    private func premiumStatCard(value: String, label: String, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(color.opacity(0.85))
            }
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(Color.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            ZStack {
                Color.bhqCard
                color.opacity(0.06)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.18), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Filter Pills

    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip("All", count: members.count, id: "all",   activeColor: .bhqTint)
                filterChip("Online",  count: onlineCount,  id: "online",  activeColor: .bhqGreen)
                filterChip("Busy",    count: busyCount,    id: "busy",    activeColor: .bhqYellow)
                filterChip("Offline", count: offlineCount, id: "offline", activeColor: Color(.systemGray3))
            }
            .padding(.horizontal, 16)
        }
    }

    private func filterChip(_ label: String, count: Int, id: String, activeColor: Color) -> some View {
        let isActive = filterStatus == id
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                filterStatus = id
            }
        } label: {
            HStack(spacing: 5) {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                Text("\(count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .opacity(0.75)
            }
            .foregroundStyle(isActive ? (id == "offline" ? Color(.label) : .white) : Color.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                isActive
                    ? activeColor.opacity(id == "offline" ? 0.35 : 0.85)
                    : Color(.systemFill)
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isActive ? activeColor.opacity(0.5) : Color.clear, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Member Cards

    @ViewBuilder
    private var memberCards: some View {
        if filtered.isEmpty {
            emptyState
        } else {
            LazyVStack(spacing: 10) {
                ForEach(filtered) { member in
                    NavigationLink(destination: MemberDetailView(member: member)) {
                        MemberCard(member: member, equipment: equipmentFor(member: member))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.bhqCard)
                    .frame(width: 80, height: 80)
                Image(systemName: "person.slash")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(Color.secondary.opacity(0.5))
            }
            VStack(spacing: 6) {
                Text("No members found")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.primary)
                Text("Try a different filter to see team members.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Member Card View

private struct MemberCard: View {
    let member: AppUser
    let equipment: [Equipment]

    private var team: Team? { Team.find(member.team) }
    private var theme: RoleTheme { RoleTheme.forUser(member) }

    var body: some View {
        let teamColor = team?.color ?? theme.primary

        return VStack(alignment: .leading, spacing: 0) {
            // Top section: avatar + name block + chevron
            HStack(spacing: 14) {
                avatarView(teamColor: teamColor)

                // Name + role badge + position
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(member.displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.primary)

                        roleBadge
                    }
                    Text(member.position)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.secondary)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.secondary.opacity(0.35))
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 14)

            // Divider
            Rectangle()
                .fill(teamColor.opacity(0.1))
                .frame(height: 0.5)
                .padding(.horizontal, 16)

            // Bottom row: team badge + equipment count + last seen
            HStack(spacing: 8) {
                if let team = team {
                    teamBadge(team: team)
                }

                equipmentBadge(count: equipment.count)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.secondary.opacity(0.6))
                    Text(member.loginTimeString)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondary.opacity(0.75))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
        }
        .background(Color.bhqCard)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(teamColor.opacity(0.12), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func avatarView(teamColor: Color) -> some View {
        ZStack(alignment: .bottomTrailing) {
            Text(member.initials)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(teamColor)
                .frame(width: 48, height: 48)
                .background(teamColor.opacity(0.14))
                .clipShape(Circle())

            StatusIndicator(status: member.status, size: 11)
                .overlay(
                    Circle()
                        .stroke(Color.bhqCard, lineWidth: 2.5)
                )
                .offset(x: 2, y: 2)
        }
    }

    @ViewBuilder
    private var roleBadge: some View {
        let (label, color): (String, Color) = {
            switch member.role {
            case .admin:    return ("Admin", theme.primary)
            case .teamLead: return ("Lead",  .bhqBlue)
            default:        return ("", .clear)
            }
        }()

        if !label.isEmpty {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }

    private func teamBadge(team: Team) -> some View {
        HStack(spacing: 4) {
            Text(team.icon)
                .font(.system(size: 10))
            Text(team.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(team.color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(team.color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func equipmentBadge(count: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 10))
            Text(count == 0 ? "No gear" : "\(count) item\(count == 1 ? "" : "s")")
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(count == 0 ? Color.secondary.opacity(0.5) : Color.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemFill))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TeamRosterView(members: AppUser.samples, equipment: Equipment.samples)
    }
    .preferredColorScheme(.dark)
}
