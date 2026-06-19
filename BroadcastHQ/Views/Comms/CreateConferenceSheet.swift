import SwiftUI

struct CreateConferenceSheet: View {
    @EnvironmentObject var authState: AuthState
    @Environment(\.dismiss) var dismiss
    @State private var roomName = ""
    @State private var accessMode: ConferenceAccessMode = .open
    @State private var selectedUserIds: Set<String> = []
    @State private var isCreating = false

    private var approvedMembers: [StoredAccount] {
        authState.accounts.filter { $0.isApproved && $0.id != authState.currentUser?.id }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Room Name") {
                    TextField("e.g. Camera Ops Sync", text: $roomName)
                }

                Section("Access") {
                    Picker("Who can join", selection: $accessMode) {
                        Text("Open — anyone").tag(ConferenceAccessMode.open)
                        Text("Invite only").tag(ConferenceAccessMode.invite)
                    }
                    .pickerStyle(.segmented)
                }

                if accessMode == .invite {
                    Section("Invite Members") {
                        ForEach(approvedMembers, id: \.id) { account in
                            Button {
                                if selectedUserIds.contains(account.id) {
                                    selectedUserIds.remove(account.id)
                                } else {
                                    selectedUserIds.insert(account.id)
                                }
                            } label: {
                                HStack {
                                    ProfileAvatar(
                                        userId: account.id,
                                        initials: account.displayName.split(separator: " ").prefix(2).compactMap { $0.first.map(String.init) }.joined(),
                                        size: 32
                                    )
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(account.displayName)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(Color.primary)
                                        Text(account.position)
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color.secondary)
                                    }
                                    Spacer()
                                    if selectedUserIds.contains(account.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color.bhqBlue)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Room")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") { createRoom() }
                        .disabled(roomName.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
                        .bold()
                }
            }
        }
    }

    private func createRoom() {
        isCreating = true
        let name = roomName.trimmingCharacters(in: .whitespaces)
        let invited = Array(selectedUserIds)
        Task {
            if let roomId = try? await authState.createConferenceRoom(
                name: name, accessMode: accessMode, invitedUserIds: invited
            ) {
                await MainActor.run {
                    authState.joinConference(roomId: roomId)
                    dismiss()
                }
            } else {
                await MainActor.run { isCreating = false }
            }
        }
    }
}
