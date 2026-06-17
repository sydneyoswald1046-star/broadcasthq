import SwiftUI

struct DMView: View {
    @EnvironmentObject var authState: AuthState
    @EnvironmentObject var volumePTT: VolumeButtonPTT
    @State private var selectedMember: AppUser? = nil
    @State private var inputText: String = ""
    @State private var isPTTActive: Bool = false
    @State private var showNewMessage: Bool = false
    @FocusState private var isInputFocused: Bool
    
    private var currentUserId: String { authState.currentUser?.id ?? "" }
    
    private var allMembers: [AppUser] {
        authState.accounts.filter { $0.isApproved && $0.id != currentUserId }.map { $0.toAppUser() }
    }
    
    private var conversationMembers: [AppUser] {
        allMembers.filter { dmHasMessages(for: $0.id) }
            .sorted { lastDMTime(for: $0.id) > lastDMTime(for: $1.id) }
    }
    
    private var newMembers: [AppUser] {
        allMembers.filter { !dmHasMessages(for: $0.id) }
    }
    
    private func dmMessages(for memberId: String) -> [ChatMessage] {
        authState.messages.filter {
            ($0.senderId == currentUserId && $0.recipientId == memberId) ||
            ($0.senderId == memberId && $0.recipientId == currentUserId)
        }
    }
    
    private func dmHasMessages(for memberId: String) -> Bool {
        authState.messages.contains {
            ($0.senderId == currentUserId && $0.recipientId == memberId) ||
            ($0.senderId == memberId && $0.recipientId == currentUserId)
        }
    }
    
    private func lastDM(for memberId: String) -> ChatMessage? {
        dmMessages(for: memberId).last
    }
    
    private func lastDMTime(for memberId: String) -> Date {
        lastDM(for: memberId)?.timestamp ?? .distantPast
    }
    
