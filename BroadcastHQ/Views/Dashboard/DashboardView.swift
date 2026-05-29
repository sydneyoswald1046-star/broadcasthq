import Combine
import SwiftUI

struct DashboardView: View {
    @Binding var selectTab: ContentView.Tab
    @Binding var segments: [Segment]
    @Binding var isBroadcastLive: Bool
    let currentUser: AppUser
    @EnvironmentObject var authState: AuthState
    
    @State private var timerTick: Int = 0
    @State private var showTeamRoster: Bool = false
    
    private var members: [AppUser] {
        authState.accounts.filter { $0.isApproved }.map { $0.toAppUser() }
    }
    @State private var showAlertConfirm: Bool = false
    @State private var alertSent: Bool = false
    @State private var showGoLiveConfirm: Bool = false
    @State private var showEndLiveConfirm: Bool = false
    @State private var showAdminPanel: Bool = false
    @State private var showEventScheduler: Bool = false
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // Broadcast elapsed time — calculated from Firestore start time
    private var broadcastElapsed: Int {
        let _ = timerTick
        guard let startTime = authState.broadcastStartTime, isBroadcastLive else { return 0 }
        return Int(Date().timeIntervalSince(startTime))
    }
    
    // Segment elapsed time — from authState so it persists across tab switches
    private var elapsed: Int {
        let _ = timerTick
        guard isBroadcastLive else { return 0 }
        return Int(Date().timeIntervalSince(authState.segmentStartTime))
    }
    
