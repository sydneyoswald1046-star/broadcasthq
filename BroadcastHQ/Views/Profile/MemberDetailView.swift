import SwiftUI

struct MemberDetailView: View {
    let member: AppUser
    @EnvironmentObject var authState: AuthState
    @State private var showDirectMessage: Bool = false

    private var team: Team? { Team.find(member.team) }
    private var theme: RoleTheme { RoleTheme.forUser(member) }
    private var memberEquipment: [Equipment] {
        authState.equipment.filter { $0.assignedTo == member.displayName }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroHeader
                    .padding(.bottom, 16)

                VStack(spacing: 16) {
                    quickActionsRow
                    infoSection
                    equipmentSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .background(Color.bhqBackground)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showDirectMessage) {
            DirectMessageView(member: member)
        }
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        ZStack(alignment: .bottom) {
            // Gradient backdrop
            LinearGradient(
                colors: [theme.primary.opacity(0.18), Color.bhqBackground],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(maxWidth: .infinity)
            .frame(height: 260)

            VStack(spacing: 14) {
                // Avatar with animated gradient ring and glow
                ZStack {
                    // Glow behind avatar
                    Circle()
                        .fill(theme.glow.opacity(0.25))
                        .frame(width: 150, height: 150)
                        .blur(radius: 18)

                    // Gradient ring
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: theme.gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 128, height: 128)

                    ProfileAvatar(
                        userId: member.id,
                        initials: member.initials,
                        size: 120,
                        color: theme.primary
                    )
                }

                // Name
                Text(member.displayName)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.white)

                // Role + Team badges
                HStack(spacing: 8) {
                    roleBadge
                    if let t = team { teamBadge(t) }
                }

                // Position subtitle
                if !member.position.isEmpty {
                    Text(member.position)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.55))
                }

                // Status integrated into header
                HStack(spacing: 6) {
                    StatusIndicator(status: member.status, size: 8)
                    Text(member.status.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(statusColor)
                }
                .padding(.top, 2)
            }
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
    }

    private var roleBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: theme.icon)
                .font(.system(size: 10, weight: .bold))
            Text(theme.badge)
                .font(.system(size: 11, weight: .bold))
                .tracking(0.6)
        }
        .foregroundStyle(theme.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(
            LinearGradient(
                colors: [theme.primary.opacity(0.18), theme.primary.opacity(0.08)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .overlay(Capsule().stroke(theme.primary.opacity(0.3), lineWidth: 0.5))
        .clipShape(Capsule())
    }

    private func teamBadge(_ t: Team) -> some View {
        HStack(spacing: 4) {
            Image(systemName: t.icon).font(.system(size: 10))
            Text(t.name).font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(t.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(t.color.opacity(0.15))
        .overlay(Capsule().stroke(t.color.opacity(0.25), lineWidth: 0.5))
        .clipShape(Capsule())
    }

    // MARK: - Quick Actions Row

    private var quickActionsRow: some View {
        HStack(spacing: 12) {
            actionCard(
                icon: "message.fill",
                label: "Message",
                accentColor: theme.primary
            ) {
                showDirectMessage = true
            }

            actionCard(
                icon: "phone.fill",
                label: "Call",
                accentColor: theme.primary
            ) {
                // placeholder
            }

            actionCard(
                icon: "key.fill",
                label: "PIN",
                accentColor: theme.primary
            ) {
                // placeholder
            }
        }
    }

    private func actionCard(
        icon: String,
        label: String,
        accentColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(accentColor)
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.bhqCard)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("INFORMATION")

            VStack(spacing: 0) {
                infoRow(icon: "envelope.fill", label: "Email", value: member.email)
                infoDivider
                infoRow(
                    icon: "person.badge.shield.checkmark",
                    label: "Role",
                    value: member.role.rawValue.replacingOccurrences(of: "_", with: " ").capitalized
                )
                infoDivider
                infoRow(
                    icon: "person.3.fill",
                    label: "Team",
                    value: member.team.capitalized
                )
                infoDivider
                infoRow(icon: "briefcase.fill", label: "Position", value: member.position)
                infoDivider
                infoRow(icon: "clock", label: "Last Seen", value: member.loginTimeString)
            }
            .background(Color.bhqCard)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(theme.primary.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.primary)
            }

            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(Color.white.opacity(0.5))

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var infoDivider: some View {
        Divider()
            .background(Color.white.opacity(0.08))
            .padding(.leading, 60)
    }

    // MARK: - Equipment Section

    private var equipmentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("ASSIGNED EQUIPMENT")

            if memberEquipment.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "tray")
                        .foregroundStyle(Color.white.opacity(0.3))
                    Text("No equipment assigned")
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.35))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 22)
                .background(Color.bhqCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(memberEquipment.enumerated()), id: \.element.id) { index, item in
                        equipmentRow(item)
                        if index < memberEquipment.count - 1 {
                            infoDivider
                        }
                    }
                }
                .background(Color.bhqCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private func equipmentRow(_ item: Equipment) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.bhqCardElevated)
                    .frame(width: 32, height: 32)
                Image(systemName: "wrench.and.screwdriver")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.5))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white)
                Text(item.type)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.45))
            }

            Spacer()

            conditionBadge(item)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func conditionBadge(_ item: Equipment) -> some View {
        let (label, color): (String, Color) = item.hasIssue
            ? (item.condition.rawValue.uppercased(), item.condition == .missing ? Color.bhqYellow : Color.bhqTint)
            : ("OK", Color.bhqGreen)

        return Text(label)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color(red: 0.85, green: 0.70, blue: 0.30)) // gold accent dot
                .frame(width: 5, height: 5)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.4))
                .tracking(1.2)
        }
    }

    private var statusColor: Color {
        switch member.status {
        case .online: return Color.bhqGreen
        case .busy: return Color.bhqYellow
        case .offline: return Color(.systemGray3)
        }
    }
}

#Preview {
    NavigationStack {
        MemberDetailView(member: AppUser.samples[0])
    }
    .preferredColorScheme(.dark)
}
