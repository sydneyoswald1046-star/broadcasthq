import SwiftUI

struct ConferenceRoomView: View {
    @EnvironmentObject var authState: AuthState
    @State private var showEndConfirmation = false

    private var room: ConferenceRoom? { authState.activeConferenceRoom }
    private var isCreator: Bool {
        room?.createdBy == authState.currentUser?.id
    }

    var body: some View {
        if let room = room {
            VStack(spacing: 0) {
                header(room: room)
                participantGrid(room: room)
                Spacer()
                controls
            }
            .background(Color.bhqBackground)
            .alert("End Room?", isPresented: $showEndConfirmation) {
                Button("End for Everyone", role: .destructive) { authState.endConference() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will disconnect all \(room.participantCount) participants.")
            }
        }
    }

    private func header(room: ConferenceRoom) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.bhqGreen)
                    .frame(width: 8, height: 8)
                    .pulsing()
                Text("LIVE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.bhqGreen)
                    .tracking(1)
                Text("·")
                    .foregroundStyle(Color.secondary.opacity(0.4))
                Text("OPEN CHANNEL")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.bhqBlue)
                    .tracking(0.5)
            }
            Text(room.name)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.primary)
            Text("\(room.participantCount) participant\(room.participantCount == 1 ? "" : "s")")
                .font(.system(size: 13))
                .foregroundStyle(Color.secondary)
            HStack(spacing: 6) {
                Image(systemName: "waveform.badge.minus")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.bhqGreen)
                Text("Noise Cancellation Active")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.bhqGreen)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.bhqGreen.opacity(0.1))
            .clipShape(Capsule())
        }
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private func participantGrid(room: ConferenceRoom) -> some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 90, maximum: 120), spacing: 16)
            ], spacing: 20) {
                ForEach(room.participants) { participant in
                    participantTile(participant: participant)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    private func participantTile(participant: ConferenceParticipant) -> some View {
        let isMe = participant.userId == authState.currentUser?.id
        let isMutedParticipant = isMe && authState.isMuted
        return VStack(spacing: 8) {
            ZStack {
                SpeakingIndicator(isSpeaking: !isMutedParticipant, size: 56)
                ProfileAvatar(
                    userId: participant.userId,
                    initials: participant.displayName.split(separator: " ").prefix(2).compactMap { $0.first.map(String.init) }.joined(),
                    size: 56,
                    color: .bhqBlue
                )
                if isMutedParticipant {
                    Circle()
                        .fill(Color.black.opacity(0.5))
                        .frame(width: 56, height: 56)
                        .overlay {
                            Image(systemName: "mic.slash.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(Color.white)
                        }
                }
            }
            Text(isMe ? "You" : participant.displayName.split(separator: " ").first.map(String.init) ?? participant.displayName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.primary)
                .lineLimit(1)
        }
    }

    private var controls: some View {
        HStack(spacing: 40) {
            // Mute
            Button { authState.toggleMute() } label: {
                VStack(spacing: 6) {
                    Circle()
                        .fill(authState.isMuted ? Color.bhqTint : Color(.systemFill))
                        .frame(width: 56, height: 56)
                        .overlay {
                            Image(systemName: authState.isMuted ? "mic.slash.fill" : "mic.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(authState.isMuted ? Color.white : Color.primary)
                        }
                    Text(authState.isMuted ? "Unmute" : "Mute")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.secondary)
                }
            }

            // Leave
            Button { authState.leaveConference() } label: {
                VStack(spacing: 6) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 56, height: 56)
                        .overlay {
                            Image(systemName: "phone.down.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(Color.white)
                        }
                    Text("Leave")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.secondary)
                }
            }

            // End Room (creator only)
            if isCreator {
                Button { showEndConfirmation = true } label: {
                    VStack(spacing: 6) {
                        Circle()
                            .fill(Color.red.opacity(0.15))
                            .frame(width: 56, height: 56)
                            .overlay {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(Color.red)
                            }
                        Text("End")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 24)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        .background(Color.bhqCard.opacity(0.95))
    }
}
