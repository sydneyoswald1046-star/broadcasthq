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
    
    private var adminCount: Int { approvedAccounts.filter { $0.role == .admin }.count }
    private var leadCount: Int { approvedAccounts.filter { $0.role == .teamLead }.count }
    private var memberCount: Int { approvedAccounts.filter { $0.role == .member }.count }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                statsRow
                searchBar
                filterPills
                
                if authState.pendingMembers.count > 0 {
                    pendingBanner
                }
                
                userList
            }
            .padding(.vertical)
        }
        .background(Color.bhqBackground)
        .navigationTitle("Manage Team")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddMember = true
                } label: {
                    Image(systemName: "person.badge.plus")
                        .foregroundStyle(Color.bhqBlue)
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
                    withAnimation { authState.accounts.removeAll { $0.id == account.id } }
                }
                accountToRemove = nil
            }
            Button("Cancel", role: .cancel) { accountToRemove = nil }
        } message: {
            if let account = accountToRemove {
                Text("Remove \(account.displayName) from the team? This cannot be undone.")
            }
        }
    }
    
    // MARK: - Stats Row
    private var statsRow: some View {
        HStack(spacing: 10) {
            StatCard(value: "\(approvedAccounts.count)", label: "Total", color: .bhqBlue)
            StatCard(value: "\(adminCount)", label: "Admins", color: RoleTheme.admin.primary)
            StatCard(value: "\(leadCount)", label: "Leads", color: RoleTheme.director.primary)
            StatCard(value: "\(memberCount)", label: "Members", color: .bhqGreen)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.secondary)
            TextField("Search by name, role, or email...", text: $searchText)
                .font(.body)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemFill).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
    }
    
    // MARK: - Filter Pills
    private var filterPills: some View {
        VStack(spacing: 8) {
            // Role filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    rolePill("All", id: "all")
                    rolePill("Admin", id: "admin")
                    rolePill("Lead", id: "team_lead")
                    rolePill("Member", id: "member")
                }
                .padding(.horizontal, 16)
            }
            
            // Team filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    teamPill("All Teams", id: "all")
                    ForEach(Team.all) { team in
                        teamPill(team.name, id: team.id)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    private func rolePill(_ label: String, id: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { filterRole = id }
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(filterRole == id ? Color.black : Color.secondary)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(filterRole == id ? Color.white : Color(.systemFill))
                .clipShape(Capsule())
        }
    }
    
    private func teamPill(_ label: String, id: String) -> some View {
        let team = Team.find(id)
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { filterTeam = id }
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(filterTeam == id ? (id == "all" ? Color.black : Color.white) : Color.secondary)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(filterTeam == id ? (team?.color ?? Color.white) : Color(.systemFill))
                .clipShape(Capsule())
        }
    }
    
    // MARK: - Pending Banner
    private var pendingBanner: some View {
        NavigationLink(destination: AdminApprovalView().environmentObject(authState)) {
            HStack(spacing: 10) {
                Image(systemName: "person.badge.clock")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.bhqYellow)
                
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
                    .foregroundStyle(Color.secondary.opacity(0.5))
            }
            .padding(14)
            .background(Color.bhqYellow.opacity(0.08))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.bhqYellow.opacity(0.2), lineWidth: 0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }
    
    // MARK: - User List
    private var userList: some View {
        VStack(spacing: 0) {
            if filtered.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.slash")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.secondary.opacity(0.4))
                    Text("No members found")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color.bhqCard)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(filtered.enumerated()), id: \.element.id) { index, account in
                        userCard(account: account)
                        
                        if index < filtered.count - 1 {
                            Divider().padding(.leading, 64)
                        }
                    }
                }
                .background(Color.bhqCard)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - User Card
    private func userCard(account: StoredAccount) -> some View {
        let team = Team.find(account.team)
        let roleTheme = RoleTheme.forUser(account.toAppUser())
        let isCurrentUser = account.id == authState.currentUser?.id
        
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                // Avatar
                Text(String(account.firstName.prefix(1)) + String(account.lastName.prefix(1)))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(roleTheme.primary)
                    .frame(width: 42, height: 42)
                    .background(roleTheme.primary.opacity(0.15))
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(
                            LinearGradient(colors: roleTheme.gradient, startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: account.role != .member ? 2 : 0
                        )
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(account.displayName)
                            .font(.system(size: 16, weight: .semibold))
                        
                        if isCurrentUser {
                            Text("YOU")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.bhqBlue)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Color.bhqBlue.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                    }
                    
                    Text(account.position)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.secondary)
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
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(roleTheme.primary.opacity(0.12))
                .clipShape(Capsule())
            }
            
            // Info row
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "envelope").font(.system(size: 10)).foregroundStyle(Color.secondary)
                    Text(account.email).font(.system(size: 11)).foregroundStyle(Color.secondary).lineLimit(1)
                }
                
                if let team = team {
                    HStack(spacing: 4) {
                        Image(systemName: team.icon).font(.system(size: 10)).foregroundStyle(team.color)
                        Text(team.name).font(.system(size: 11)).foregroundStyle(Color.secondary)
                    }
                }
            }
            .padding(.leading, 54)
            
            // Action buttons
            if !isCurrentUser {
                HStack(spacing: 8) {
                    Button {
                        selectedAccount = account
                        showEditSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil").font(.system(size: 11))
                            Text("Edit").font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(Color.bhqBlue)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Color.bhqBlue.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    Button {
                        accountToRemove = account
                        showRemoveConfirm = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash").font(.system(size: 11))
                            Text("Remove").font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(Color.bhqTint)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Color.bhqTint.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.leading, 54)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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
