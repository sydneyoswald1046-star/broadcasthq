import SwiftUI

struct AdminPanelView: View {
    @EnvironmentObject var authState: AuthState
    @State private var searchText: String = ""
    @State private var filterRole: String = "all"
    @State private var filterTeam: String = "all"
    @State private var selectedAccount: StoredAccount?
    @State private var showEditSheet: Bool = false
    @State private var showRemoveConfirm: Bool = false
    @State private var accountToRemove: StoredAccount?
    @State private var showAddMember: Bool = false
    @State private var showResetPinConfirm: Bool = false
    @State private var accountToResetPin: StoredAccount?
    @State private var resetPinResult: String?
    @State private var showResetPinResult: Bool = false

    // MARK: - Computed data

    private var approvedAccounts: [StoredAccount] {
        authState.accounts.filter { $0.isApproved }
    }

    private var filtered: [StoredAccount] {
        var result = approvedAccounts

        if !searchText.isEmpty {
            result = result.filter {
                $0.displayName.localizedCaseInsensitiveContains(searchText) ||
                $0.position.localizedCaseInsensitiveContains(searchText) ||
                $0.email.localizedCaseInsensitiveContains(searchText)
            }
        }

        if filterRole != "all" {
            result = result.filter { $0.role.rawValue == filterRole }
        }

        if filterTeam != "all" {
            result = result.filter { $0.team == filterTeam }
        }

        return result
    }

    private var adminCount: Int  { approvedAccounts.filter { $0.role == .admin }.count }
    private var leadCount: Int   { approvedAccounts.filter { $0.role == .teamLead }.count }
    private var memberCount: Int { approvedAccounts.filter { $0.role == .member }.count }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            Color.bhqBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    greetingHeader
                    statsRow
                    searchBar

                    if authState.pendingMembers.count > 0 {
                        pendingBanner
                    }

