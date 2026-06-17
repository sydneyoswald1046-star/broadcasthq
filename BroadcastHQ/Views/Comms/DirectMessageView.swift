import SwiftUI

struct DirectMessageView: View {
    let member: AppUser
    @EnvironmentObject var authState: AuthState
    @EnvironmentObject var volumePTT: VolumeButtonPTT
    @State private var inputText: String = ""
    @State private var isPTTActive: Bool = false
    @FocusState private var isInputFocused: Bool
    
    private var team: Team? { Team.find(member.team) }
    private var currentUserId: String { authState.currentUser?.id ?? "" }
    
    private var messages: [ChatMessage] {
        authState.messages.filter {
            ($0.senderId == currentUserId && $0.recipientId == member.id) ||
            ($0.senderId == member.id && $0.recipientId == currentUserId)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            memberHeader
            messageList
            
            // PTT active banner
            if isPTTActive || volumePTT.isTransmitting || authState.isLocalTransmitting {
                HStack(spacing: 8) {
                    Circle().fill(Color.white).frame(width: 6, height: 6)
                    Image(systemName: "mic.fill").font(.system(size: 12)).foregroundStyle(Color.white)
                    Text("Transmitting to \(member.displayName.split(separator: " ").first ?? "")...")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.white)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 8)
                .background(Color.bhqTint)
            } else if authState.isChannelBusy {
                HStack(spacing: 8) {
                    Image(systemName: "mic.fill").font(.system(size: 12)).foregroundStyle(Color.bhqYellow)
                    Text("\(authState.channelBusyUserName) is talking").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.white)
                    Spacer()
                    Text("BUSY").font(.system(size: 10, weight: .bold)).foregroundStyle(Color.bhqYellow).tracking(0.5)
                }
                .padding(.horizontal, 16).frame(maxWidth: .infinity).padding(.vertical, 8)
                .background(Color(white: 0.12))
            }
            
            inputBar
        }
        .background(Color.bhqBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Auto-focus keyboard for fast typing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { isInputFocused = true }
        }
    }
    
    // MARK: - Member Header
    private var memberHeader: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                Text(member.initials).font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(team?.color ?? Color.secondary)
                    .frame(width: 40, height: 40)
                    .background((team?.color ?? Color.gray).opacity(0.15)).clipShape(Circle())
                StatusIndicator(status: member.status, size: 10)
                    .overlay(Circle().stroke(Color.bhqCard, lineWidth: 2))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(member.displayName).font(.system(size: 16, weight: .semibold))
                HStack(spacing: 4) {
                    Circle().fill(statusColor).frame(width: 6, height: 6)
                    Text(member.status == .online ? "Online" : member.status == .busy ? "Busy" : "Offline").font(.system(size: 12)).foregroundStyle(Color.secondary)
                    Text("·").foregroundStyle(Color.secondary)
                    Text(member.position).font(.system(size: 12)).foregroundStyle(Color.secondary)
                }
            }
            Spacer()
            if let team = team {
                Text(team.name).font(.system(size: 11, weight: .medium)).foregroundStyle(team.color)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(team.color.opacity(0.15)).clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Color.bhqCard)
        .overlay(alignment: .bottom) { Divider() }
    }
    
    private var statusColor: Color {
        switch member.status {
        case .online: return Color.bhqGreen; case .busy: return Color.bhqYellow; case .offline: return Color(.systemGray3)
        }
    }
    
    // MARK: - Message List
    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if messages.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(messages) { msg in
                            let isMe = msg.senderId == currentUserId
                            HStack(alignment: .bottom, spacing: 6) {
                                if isMe { Spacer(minLength: 60) }
                                if !isMe {
                                    Text(msg.senderInitials).font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(team?.color ?? Color.secondary)
                                        .frame(width: 26, height: 26)
                                        .background((team?.color ?? Color.gray).opacity(0.15)).clipShape(Circle())
                                }
                                VStack(alignment: isMe ? .trailing : .leading, spacing: 2) {
                                    Text(msg.text).font(.system(size: 15))
                                        .foregroundStyle(isMe ? Color.white : Color.primary)
                                        .padding(.horizontal, 12).padding(.vertical, 8)
                                        .background(isMe ? Color.bhqBlue : Color.bhqCardElevated)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                    Text(msg.timeString).font(.system(size: 10)).foregroundStyle(Color.secondary.opacity(0.4))
                                }
                                if !isMe { Spacer(minLength: 60) }
                            }.id(msg.id)
                        }
                    }.padding(.horizontal, 12).padding(.vertical, 8)
                }
            }
            .onChange(of: authState.messages.count) { _, _ in
                if let last = messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
            }
            .onAppear {
                if let last = messages.last {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onTapGesture { isInputFocused = false }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Text(member.initials).font(.system(size: 24, weight: .bold))
                .foregroundStyle(team?.color ?? Color.secondary)
                .frame(width: 56, height: 56)
                .background((team?.color ?? Color.gray).opacity(0.15)).clipShape(Circle())
            Text("Message \(member.displayName.split(separator: " ").first ?? "")")
                .font(.system(size: 15, weight: .medium)).foregroundStyle(Color.secondary)
            Text("Messages sync across all devices").font(.system(size: 12))
                .foregroundStyle(Color.secondary.opacity(0.4))
            Spacer()
        }
    }
    
    // MARK: - Input Bar
    private var inputBar: some View {
        HStack(spacing: 8) {
            // PTT button
            Circle()
                .fill(authState.isChannelBusy ? Color.secondary.opacity(0.3) : isPTTActive ? Color.bhqTint : Color.bhqGreen)
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: authState.isChannelBusy ? "mic.slash" : isPTTActive ? "mic.fill" : "mic")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.white)
                }
                .shadow(color: isPTTActive ? Color.bhqTint.opacity(0.4) : Color.clear, radius: 6)
                .scaleEffect(isPTTActive ? 1.05 : 1.0)
                .animation(.easeOut(duration: 0.08), value: isPTTActive)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !isPTTActive && !authState.isChannelBusy {
                                isPTTActive = true
                                authState.startPTT(channel: "dm:\(member.id)")
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            }
                        }
                        .onEnded { _ in
                            if isPTTActive {
                                isPTTActive = false
                                authState.stopPTT()
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                        }
                )
            
            // Text input
            TextField("Message...", text: $inputText)
                .font(.system(size: 15))
                .focused($isInputFocused)
                .submitLabel(.send)
                .onSubmit { sendMessage() }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color(.systemFill))
                .clipShape(Capsule())
            
            // Send button
            Button { sendMessage() } label: {
                Circle()
                    .fill(inputText.isEmpty ? Color(.systemFill) : Color.bhqBlue)
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(inputText.isEmpty ? Color.secondary.opacity(0.4) : Color.white)
                    }
            }
            .disabled(inputText.isEmpty)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Color.bhqCard)
    }
    
    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        inputText = ""
        authState.sendMessage(text: text, teamId: nil, recipientId: member.id)
    }
}

#Preview {
    NavigationStack {
        DirectMessageView(member: AppUser.samples[1])
            .environmentObject(AuthState()).environmentObject(VolumeButtonPTT())
    }.preferredColorScheme(.dark)
}