    private var liveSegment: Segment? { segments.first { $0.status == .live } }
    private var liveIndex: Int { segments.firstIndex { $0.status == .live } ?? 0 }
    private var remaining: Int { max(0, (liveSegment?.duration ?? 0) - elapsed) }
    private var progress: Double { min(1, Double(elapsed) / Double(liveSegment?.duration ?? 1)) }
    private var onlineCount: Int { members.filter { $0.status == .online }.count }
    private var gearIssues: Int { authState.equipment.filter { $0.hasIssue }.count }
    private var timeLeft: String {
        let upcomingTotal = segments.filter { $0.status == .upcoming }.reduce(0) { $0 + $1.duration }
        return Segment.formatTime(remaining + upcomingTotal)
    }
    private var canGoPrev: Bool { liveIndex > 0 }
    private var canGoNext: Bool { liveIndex < segments.count - 1 }
    private var canControlBroadcast: Bool { currentUser.role == .admin || currentUser.role == .teamLead }
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 16) {
                    if !isBroadcastLive, let event = authState.nextEvent { nextEventBanner(event: event) }
                    if canControlBroadcast { broadcastControlButton }
                    if isBroadcastLive { liveNowCard; liveControls } else { standbyCard }
                    progressBar; statsRow; recentMessagesSection; quickActionsSection; teamStatusSection
                    Spacer().frame(height: 80)
                }.padding(.vertical)
            }.background(Color.bhqBackground)
            if alertSent { alertToast }
        }
        .onReceive(timer) { _ in if isBroadcastLive { timerTick += 1 } }
        .onChange(of: liveSegment?.id) { _, _ in authState.segmentStartTime = Date() }
        .navigationDestination(isPresented: $showTeamRoster) { TeamRosterView(members: members, equipment: authState.equipment) }
        .navigationDestination(isPresented: $showAdminPanel) { AdminPanelView() }
        .navigationDestination(isPresented: $showEventScheduler) { EventSchedulerView() }
        .sheet(isPresented: $showAlertConfirm) {
            SendAlertSheet(isPresented: $showAlertConfirm).environmentObject(authState)
        }
        .alert("Go Live", isPresented: $showGoLiveConfirm) {
            Button("Start Broadcast", role: .destructive) { startBroadcast() }; Button("Cancel", role: .cancel) { }
        } message: { Text("This will start the broadcast and notify all \(members.count) team members.") }
        .alert("End Broadcast", isPresented: $showEndLiveConfirm) {
            Button("End Broadcast", role: .destructive) { endBroadcast() }; Button("Cancel", role: .cancel) { }
        } message: { Text("This will end the live broadcast and mark all remaining segments as completed.") }
    }
    
    private func nextEventBanner(event: BroadcastEvent) -> some View {
        Button { showEventScheduler = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "calendar.badge.clock").font(.system(size: 20)).foregroundStyle(Color.bhqYellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Next: \(event.title)").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.primary)
                    Text(event.timeString).font(.system(size: 12)).foregroundStyle(Color.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.secondary.opacity(0.5))
            }.padding(14).background(Color.bhqYellow.opacity(0.06))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.bhqYellow.opacity(0.15), lineWidth: 0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain).padding(.horizontal)
    }
    
    private var broadcastControlButton: some View {
        Button {
            if isBroadcastLive { showEndLiveConfirm = true } else { showGoLiveConfirm = true }
        } label: {
            HStack(spacing: 10) {
                Circle().fill(isBroadcastLive ? Color.white : Color.bhqTint).frame(width: 10, height: 10)
                    .overlay { if isBroadcastLive { Circle().fill(Color.white).frame(width: 10, height: 10).pulsing() } }
                Text(isBroadcastLive ? "END BROADCAST" : "GO LIVE").font(.system(size: 16, weight: .bold)).tracking(1)
                Spacer()
                Image(systemName: isBroadcastLive ? "stop.fill" : "play.fill").font(.system(size: 14, weight: .bold))
            }.foregroundStyle(Color.white).padding(.horizontal, 20).padding(.vertical, 16)
            .background(isBroadcastLive
                ? LinearGradient(colors: [Color.bhqTint, Color.bhqTint.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                : LinearGradient(colors: [Color.bhqGreen, Color.bhqGreen.opacity(0.8)], startPoint: .leading, endPoint: .trailing))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }.padding(.horizontal)
    }
    
    private var standbyCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right").font(.system(size: 32)).foregroundStyle(Color.bhqGreen.opacity(0.5))
            Text("Broadcast Standby").font(.system(size: 20, weight: .bold))
            Text("Ready to go live · \(segments.count) segments loaded").font(.subheadline).foregroundStyle(Color.secondary)
            Text("Total runtime: \(Segment.formatTime(segments.reduce(0) { $0 + $1.duration }))").font(.system(size: 13)).foregroundStyle(Color.secondary.opacity(0.7))
        }.frame(maxWidth: .infinity).padding(24).background(Color.bhqCard)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.bhqGreen.opacity(0.15), lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 16)).padding(.horizontal)
    }
    
    private var liveControls: some View {
        HStack(spacing: 10) {
            controlButton(icon: "backward.fill", label: "Prev", color: canGoPrev ? Color.bhqBlue : Color.secondary.opacity(0.3)) { if canGoPrev { goToSegment(liveIndex - 1) } }.disabled(!canGoPrev)
            controlButton(icon: "forward.fill", label: "Next", color: canGoNext ? Color.bhqGreen : Color.secondary.opacity(0.3)) { if canGoNext { advanceSegment() } }.disabled(!canGoNext)
            controlButton(icon: "megaphone.fill", label: "Alert", color: Color.bhqTint) { showAlertConfirm = true }
            controlButton(icon: "antenna.radiowaves.left.and.right", label: "Comms", color: Color.bhqPurple) { selectTab = .comms }
        }.padding(.horizontal)
    }
    
    private func controlButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 16, weight: .semibold)).foregroundStyle(color)
                    .frame(width: 48, height: 48).background(color.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 14))
                Text(label).font(.system(size: 10, weight: .medium)).foregroundStyle(Color.secondary)
            }.frame(maxWidth: .infinity)
        }.buttonStyle(.plain)
    }
    
    private var alertToast: some View {
        VStack { HStack(spacing: 10) { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.bhqGreen).font(.system(size: 18))
            Text("Alert sent to \(members.count) members").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.white) }
            .padding(.horizontal, 20).padding(.vertical, 14).background(Color.bhqCardElevated).clipShape(Capsule())
            .shadow(color: Color.black.opacity(0.3), radius: 10).padding(.top, 8); Spacer() }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    private var liveNowCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { HStack(spacing: 6) { Circle().fill(Color.bhqTint).frame(width: 7, height: 7).pulsing()
                Text("ON AIR").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.bhqTint).tracking(0.5) }
                Spacer(); Text("Segment \(liveIndex + 1) of \(segments.count)").font(.system(size: 12)).foregroundStyle(Color.secondary) }
            Text(liveSegment?.title ?? "No active segment").font(.system(size: 22, weight: .bold))
            Text("\(liveSegment?.assignedRole ?? "") · \(liveSegment?.notes ?? "")").font(.subheadline).foregroundStyle(Color.secondary)
            timerDisplay; progressBarInCard
        }.padding(16)
        .background(LinearGradient(colors: [Color.bhqTint.opacity(0.1), Color.bhqCard], startPoint: .topLeading, endPoint: .bottomTrailing))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.bhqTint.opacity(0.2), lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 16)).padding(.horizontal)
    }
    
    private var timerDisplay: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text("REMAINING").font(.system(size: 11, weight: .medium)).foregroundStyle(Color.secondary.opacity(0.5)).tracking(0.5)
                Text(Segment.formatTime(remaining)).font(.system(size: 40, weight: .bold, design: .rounded)).monospacedDigit()
                    .foregroundStyle(remaining < 60 ? Color.bhqTint : Color.primary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(progress * 100))%").font(.subheadline).foregroundStyle(Color.secondary)
                let _ = timerTick // Force refresh
                Text(Segment.formatTime(broadcastElapsed))
                    .font(.system(size: 12, weight: .medium, design: .rounded)).monospacedDigit()
                    .foregroundStyle(Color.secondary.opacity(0.5))
            }
        }
    }
    
    private var progressBarInCard: some View {
        GeometryReader { geo in ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2).fill(Color(.systemFill))
            RoundedRectangle(cornerRadius: 2).fill(remaining < 60 ? Color.bhqTint : Color.bhqGreen)
                .frame(width: geo.size.width * progress).animation(.linear(duration: 1), value: progress)
        }}.frame(height: 4)
    }
    
    private var progressBar: some View {
        HStack(spacing: 3) { ForEach(segments) { seg in RoundedRectangle(cornerRadius: 2.5).fill(segmentPillColor(seg)).frame(height: 5) } }.padding(.horizontal)
    }
    
    private func segmentPillColor(_ seg: Segment) -> Color {
        switch seg.status { case .completed: return Color.bhqGreen; case .live: return Color.bhqTint; case .upcoming: return Color(.systemFill) }
    }
    
    private var statsRow: some View {
        HStack(spacing: 10) {
            Button { showTeamRoster = true } label: { StatCard(value: "\(onlineCount)/\(members.count)", label: "Online", color: .bhqGreen) }.buttonStyle(.plain)
            StatCard(value: gearIssues > 0 ? "\(gearIssues)" : "✓", label: gearIssues > 0 ? "Gear Issues" : "Gear OK", color: gearIssues > 0 ? .bhqYellow : .bhqGreen)
            StatCard(value: timeLeft, label: "Time Left", color: .bhqBlue)
        }.padding(.horizontal)
    }
    
    // MARK: - Recent Messages (grouped by sender)
    
    private struct MessageGroup: Identifiable {
        let id: String // senderId
        let senderName: String
        let senderInitials: String
        let senderId: String
        let latestText: String
        let latestTime: Date
        let count: Int
        let isDM: Bool
        let teamId: String?
        
        var timeString: String {
            let f = RelativeDateTimeFormatter()
            f.unitsStyle = .abbreviated
            return f.localizedString(for: latestTime, relativeTo: Date())
        }
    }
    
    private var messageGroups: [MessageGroup] {
        let myId = currentUser.id
        let relevant = authState.messages
            .filter { msg in
                (msg.recipientId == myId || msg.recipientId == nil) && msg.senderId != myId
            }
        
        // Group by sender
        var grouped: [String: [ChatMessage]] = [:]
        for msg in relevant {
            grouped[msg.senderId, default: []].append(msg)
        }
        
        // Convert to MessageGroup, sorted by most recent
        return grouped.compactMap { senderId, msgs -> MessageGroup? in
            guard let latest = msgs.last else { return nil }
            return MessageGroup(
                id: senderId,
                senderName: latest.senderName,
                senderInitials: latest.senderInitials,
                senderId: senderId,
                latestText: latest.text,
                latestTime: latest.timestamp,
                count: msgs.count,
                isDM: latest.recipientId != nil,
                teamId: latest.teamId ?? authState.accounts.first { $0.id == senderId }?.team
            )
        }
        .sorted { $0.latestTime > $1.latestTime }
        .prefix(5)
        .map { $0 }
    }
    
    private var unreadDMCount: Int {
        authState.messages.filter { $0.recipientId == currentUser.id }.count
    }
    
    private var recentMessagesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                SectionHeader(title: "Messages")
                Spacer()
                if unreadDMCount > 0 {
                    Text("\(unreadDMCount) DM\(unreadDMCount == 1 ? "" : "s")")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.bhqTint).clipShape(Capsule())
                }
                Button { selectTab = .comms } label: {
                    Text("Open").font(.system(size: 13, weight: .medium)).foregroundStyle(Color.bhqBlue)
                }.padding(.trailing, 16)
            }
            
            if messageGroups.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 18)).foregroundStyle(Color.secondary.opacity(0.3))
                    Text("No messages yet").font(.system(size: 14)).foregroundStyle(Color.secondary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 20)
                .background(Color.bhqCard).clipShape(RoundedRectangle(cornerRadius: 12)).padding(.horizontal)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(messageGroups.enumerated()), id: \.element.id) { index, group in
                        Button {
                            if group.isDM {
                                authState.deepLinkDMUserId = group.senderId
                                selectTab = .dms
                            } else {
                                selectTab = .comms
                            }
                        } label: {
                            HStack(spacing: 10) {
                                let team = Team.find(group.teamId ?? "")
                                ProfileAvatar(
                                    userId: group.senderId,
                                    initials: group.senderInitials,
                                    size: 36,
                                    color: team?.color ?? .secondary
                                )
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(group.senderName)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Color.primary)
                                        
                                        if group.count > 1 {
                                            HStack(spacing: 2) {
                                                Image(systemName: "bubble.left.fill")
                                                    .font(.system(size: 8))
                                                Text("\(group.count)")
                                                    .font(.system(size: 10, weight: .bold))
                                            }
                                            .foregroundStyle(Color.bhqBlue)
                                            .padding(.horizontal, 5).padding(.vertical, 2)
                                            .background(Color.bhqBlue.opacity(0.12))
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                        }
                                        
                                        if group.isDM {
                                            Text("DM")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundStyle(Color.purple)
                                                .padding(.horizontal, 4).padding(.vertical, 1)
                                                .background(Color.purple.opacity(0.12))
                                                .clipShape(RoundedRectangle(cornerRadius: 3))
                                        }
                                        
                                        Spacer()
                                        
                                        Text(group.timeString)
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color.secondary.opacity(0.4))
                                    }
                                    
                                    Text(group.latestText)
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        
                        if index < messageGroups.count - 1 {
                            Divider().padding(.leading, 60)
                        }
                    }
                }
                .background(Color.bhqCard).clipShape(RoundedRectangle(cornerRadius: 12)).padding(.horizontal)
            }
        }
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "Quick Actions")
            VStack(spacing: 0) {
                quickAction("Team Communication", icon: "antenna.radiowaves.left.and.right") { selectTab = .comms }
                Divider().padding(.leading, 54)
                quickAction("Broadcast Rundown", icon: "play.rectangle.on.rectangle.fill") { selectTab = .rundown }
                Divider().padding(.leading, 54)
                quickAction("Equipment Tracker", icon: "camera.on.rectangle.fill") { selectTab = .equipment }
                Divider().padding(.leading, 54)
                quickAction("Alert Entire Team", icon: "megaphone.fill") { showAlertConfirm = true }
                if canControlBroadcast { Divider().padding(.leading, 54); quickAction("Schedule Event", icon: "calendar.badge.clock") { showEventScheduler = true } }
                if currentUser.role == .admin { Divider().padding(.leading, 54); quickAction("Manage Team", icon: "person.3.sequence.fill") { showAdminPanel = true } }
            }.background(Color.bhqCard).clipShape(RoundedRectangle(cornerRadius: 12)).padding(.horizontal)
        }
    }
    
    private func quickAction(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 16, weight: .medium)).foregroundStyle(Color.secondary).frame(width: 30)
                Text(title).font(.body).foregroundStyle(Color.primary); Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.secondary.opacity(0.5))
            }.padding(.horizontal, 16).padding(.vertical, 11).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
    
    private var teamStatusSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "Team Status")
            VStack(spacing: 0) {
                // Group by team
                ForEach(Team.all) { team in
                    let teamMembers = members.filter { $0.team == team.id }
                    if !teamMembers.isEmpty {
                        // Team header
                        HStack(spacing: 8) {
                            Image(systemName: team.icon).font(.system(size: 12)).foregroundStyle(team.color)
                            Text(team.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(team.color)
                            Spacer()
                            Text("\(teamMembers.count)").font(.system(size: 12, weight: .bold)).foregroundStyle(team.color)
                                .frame(minWidth: 22, minHeight: 22).background(team.color.opacity(0.12)).clipShape(Circle())
                        }
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(team.color.opacity(0.04))
                        
                        // Team members
                        ForEach(teamMembers) { member in
                            NavigationLink(destination: MemberDetailView(member: member)) { memberRow(member: member) }.buttonStyle(.plain)
                        }
                        Divider()
                    }
                }
                
                // Members without a recognized team
                let unteamed = members.filter { member in !Team.all.contains { $0.id == member.team } }
                if !unteamed.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "person.fill").font(.system(size: 12)).foregroundStyle(Color.secondary)
                        Text("Other").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.secondary)
                        Spacer()
                        Text("\(unteamed.count)").font(.system(size: 12, weight: .bold)).foregroundStyle(Color.secondary)
                            .frame(minWidth: 22, minHeight: 22).background(Color.secondary.opacity(0.12)).clipShape(Circle())
                    }
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Color.secondary.opacity(0.04))
                    
                    ForEach(unteamed) { member in
                        NavigationLink(destination: MemberDetailView(member: member)) { memberRow(member: member) }.buttonStyle(.plain)
                    }
                }
                
                Button { showTeamRoster = true } label: {
                    HStack { Spacer(); Text("See Full Roster").font(.system(size: 13, weight: .medium)).foregroundStyle(Color.bhqBlue)
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.bhqBlue); Spacer()
                    }.padding(.vertical, 12).background(Color.bhqCard)
                }.buttonStyle(.plain)
            }.background(Color.bhqCard).clipShape(RoundedRectangle(cornerRadius: 12)).padding(.horizontal)
        }
    }
    
    private func memberRow(member: AppUser) -> some View {
        HStack(spacing: 12) {
            let team = Team.find(member.team)
            Text(member.initials).font(.system(size: 13, weight: .semibold)).foregroundStyle(team?.color ?? Color.secondary)
                .frame(width: 36, height: 36).background((team?.color ?? Color.gray).opacity(0.15)).clipShape(Circle())
            VStack(alignment: .leading, spacing: 1) { Text(member.displayName).font(.body).foregroundStyle(Color.primary); Text(member.position).font(.subheadline).foregroundStyle(Color.secondary) }
            Spacer(); StatusIndicator(status: member.status)
            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.secondary.opacity(0.3))
        }.padding(.horizontal, 16).padding(.vertical, 10)
    }
    
    // MARK: - Broadcast Actions (now sync to Firestore)
    private func startBroadcast() {
        withAnimation(.easeInOut(duration: 0.3)) {
            for i in segments.indices { segments[i].status = .upcoming }
            if !segments.isEmpty { segments[0].status = .live }
            authState.segmentStartTime = Date()
            authState.setBroadcastLive(true)
            authState.syncSegments()
        }
    }
    
    private func endBroadcast() {
        withAnimation(.easeInOut(duration: 0.3)) {
            for i in segments.indices { segments[i].status = .completed }
            authState.segmentStartTime = Date()
            authState.setBroadcastLive(false)
            authState.syncSegments()
        }
    }
    
    private func advanceSegment() {
        guard let liveIdx = segments.firstIndex(where: { $0.status == .live }) else { return }
        withAnimation {
            segments[liveIdx].status = .completed
            if liveIdx + 1 < segments.count { segments[liveIdx + 1].status = .live }
            else { authState.setBroadcastLive(false) }
            authState.syncSegments()
        }
    }
    
    private func goToSegment(_ index: Int) {
        guard index >= 0 && index < segments.count else { return }
        withAnimation {
            if let currentLive = segments.firstIndex(where: { $0.status == .live }) { segments[currentLive].status = .upcoming }
            segments[index].status = .live
            authState.syncSegments()
        }
    }
}

#Preview {
    NavigationStack {
        DashboardView(selectTab: .constant(.dashboard), segments: .constant(Segment.samples), isBroadcastLive: .constant(false), currentUser: AppUser.samples[0])
            .navigationTitle("Dashboard").environmentObject(AuthState())
    }.preferredColorScheme(.dark)
}
