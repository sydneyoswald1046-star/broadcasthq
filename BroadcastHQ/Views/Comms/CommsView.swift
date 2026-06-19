import SwiftUI

enum CommsTab: String, CaseIterable {
    case channels = "Channels"
    case conference = "Conference"
}

struct CommsView: View {
    @EnvironmentObject var authState: AuthState
    @EnvironmentObject var volumePTT: VolumeButtonPTT
    @State private var commsTab: CommsTab = .channels
    @State private var activeTeam: String = "all"
    @State private var inputText: String = ""
    @State private var selectedMember: AppUser? = nil
    @State private var showMemberDetail: Bool = false
    @State private var isPTTActive: Bool = false
    @FocusState private var isInputFocused: Bool
    
    private var currentUserId: String { authState.currentUser?.id ?? "" }
    
    private var filtered: [ChatMessage] {
        let msgs = authState.messages.filter { $0.recipientId == nil }
        if activeTeam == "all" { return msgs }
        return msgs.filter { $0.teamId == activeTeam }
    }
    
    private func findMember(senderId: String) -> AppUser? {
        authState.accounts.first { $0.id == senderId }?.toAppUser()
    }
    
    private func teamFor(senderId: String) -> Team? {
        if let account = authState.accounts.first(where: { $0.id == senderId }) {
            return Team.find(account.team)
        }
        return nil
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Segmented control
            Picker("", selection: $commsTab) {
                ForEach(CommsTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            switch commsTab {
            case .channels:
                VStack(spacing: 0) {
                    channelSelector
                    statusBanner
                    messageList
                    inputBar
                }
            case .conference:
                ConferenceListView()
            }
        }
        .background(Color.bhqBackground)
        .navigationDestination(isPresented: $showMemberDetail) {
            if let member = selectedMember { MemberDetailView(member: member) }
        }
    }
    
    // MARK: - Channel Selector
    private var channelSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                channelPill("All", id: "all", color: Color.white)
                ForEach(Team.all) { team in
                    channelPill(team.name, id: team.id, color: team.color)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color.bhqBackground)
    }
    