                    filterPills
                    memberCards
                }
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddMember = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(RoleTheme.admin.primary.opacity(0.18))
                            .frame(width: 34, height: 34)
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(RoleTheme.admin.primary)
                    }
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            if let account = selectedAccount {
                EditMemberSheet(
                    account: account,
                    onSave: { updated in
                        if let index = authState.accounts.firstIndex(where: { $0.id == updated.id }) {
                            authState.accounts[index] = updated
                        }
                        showEditSheet = false
                        selectedAccount = nil
                    },
                    onDismiss: {
                        showEditSheet = false
                        selectedAccount = nil
                    }
                )
            }
        }
        .sheet(isPresented: $showAddMember) {
            AddMemberSheet(
                onAdd: { account in
                    authState.accounts.append(account)
                    showAddMember = false
                },
                onDismiss: { showAddMember = false }
            )
        }
        .alert("Remove Member", isPresented: $showRemoveConfirm) {
            Button("Remove", role: .destructive) {
                if let account = accountToRemove {
                    authState.rejectAccount(account.id)
                }
                accountToRemove = nil
            }
            Button("Cancel", role: .cancel) { accountToRemove = nil }
        } message: {
            if let account = accountToRemove {
                Text("Remove \(account.displayName) from the team? This cannot be undone.")
            }
        }
        .alert("Reset PIN", isPresented: $showResetPinConfirm) {
            Button("Reset", role: .destructive) {
                if let account = accountToResetPin {
                    Task {
                        if let newPin = await authState.resetMemberPin(account.id) {
                            resetPinResult = newPin
                            showResetPinResult = true
                        }
                        accountToResetPin = nil
                    }
                }
            }
            Button("Cancel", role: .cancel) { accountToResetPin = nil }
        } message: {
            if let account = accountToResetPin {
                Text("Generate a new PIN for \(account.displayName)? Their current PIN will stop working.")
            }
        }
        .alert("New PIN", isPresented: $showResetPinResult) {
            Button("OK") { resetPinResult = nil }
        } message: {
            if let pin = resetPinResult, let account = accountToResetPin ?? selectedAccount {
                Text("\(account.displayName)'s new PIN is: \(pin)\n\nShare this with them — they'll need it to log in.")
            } else if let pin = resetPinResult {
                Text("New PIN: \(pin)")
            }
        }
    }

    // MARK: - Greeting Header

    private var greetingHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Hello,")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.secondary)

                HStack(spacing: 0) {
                    Text("Good \(timeOfDayGreeting), ")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(RoleTheme.admin.primary)
                    Text(adminFirstName)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Color.primary)
                }

                Text("Today, \(formattedDate)")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.secondary.opacity(0.8))
            }

            Spacer()

            // Settings / profile indicator
            ZStack {
                Circle()
                    .fill(RoleTheme.admin.primary.opacity(0.15))
                    .overlay(
                        Circle().stroke(
                            LinearGradient(
                                colors: RoleTheme.admin.gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                    )
                    .frame(width: 40, height: 40)

                Image(systemName: "crown.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(RoleTheme.admin.primary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private var timeOfDayGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12:  return "Morning"
        case 12..<17: return "Afternoon"
        default:      return "Evening"
        }
    }

    private var adminFirstName: String {
        authState.currentUser?.displayName.components(separatedBy: " ").first ?? "Admin"
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter.string(from: Date())
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 10) {
            adminStatCard(
                value: "\(approvedAccounts.count)",
                label: "Total",
                icon: "person.3.fill",
                color: RoleTheme.admin.primary
            )
            adminStatCard(
                value: "\(adminCount)",
                label: "Admins",
                icon: "crown.fill",
                color: RoleTheme.admin.secondary
            )
            adminStatCard(
                value: "\(leadCount)",
                label: "Leads",
                icon: "film.fill",
                color: RoleTheme.director.primary
            )
            adminStatCard(
                value: "\(memberCount)",
                label: "Members",
                icon: "person.fill",
                color: Color.bhqGreen
            )
        }
        .padding(.horizontal, 20)
    }

    private func adminStatCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color.opacity(0.85))

            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            ZStack {
                Color.bhqCard
                LinearGradient(
                    colors: [color.opacity(0.12), color.opacity(0.03)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(color.opacity(0.22), lineWidth: 0.5)
        )
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.secondary)
                .font(.system(size: 15))

            TextField("Search name, position, email…", text: $searchText)
                .font(.system(size: 15))
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color.bhqCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    searchText.isEmpty
                        ? RoleTheme.admin.primary.opacity(0.15)
                        : RoleTheme.admin.primary.opacity(0.45),
                    lineWidth: 0.5
                )
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Pending Banner

    private var pendingBanner: some View {
        NavigationLink(destination: AdminApprovalView().environmentObject(authState)) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(RoleTheme.admin.primary.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "person.badge.clock.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(RoleTheme.admin.primary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(authState.pendingMembers.count) Pending Approval\(authState.pendingMembers.count == 1 ? "" : "s")")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.primary)
                    Text("Tap to review and approve new signups")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(RoleTheme.admin.primary.opacity(0.6))
            }
            .padding(16)
            .background(
                ZStack {
                    Color.bhqCard
                    LinearGradient(
                        colors: [RoleTheme.admin.primary.opacity(0.10), RoleTheme.admin.primary.opacity(0.02)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(RoleTheme.admin.primary.opacity(0.35), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }

    // MARK: - Filter Pills

    private var filterPills: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    rolePill("All", id: "all")
                    rolePill("Admin", id: "admin")
                    rolePill("Lead", id: "team_lead")
                    rolePill("Member", id: "member")
                }
                .padding(.horizontal, 20)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    teamPill("All Teams", id: "all")
                    ForEach(Team.all) { team in
                        teamPill(team.name, id: team.id)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func rolePill(_ label: String, id: String) -> some View {
        let isActive = filterRole == id
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { filterRole = id }
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isActive ? Color.black : Color.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    isActive
                        ? LinearGradient(colors: RoleTheme.admin.gradient, startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [Color(.systemFill), Color(.systemFill)], startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isActive ? Color.clear : Color.bhqSeparator, lineWidth: 0.5)
                )
        }
    }

    private func teamPill(_ label: String, id: String) -> some View {
        let isActive = filterTeam == id
        let team = Team.find(id)
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { filterTeam = id }
        } label: {
            HStack(spacing: 4) {
                if let team = team {
                    Image(systemName: team.icon)
                        .font(.system(size: 10, weight: .semibold))
                }
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(
                isActive
                    ? (id == "all" ? Color.black : Color.white)
                    : Color.secondary
            )
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                isActive
                    ? (id == "all"
                        ? LinearGradient(colors: RoleTheme.admin.gradient, startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [team?.color ?? Color.white, team?.color.opacity(0.7) ?? Color.white], startPoint: .leading, endPoint: .trailing))
                    : LinearGradient(colors: [Color(.systemFill), Color(.systemFill)], startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isActive ? Color.clear : Color.bhqSeparator, lineWidth: 0.5)
            )
        }
    }

    // MARK: - Member Cards

    private var memberCards: some View {
        VStack(spacing: 0) {
            if filtered.isEmpty {
                emptyState
            } else {
                VStack(spacing: 10) {
                    ForEach(filtered) { account in
                        memberCard(account: account)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.slash")
                .font(.system(size: 36))
                .foregroundStyle(RoleTheme.admin.primary.opacity(0.3))
            Text("No members found")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 52)
        .background(Color.bhqCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(RoleTheme.admin.primary.opacity(0.12), lineWidth: 0.5)
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Member Card

    private func memberCard(account: StoredAccount) -> some View {
        let roleTheme = RoleTheme.forUser(account.toAppUser())
        let team = Team.find(account.team)
        let isCurrentUser = account.id == authState.currentUser?.id
        let presenceStatus = PresenceStatus(rawValue: account.presence) ?? .offline
        let initials = String(account.firstName.prefix(1)) + String(account.lastName.prefix(1))

        return VStack(alignment: .leading, spacing: 14) {
            // Top row: avatar + name/role + status
            HStack(alignment: .top, spacing: 14) {
                // Avatar with role gradient ring
                ZStack(alignment: .bottomTrailing) {
                    ProfileAvatar(
                        userId: account.id,
                        initials: initials,
                        size: 48,
                        color: roleTheme.primary
                    )
                    .overlay(
                        Circle().stroke(
                            LinearGradient(
                                colors: roleTheme.gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                    )

                    StatusIndicator(status: presenceStatus, size: 10)
                        .overlay(Circle().stroke(Color.bhqCard, lineWidth: 1.5))
                        .offset(x: 1, y: 1)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(account.displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.primary)

                        if isCurrentUser {
                            Text("YOU")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.bhqBlue)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.bhqBlue.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }

                        Spacer()

                        // Role badge
                        HStack(spacing: 3) {
                            Image(systemName: roleTheme.icon)
                                .font(.system(size: 8, weight: .bold))
                            Text(roleTheme.badge)
                                .font(.system(size: 9, weight: .bold))
                                .tracking(0.3)
                        }
                        .foregroundStyle(roleTheme.primary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(roleTheme.primary.opacity(0.14))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(roleTheme.primary.opacity(0.25), lineWidth: 0.5))
                    }

                    // Position + team
                    HStack(spacing: 8) {
                        Text(account.position)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.secondary)

                        if let team = team {
                            Circle()
                                .fill(Color.secondary.opacity(0.4))
                                .frame(width: 3, height: 3)
                            Image(systemName: team.icon)
                                .font(.system(size: 10))
                                .foregroundStyle(team.color)
                            Text(team.name)
                                .font(.system(size: 13))
                                .foregroundStyle(Color.secondary)
                        }
                    }
                }
            }

            // Email row
            HStack(spacing: 6) {
                Image(systemName: "envelope")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondary.opacity(0.6))
                Text(account.email)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
            }
            .padding(.leading, 62)

            // Action buttons — only show for other members
            if !isCurrentUser {
                Divider()
                    .background(Color.bhqSeparator)

                HStack(spacing: 8) {
                    actionButton(
                        label: "Edit",
                        icon: "pencil",
                        color: Color.bhqBlue
                    ) {
                        selectedAccount = account
                        showEditSheet = true
                    }

                    actionButton(
                        label: "Reset PIN",
                        icon: "key.horizontal",
                        color: RoleTheme.admin.primary
                    ) {
                        accountToResetPin = account
                        showResetPinConfirm = true
                    }

                    Spacer()

                    actionButton(
                        label: "Remove",
                        icon: "trash",
                        color: Color.bhqTint
                    ) {
                        accountToRemove = account
                        showRemoveConfirm = true
                    }
                }
            }
        }
        .padding(16)
        .background(Color.bhqCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(RoleTheme.admin.primary.opacity(0.15), lineWidth: 0.5)
        )
    }

    private func actionButton(label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(label)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(color.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(color.opacity(0.2), lineWidth: 0.5)
            )
        }
    }
}

// MARK: - Edit Member Sheet

struct EditMemberSheet: View {
    let account: StoredAccount
    let onSave: (StoredAccount) -> Void
    let onDismiss: () -> Void

    @State private var editRole: UserRole
    @State private var editPosition: String
    @State private var editTeam: String
    @State private var editPhone: String

    private let positions = [
        "Director", "Tech Director", "Producer", "Floor Director",
        "Camera 1", "Camera 2", "Camera 3",
        "Photographer", "Lead Photographer",
        "Audio Engineer", "Audio Assist",
        "Graphics Op", "Projection Op",
        "Choir Director", "Worship Leader",
        "Lighting Director", "Lighting Op",
        "Volunteer"
    ]

    init(account: StoredAccount, onSave: @escaping (StoredAccount) -> Void, onDismiss: @escaping () -> Void) {
        self.account = account
        self.onSave = onSave
        self.onDismiss = onDismiss
        _editRole = State(initialValue: account.role)
        _editPosition = State(initialValue: account.position)
        _editTeam = State(initialValue: account.team)
        _editPhone = State(initialValue: account.phone)
    }

    var body: some View {
        NavigationStack {
            List {
                // Member info (read-only)
                Section {
                    HStack(spacing: 12) {
                        Text(String(account.firstName.prefix(1)) + String(account.lastName.prefix(1)))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.secondary)
                            .frame(width: 44, height: 44)
                            .background(Color(.systemFill))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(account.displayName)
                                .font(.system(size: 17, weight: .semibold))
                            Text(account.email)
                                .font(.subheadline)
                                .foregroundStyle(Color.secondary)
                        }
                    }
                }

                // Editable fields
                Section {
                    Picker("Role", selection: $editRole) {
                        Text("Admin").tag(UserRole.admin)
                        Text("Team Lead").tag(UserRole.teamLead)
                        Text("Member").tag(UserRole.member)
                    }

                    Picker("Position", selection: $editPosition) {
                        ForEach(positions, id: \.self) { pos in
                            Text(pos).tag(pos)
                        }
                    }

                    Picker("Team", selection: $editTeam) {
                        ForEach(Team.all) { team in
                            Text(team.name).tag(team.id)
                        }
                    }
                } header: { Text("Role & Assignment") }

                Section {
                    HStack {
                        Image(systemName: "phone").foregroundStyle(Color.secondary)
                        TextField("Phone", text: $editPhone)
                            .keyboardType(.phonePad)
                    }
                } header: { Text("Contact") }

                // Role change warning
                if editRole != account.role {
                    Section {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.bhqYellow)
                            Text("Changing role from \(account.role.displayName) to \(editRole.displayName) will change this member's access level and dashboard.")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Edit Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onDismiss() }
                        .foregroundStyle(Color.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        var updated = account
                        updated.role = editRole
                        updated.position = editPosition
                        updated.team = editTeam
                        updated.phone = editPhone
                        onSave(updated)
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.bhqBlue)
                }
            }
        }
    }
}

