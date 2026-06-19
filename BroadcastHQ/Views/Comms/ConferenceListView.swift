import SwiftUI

struct ConferenceListView: View {
    @EnvironmentObject var authState: AuthState
    @State private var showCreateSheet = false

    private var currentUser: AppUser? { authState.currentUser }
    private var canCreate: Bool {
        guard let role = currentUser?.role else { return false }
        return role == .admin || role == .teamLead
    }

    var body: some View {
        VStack(spacing: 0) {
            if authState.conferenceRooms.isEmpty {
                emptyState
            } else {
                roomList
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateConferenceSheet()
        }
        .overlay(alignment: .bottomTrailing) {
            if canCreate {
                createButton
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "person.wave.2")
                .font(.system(size: 32))
                .foregroundStyle(Color.secondary.opacity(0.2))
            Text("No active rooms")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.secondary.opacity(0.5))
            Text(canCreate ? "Create a room to start a conference call" : "Waiting for a room to be created")
                .font(.system(size: 12))
                .foregroundStyle(Color.secondary.opacity(0.3))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var roomList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(authState.conferenceRooms) { room in
                    RoomCard(room: room)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private var createButton: some View {
        Button { showCreateSheet = true } label: {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.white)
                .frame(width: 56, height: 56)
                .background(Color.bhqBlue)
                .clipShape(Circle())
                .shadow(color: Color.bhqBlue.opacity(0.4), radius: 8)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 20)
    }
}

struct RoomCard: View {
    let room: ConferenceRoom
    @EnvironmentObject var authState: AuthState

    private var isInThisRoom: Bool {
        authState.activeConferenceRoom?.id == room.id
    }

    var body: some View {
        Button {
            if !isInThisRoom {
                authState.joinConference(roomId: room.id)
            }
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(isInThisRoom ? Color.bhqGreen : Color.bhqBlue)
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: isInThisRoom ? "waveform" : "phone.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.white)
                            .symbolEffect(.variableColor.iterative, options: .repeating, isActive: isInThisRoom)
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text(room.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.primary)

                    HStack(spacing: 6) {
                        HStack(spacing: 3) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 10))
                            Text("\(room.participantCount)")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(Color.secondary)

                        Text(room.accessMode == .invite ? "Invite" : "Open")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(room.accessMode == .invite ? Color.bhqYellow : Color.bhqGreen)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background((room.accessMode == .invite ? Color.bhqYellow : Color.bhqGreen).opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                Spacer()

                if isInThisRoom {
                    Text("JOINED")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.bhqGreen)
                        .tracking(0.5)
                } else {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.bhqBlue.opacity(0.6))
                }
            }
            .padding(14)
            .background(isInThisRoom ? Color.bhqGreen.opacity(0.08) : Color.bhqCard)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isInThisRoom ? Color.bhqGreen.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