    private func channelPill(_ name: String, id: String, color: Color) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) { activeTeam = id }
        } label: {
            HStack(spacing: 5) {
                if activeTeam == id {
                    Circle().fill(id == "all" ? Color.black : Color.white).frame(width: 5, height: 5)
                }
                Text(name)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(activeTeam == id ? (id == "all" ? Color.black : Color.white) : Color.secondary)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(activeTeam == id ? (id == "all" ? Color.white : color) : Color(.systemFill))
            .clipShape(Capsule())
        }
    }
    
    // MARK: - Status Banner
    @ViewBuilder
    private var statusBanner: some View {
        if isPTTActive || volumePTT.isTransmitting || authState.isLocalTransmitting {
            HStack(spacing: 8) {
                Circle().fill(Color.white).frame(width: 6, height: 6)
                    .opacity(isPTTActive ? 1 : 0.5)
                    .animation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true), value: isPTTActive)
                Image(systemName: "mic.fill").font(.system(size: 12)).foregroundStyle(Color.white)
                Text("TRANSMITTING").font(.system(size: 11, weight: .bold)).foregroundStyle(Color.white).tracking(1)
                Spacer()
                if volumePTT.isTransmitting, let device = volumePTT.connectedDeviceName {
                    Text(device.uppercased()).font(.system(size: 9, weight: .bold)).foregroundStyle(Color.white.opacity(0.6)).tracking(0.5)
                } else {
                    Text(activeTeam == "all" ? "ALL CHANNELS" : Team.find(activeTeam)?.name.uppercased() ?? "")
                        .font(.system(size: 9, weight: .bold)).foregroundStyle(Color.white.opacity(0.6)).tracking(0.5)
                }
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity).padding(.vertical, 8)
            .background(Color.bhqTint)
        } else if authState.isChannelBusy {
            HStack(spacing: 8) {
                Image(systemName: "waveform")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.bhqYellow)
                    .symbolEffect(.variableColor.iterative, options: .repeating)
                Text("\(authState.channelBusyUserName) is talking")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.white)
                Spacer()
                Image(systemName: "circle.fill")
                    .font(.system(size: 6))
                    .foregroundStyle(Color.bhqYellow)
                Text("LIVE").font(.system(size: 9, weight: .bold)).foregroundStyle(Color.bhqYellow).tracking(1)
            }
            .padding(.horizontal, 16).frame(maxWidth: .infinity).padding(.vertical, 8)
            .background(Color(white: 0.08))
        }
    }
    
    // MARK: - Message List
    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if filtered.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 28)).foregroundStyle(Color.secondary.opacity(0.2))
                        Text("No messages yet")
                            .font(.system(size: 15, weight: .medium)).foregroundStyle(Color.secondary.opacity(0.5))
                        Text("Start a conversation with your team")
                            .font(.system(size: 12)).foregroundStyle(Color.secondary.opacity(0.3))
                    }
                    .frame(maxWidth: .infinity).padding(.top, 80)
                }
                
                LazyVStack(spacing: 2) {
                    ForEach(filtered) { msg in
                        let isMe = msg.senderId == currentUserId
                        let senderTeam = teamFor(senderId: msg.senderId)
                        
                        if isMe {
                            myMessageBubble(msg: msg)
                        } else {
                            otherMessageBubble(msg: msg, team: senderTeam)
                        }
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
            }
            .onChange(of: authState.messages.count) { _, _ in
                if let last = filtered.last {
                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            .onAppear {
                if let last = filtered.last {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onTapGesture { isInputFocused = false }
        }
    }
    
    // MARK: - My Message Bubble
    private func myMessageBubble(msg: ChatMessage) -> some View {
        HStack(alignment: .bottom, spacing: 0) {
            Spacer(minLength: 70)
            VStack(alignment: .trailing, spacing: 3) {
                Text(msg.text)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(
                        LinearGradient(
                            colors: [Color.bhqBlue, Color.bhqBlue.opacity(0.85)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .clipShape(
                        .rect(
                            topLeadingRadius: 18,
                            bottomLeadingRadius: 18,
                            bottomTrailingRadius: 6,
                            topTrailingRadius: 18
                        )
                    )
                
                Text(msg.timeString)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.secondary.opacity(0.35))
            }
        }
        .padding(.vertical, 2)
        .id(msg.id)
    }
    
    // MARK: - Other Message Bubble
    private func otherMessageBubble(msg: ChatMessage, team: Team?) -> some View {
        HStack(alignment: .top, spacing: 8) {
            // Avatar
            Button {
                if let member = findMember(senderId: msg.senderId) {
                    selectedMember = member; showMemberDetail = true
                }
            } label: {
                ProfileAvatar(
                    userId: msg.senderId,
                    initials: msg.senderInitials,
                    size: 32,
                    color: team?.color ?? Color.secondary
                )
            }
            
            VStack(alignment: .leading, spacing: 3) {
                // Sender name + team badge
                HStack(spacing: 6) {
                    Text(msg.senderName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(team?.color ?? Color.primary)
                    
                    if let team = team {
                        Text(team.name)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(team.color.opacity(0.8))
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(team.color.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    
                    Text(msg.timeString)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.secondary.opacity(0.35))
                }
                
                // Message
                Text(msg.text)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.primary)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(Color(.systemFill).opacity(0.6))
                    .clipShape(
                        .rect(
                            topLeadingRadius: 6,
                            bottomLeadingRadius: 18,
                            bottomTrailingRadius: 18,
                            topTrailingRadius: 18
                        )
                    )
            }
            
            Spacer(minLength: 50)
        }
        .padding(.vertical, 4)
        .id(msg.id)
    }
    
    // MARK: - Input Bar
    private var inputBar: some View {
        VStack(spacing: 0) {
            // Bluetooth device indicator
            if let device = volumePTT.connectedDeviceName {
                HStack(spacing: 6) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.bhqBlue)
                    Text(device)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.bhqBlue)
                    Text("· Hold to talk")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.secondary.opacity(0.4))
                }
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity)
                .background(Color.bhqBlue.opacity(0.06))
            }
            
            HStack(spacing: 10) {
            // PTT button
            Circle()
                .fill(authState.isChannelBusy ? Color.secondary.opacity(0.2) : (isPTTActive || volumePTT.isTransmitting) ? Color.bhqTint : Color.bhqGreen)
                .frame(width: 64, height: 64)
                .overlay {
                    VStack(spacing: 2) {
                        Image(systemName: authState.isChannelBusy ? "mic.slash.fill" : (isPTTActive || volumePTT.isTransmitting) ? "waveform" : "mic.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(Color.white)
                            .symbolEffect(.variableColor.iterative, options: .repeating, isActive: isPTTActive || volumePTT.isTransmitting)
                        Text(isPTTActive || volumePTT.isTransmitting ? "Live" : "PTT")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.8))
                    }
                }
                .shadow(color: (isPTTActive || volumePTT.isTransmitting) ? Color.bhqTint.opacity(0.5) : Color.clear, radius: 10)
                .scaleEffect((isPTTActive || volumePTT.isTransmitting) ? 1.1 : 1.0)
                .animation(.easeOut(duration: 0.1), value: isPTTActive || volumePTT.isTransmitting)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !isPTTActive && !authState.isChannelBusy {
                                isPTTActive = true
                                authState.startPTT(channel: activeTeam)
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            }
                        }
                        .onEnded { _ in
                            if isPTTActive {
                                isPTTActive = false; authState.stopPTT()
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
                .padding(.horizontal, 16).padding(.vertical, 11)
                .background(Color(.systemFill).opacity(0.6))
                .clipShape(Capsule())
            
            // Send button
            Button { sendMessage() } label: {
                Circle()
                    .fill(inputText.isEmpty ? Color(.systemFill).opacity(0.6) : Color.bhqBlue)
                    .frame(width: 38, height: 38)
                    .overlay {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(inputText.isEmpty ? Color.secondary.opacity(0.3) : Color.white)
                    }
            }
            .disabled(inputText.isEmpty)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
        }
        .background(Color.bhqCard.opacity(0.95))
    }
    
    // MARK: - Send
    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        inputText = ""
        let teamId = activeTeam == "all" ? nil : activeTeam
        authState.sendMessage(text: text, teamId: teamId, recipientId: nil)
    }
}

#Preview {
    NavigationStack {
        CommsView()
            .navigationTitle("Comms")
            .environmentObject(AuthState())
            .environmentObject(VolumeButtonPTT())
    }
    .preferredColorScheme(.dark)
}