// MARK: - Add Member Sheet

struct AddMemberSheet: View {
    let onAdd: (StoredAccount) -> Void
    let onDismiss: () -> Void

    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var email: String = ""
    @State private var phone: String = ""
    @State private var role: UserRole = .member
    @State private var position: String = "Volunteer"
    @State private var team: String = "broadcast"
    @State private var pin: String = ""

    private let positions = [
        "Director", "Tech Director", "Producer", "Floor Director",
        "Camera 1", "Camera 2", "Camera 3",
        "Photographer", "Lead Photographer",
        "Audio Engineer", "Audio Assist",
        "Graphics Op", "Projection Op",
        "Choir Director", "Worship Leader",
        "Lighting Director", "Lighting Op",
        "Volunteer"
    ]

    private var isValid: Bool {
        !firstName.isEmpty && !lastName.isEmpty && !email.isEmpty && pin.count == 4
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 10) {
                        formField("First Name", text: $firstName)
                        formField("Last Name", text: $lastName)
                    }
                    formField("Email", text: $email)
                    formField("Phone", text: $phone)
                } header: { Text("Details") }

                Section {
                    Picker("Role", selection: $role) {
                        Text("Admin").tag(UserRole.admin)
                        Text("Team Lead").tag(UserRole.teamLead)
                        Text("Member").tag(UserRole.member)
                    }

                    Picker("Position", selection: $position) {
                        ForEach(positions, id: \.self) { pos in Text(pos).tag(pos) }
                    }

                    Picker("Team", selection: $team) {
                        ForEach(Team.all) { t in Text(t.name).tag(t.id) }
                    }
                } header: { Text("Role & Assignment") }

                Section {
                    HStack {
                        Image(systemName: "lock").foregroundStyle(Color.secondary)
                        TextField("4-digit PIN", text: $pin)
                            .keyboardType(.numberPad)
                            .onChange(of: pin) { _, newValue in
                                if newValue.count > 4 { pin = String(newValue.prefix(4)) }
                            }
                    }
                } header: { Text("Login PIN") } footer: { Text("This member will use this PIN to log in.") }
            }
            .navigationTitle("Add Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onDismiss() }.foregroundStyle(Color.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        let account = StoredAccount(
                            id: UUID().uuidString,
                            firstName: firstName,
                            lastName: lastName,
                            email: email,
                            phone: phone,
                            pin: pin,
                            role: role,
                            position: position,
                            team: team,
                            isApproved: true,
                            joinedDate: Date(),
                            presence: "online",
                            lastSeen: Date()
                        )
                        onAdd(account)
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(isValid ? Color.bhqBlue : Color.secondary)
                    .disabled(!isValid)
                }
            }
        }
    }

    private func formField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .autocorrectionDisabled()
            .textInputAutocapitalization(placeholder.contains("Name") ? .words : .never)
    }
}

#Preview {
    NavigationStack {
        AdminPanelView()
            .environmentObject(AuthState())
    }
    .preferredColorScheme(.dark)
}
