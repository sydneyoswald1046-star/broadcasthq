import SwiftUI

struct AdminApprovalView: View {
    @EnvironmentObject var authState: AuthState
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if authState.pendingMembers.isEmpty {
                    emptyState
                } else {
                    pendingHeader
                    pendingList
                }
            }
            .padding(.vertical)
        }
        .background(Color.bhqBackground)
        .navigationTitle("Pending Approvals")
        .navigationBarTitleDisplayMode(.large)
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 60)
            
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.bhqGreen)
            
            Text("All Clear")
                .font(.system(size: 22, weight: .bold))
            
            Text("No pending signups to review.")
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Pending Header
    private var pendingHeader: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.bhqYellow)
                .frame(width: 8, height: 8)
            Text("\(authState.pendingMembers.count) pending approval\(authState.pendingMembers.count == 1 ? "" : "s")")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.bhqYellow)
            Spacer()
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Pending List
    private var pendingList: some View {
        VStack(spacing: 0) {
            ForEach(Array(authState.pendingMembers.enumerated()), id: \.element.id) { index, account in
                pendingCard(account: account)
                
                if index < authState.pendingMembers.count - 1 {
                    Divider().padding(.leading, 64)
                }
            }
        }
        .background(Color.bhqCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
    
    // MARK: - Pending Card
    private func pendingCard(account: StoredAccount) -> some View {
        let team = Team.find(account.team)
        
        return VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 12) {
                // Avatar
                Text(String(account.firstName.prefix(1)) + String(account.lastName.prefix(1)))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(team?.color ?? Color.secondary)
                    .frame(width: 44, height: 44)
                    .background((team?.color ?? Color.gray).opacity(0.15))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.displayName)
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text(account.position)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.secondary)
                }
                
                Spacer()
                
                Text("PENDING")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.bhqYellow)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.bhqYellow.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            
            // Details
            VStack(spacing: 4) {
                detailRow(icon: "envelope", value: account.email)
                detailRow(icon: "phone", value: account.phone)
                if let team = team {
                    detailRow(icon: "person.3", value: team.name)
                }
            }
            .padding(.leading, 56)
            
            // Action buttons
            HStack(spacing: 10) {
                Button {
                    withAnimation {
                        authState.approveAccount(account.id)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                        Text("Approve")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.bhqGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                
                Button {
                    withAnimation {
                        authState.rejectAccount(account.id)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                        Text("Reject")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.bhqTint)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(.leading, 56)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
    
    private func detailRow(icon: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(Color.secondary)
                .frame(width: 14)
            Text(value)
                .font(.system(size: 13))
                .foregroundStyle(Color.secondary)
        }
    }
}

#Preview {
    let auth = AuthState()
    auth.accounts.append(StoredAccount(id: "99", firstName: "New", lastName: "Member", email: "new@test.com", phone: "555-9999", pin: "9999", role: .member, position: "Camera 3", team: "camera", isApproved: false, joinedDate: Date(), presence: "offline", lastSeen: nil))
    return NavigationStack {
        AdminApprovalView()
            .environmentObject(auth)
    }
    .preferredColorScheme(.dark)
}