    private func unreadCount(for memberId: String) -> Int {
        authState.messages.filter { $0.senderId == memberId && $0.recipientId == currentUserId }.count
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if let member = selectedMember {
                conversationView(member: member)
            } else {
                inboxView
            }
        }
        .background(Color.bhqBackground)
        // Deep link: open DM from notification
        .onChange(of: authState.deepLinkDMUserId) { _, userId in
            if let userId = userId, let member = allMembers.first(where: { $0.id == userId }) {
                withAnimation(.easeOut(duration: 0.15)) { selectedMember = member }
                authState.deepLinkDMUserId = nil
            }
        }
        .onAppear {
            // Check if there's a pending deep link
            if let userId = authState.deepLinkDMUserId, let member = allMembers.first(where: { $0.id == userId }) {
                selectedMember = member
                authState.deepLinkDMUserId = nil
            }
        }
    }
    
    // MARK: - Inbox
    private var inboxView: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Search / New message header
                HStack {
                    Text("\(conversationMembers.count) conversation\(conversationMembers.count == 1 ? "" : "s")")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.secondary)
                    Spacer()
                    Button { showNewMessage = true } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.bhqBlue)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                
                // Active conversations
                if !conversationMembers.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(conversationMembers.enumerated()), id: \.element.id) { index, member in
                            inboxRow(member: member)
                            if index < conversationMembers.count - 1 {
                                Divider().padding(.leading, 76)
                            }
                        }
                    }
                    .background(Color.bhqCard)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)
                }
                
                // Start new conversation
                if !newMembers.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("TEAM MEMBERS")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.secondary.opacity(0.5))
                            .tracking(1)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                        
                        let columns = [
                            GridItem(.flexible(), spacing: 10),
                            GridItem(.flexible(), spacing: 10)
                        ]
                        
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(newMembers) { member in
                                Button {
                                    withAnimation(.easeOut(duration: 0.15)) { selectedMember = member }
                                } label: {
                                    let team = Team.find(member.team)
                                    
                                    VStack(spacing: 0) {
                                        Spacer()
                                        
                                        ProfileAvatar(
                                            userId: member.id,
                                            initials: member.initials,
                                            size: 52,
                                            color: team?.color ?? .secondary
                                        )
                                        
                                        Spacer().frame(height: 10)
                                        
                                        Text(member.displayName)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Color.primary)
                                            .lineLimit(1)
                                        
                                        Text(member.position)
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color.secondary)
                                            .lineLimit(1)
                                        
                                        Spacer().frame(height: 8)
                                        
                                        // Status bar at bottom
                                        HStack(spacing: 5) {
                                            Circle()
                                                .fill(member.status == .online ? Color.bhqGreen : Color.secondary.opacity(0.3))
                                                .frame(width: 7, height: 7)
                                            Text(member.status == .online ? "Online" : "Offline")
                                                .font(.system(size: 10, weight: .medium))
                                                .foregroundStyle(member.status == .online ? Color.bhqGreen : Color.secondary.opacity(0.5))
                                        }
                                        
                                        Spacer()
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 140)
                                    .background(Color.bhqCard)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(member.status == .online ? (team?.color ?? Color.bhqGreen).opacity(0.15) : Color.clear, lineWidth: 1)
                                    )
                                }.buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                
                // Empty state
                if conversationMembers.isEmpty && newMembers.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 36, weight: .light))
                            .foregroundStyle(Color.secondary.opacity(0.2))
                        Text("No conversations yet")
                            .font(.system(size: 17, weight: .semibold))
                        Text("Tap a team member above to start a direct message")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 60)
                }
                
                Spacer().frame(height: 100)
            }
        }
        .sheet(isPresented: $showNewMessage) {
            newMessageSheet
        }
    }
    
    // MARK: - Inbox Row (Premium)
    private func inboxRow(member: AppUser) -> some View {
        let team = Team.find(member.team)
        let lastMsg = lastDM(for: member.id)
        let isFromMe = lastMsg?.senderId == currentUserId
        
        return Button {
            withAnimation(.easeOut(duration: 0.15)) { selectedMember = member }
        } label: {
            HStack(spacing: 12) {
                // Avatar with online indicator
                ZStack(alignment: .bottomTrailing) {
                    ProfileAvatar(
                        userId: member.id,
                        initials: member.initials,
                        size: 50,
                        color: team?.color ?? .secondary
                    )
                    
                    Circle()
                        .fill(member.status == .online ? Color.bhqGreen : Color.secondary.opacity(0.3))
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(Color.bhqCard, lineWidth: 2.5))
                }
                
                // Name + last message
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(member.displayName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.primary)
                        
                        if let team = team {
                            Text(team.name)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(team.color.opacity(0.7))
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(team.color.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        
                        Spacer()
                        
                        if let msg = lastMsg {
                            Text(msg.timeString)
                                .font(.system(size: 11))
                                .foregroundStyle(Color.secondary.opacity(0.4))
                        }
                    }
                    
                    HStack(spacing: 4) {
                        if isFromMe {
                            Text("You:")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.secondary.opacity(0.5))
                        }
                        Text(lastMsg?.text ?? "")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Conversation View (Premium)
    private func conversationView(member: AppUser) -> some View {
        VStack(spacing: 0) {
            conversationHeader(member: member)
            conversationMessages(member: member)
            
            // PTT transmitting banner
            if isPTTActive || volumePTT.isTransmitting || authState.isLocalTransmitting {
                HStack(spacing: 8) {
                    Circle().fill(Color.white).frame(width: 6, height: 6)
                        .opacity(isPTTActive ? 1 : 0.5)
                        .animation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true), value: isPTTActive)
                    Image(systemName: "mic.fill").font(.system(size: 12)).foregroundStyle(Color.white)
                    Text("PRIVATE · \(member.displayName.split(separator: " ").first ?? "")")
                        .font(.system(size: 11, weight: .bold)).foregroundStyle(Color.white).tracking(0.5)
                    Spacer()
                    if volumePTT.isTransmitting, let device = volumePTT.connectedDeviceName {
                        Text(device.uppercased())
                            .font(.system(size: 9, weight: .bold)).foregroundStyle(Color.white.opacity(0.6)).tracking(0.5)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(Color.bhqTint)
            }
            
            conversationInput(member: member)
        }
    }
    
    private func conversationHeader(member: AppUser) -> some View {
        let team = Team.find(member.team)
        
        return HStack(spacing: 12) {
            Button {
                withAnimation(.easeOut(duration: 0.15)) { selectedMember = nil }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.bhqBlue)
            }
            
            ProfileAvatar(
                userId: member.id,
                initials: member.initials,
                size: 34,
                color: team?.color ?? .secondary
            )
            
            VStack(alignment: .leading, spacing: 1) {
                Text(member.displayName)
                    .font(.system(size: 15, weight: .semibold))
                HStack(spacing: 4) {
                    Circle()
                        .fill(member.status == .online ? Color.bhqGreen : Color.secondary.opacity(0.3))
                        .frame(width: 6, height: 6)
                    Text(member.status == .online ? "Online" : "Offline")
                        .font(.system(size: 11))
                        .foregroundStyle(member.status == .online ? Color.bhqGreen : Color.secondary)
                }
            }
            
            Spacer()
            
            if let team = team {
                Text(team.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(team.color)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(team.color.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.bhqCard.opacity(0.95))
        .overlay(alignment: .bottom) { Divider() }
    }
    
    private func conversationMessages(member: AppUser) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                let msgs = dmMessages(for: member.id)
                
                if msgs.isEmpty {
                    VStack(spacing: 12) {
                        Spacer().frame(height: 50)
                        let team = Team.find(member.team)
                        ProfileAvatar(
                            userId: member.id,
                            initials: member.initials,
                            size: 60,
                            color: team?.color ?? .secondary
                        )
                        Text(member.displayName)
                            .font(.system(size: 17, weight: .semibold))
                        Text(member.position)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.secondary)
                        Text("Start a private conversation")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.secondary.opacity(0.4))
                            .padding(.top, 4)
                    }
                } else {
                    LazyVStack(spacing: 2) {
                        ForEach(msgs) { msg in
                            let isMe = msg.senderId == currentUserId
                            if isMe {
                                myBubble(msg: msg)
                            } else {
                                theirBubble(msg: msg, member: member)
                            }
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                }
            }
            .onChange(of: authState.messages.count) { _, _ in
                if let last = dmMessages(for: member.id).last {
                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            .onAppear {
                if let last = dmMessages(for: member.id).last {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onTapGesture { isInputFocused = false }
        }
    }
    
    // MARK: - My Bubble
    private func myBubble(msg: ChatMessage) -> some View {
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
                    .foregroundStyle(Color.secondary.opacity(0.3))
            }
        }
        .padding(.vertical, 2)
        .id(msg.id)
    }
    
    // MARK: - Their Bubble
    private func theirBubble(msg: ChatMessage, member: AppUser) -> some View {
        let team = Team.find(member.team)
        
        return HStack(alignment: .top, spacing: 8) {
            ProfileAvatar(
                userId: member.id,
                initials: msg.senderInitials,
                size: 28,
                color: team?.color ?? .secondary
            )
            
            VStack(alignment: .leading, spacing: 3) {
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
                
                Text(msg.timeString)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.secondary.opacity(0.3))
            }
            
            Spacer(minLength: 50)
        }
        .padding(.vertical, 2)
        .id(msg.id)
    }
    
    // MARK: - Input Bar
    private func conversationInput(member: AppUser) -> some View {
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
                    Text("· Press to talk")
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
                .fill(authState.isChannelBusy ? Color.secondary.opacity(0.2) : isPTTActive ? Color.bhqTint : Color.bhqGreen)
                .frame(width: 64, height: 64)
                .overlay {
                    VStack(spacing: 2) {
                        Image(systemName: authState.isChannelBusy ? "mic.slash.fill" : isPTTActive ? "waveform" : "mic.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(Color.white)
                            .symbolEffect(.variableColor.iterative, options: .repeating, isActive: isPTTActive)
                        Text(isPTTActive ? "Live" : "PTT")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.8))
                    }
                }
                .shadow(color: isPTTActive ? Color.bhqTint.opacity(0.4) : Color.clear, radius: 10)
                .scaleEffect(isPTTActive ? 1.1 : 1.0)
                .animation(.easeOut(duration: 0.1), value: isPTTActive)
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
                                isPTTActive = false; authState.stopPTT()
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                        }
                )
            
            TextField("Message...", text: $inputText)
                .font(.system(size: 15))
                .focused($isInputFocused)
                .submitLabel(.send)
                .onSubmit { sendDM(to: member) }
                .padding(.horizontal, 16).padding(.vertical, 11)
                .background(Color(.systemFill).opacity(0.6))
                .clipShape(Capsule())
            
            Button { sendDM(to: member) } label: {
                Circle()
                    .fill(inputText.isEmpty ? Color(.systemFill).opacity(0.6) : Color.bhqBlue)
                    .frame(width: 38, height: 38)
                    .overlay {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(inputText.isEmpty ? Color.secondary.opacity(0.3) : Color.white)
                    }
            }.disabled(inputText.isEmpty)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
        }
        .background(Color.bhqCard.opacity(0.95))
    }
    
    // MARK: - New Message Sheet
    private var newMessageSheet: some View {
        NavigationStack {
            List {
                ForEach(allMembers) { member in
                    let team = Team.find(member.team)
                    Button {
                        showNewMessage = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation { selectedMember = member }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            ProfileAvatar(userId: member.id, initials: member.initials, size: 40, color: team?.color ?? .secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(member.displayName).font(.system(size: 15, weight: .semibold))
                                Text(member.position).font(.system(size: 12)).foregroundStyle(Color.secondary)
                            }
                            Spacer()
                            Circle()
                                .fill(member.status == .online ? Color.bhqGreen : Color.secondary.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                }
            }
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { showNewMessage = false }.foregroundStyle(Color.secondary)
                }
            }
        }
    }
    
    private func sendDM(to member: AppUser) {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        inputText = ""
        authState.sendMessage(text: text, teamId: nil, recipientId: member.id)
    }
}

#Preview {
    NavigationStack {
        DMView()
            .navigationTitle("Direct Messages")
            .environmentObject(AuthState())
            .environmentObject(VolumeButtonPTT())
    }.preferredColorScheme(.dark)
}
