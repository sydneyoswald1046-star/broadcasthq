import Combine
import SwiftUI

struct MemberDashboardView: View {
    @Binding var selectTab: ContentView.Tab
    @Binding var segments: [Segment]
    @Binding var isBroadcastLive: Bool
    let currentUser: AppUser
    @EnvironmentObject var authState: AuthState
    
    @State private var timerTick: Int = 0
    
    private var members: [AppUser] {
        authState.accounts.filter { $0.isApproved }.map { $0.toAppUser() }
    }
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private var liveSegment: Segment? { segments.first { $0.status == .live } }
    private var liveIndex: Int { segments.firstIndex { $0.status == .live } ?? 0 }
    
    // Segment elapsed — from authState so it persists across tab switches
    private var elapsed: Int {
        let _ = timerTick
        guard isBroadcastLive else { return 0 }
        return Int(Date().timeIntervalSince(authState.segmentStartTime))
    }
    
    // Broadcast elapsed — from Firestore start time
    private var broadcastElapsed: Int {
        let _ = timerTick
        guard let startTime = authState.broadcastStartTime, isBroadcastLive else { return 0 }
        return Int(Date().timeIntervalSince(startTime))
    }
    
    private var remaining: Int { max(0, (liveSegment?.duration ?? 0) - elapsed) }
    private var progress: Double { min(1, Double(elapsed) / Double(liveSegment?.duration ?? 1)) }
    
    private var timeLeft: String {
        let upcomingTotal = segments.filter { $0.status == .upcoming }.reduce(0) { $0 + $1.duration }
        return Segment.formatTime(remaining + upcomingTotal)
    }
    
    private var mySegments: [Segment] { segments.filter { $0.assignedRole == currentUser.position } }
    private var myNextSegment: Segment? { mySegments.first { $0.status == .upcoming } }
    private var amILive: Bool { liveSegment?.assignedRole == currentUser.position }
    private var myEquipment: [Equipment] { authState.equipment.filter { $0.assignedTo == currentUser.displayName } }
    private var myTeam: [AppUser] { members.filter { $0.team == currentUser.team } }
    private var team: Team? { Team.find(currentUser.team) }
    private var onlineCount: Int { members.filter { $0.status == .online }.count }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if isBroadcastLive {
                    if amILive { youAreLiveCard } else { broadcastLiveCard }
                } else {
                    standbyBanner
                }
                
                if isBroadcastLive { progressBar }
                
                if isBroadcastLive, let next = myNextSegment { upNextCard(segment: next) }
                
                statsRow
                memberQuickActions
                memberMessagesSection
                mySegmentsSection
                myEquipmentSection
                myTeamSection
                
                Spacer().frame(height: 80)
            }
            .padding(.vertical)
        }
        .background(Color.bhqBackground)
        .onReceive(timer) { _ in if isBroadcastLive { timerTick += 1 } }
    }
    
    // MARK: - Stats Row (matches admin)
    private var statsRow: some View {
        HStack(spacing: 10) {
            StatCard(value: "\(onlineCount)/\(members.count)", label: "Online", color: .bhqGreen)
            StatCard(value: timeLeft, label: "Time Left", color: .bhqBlue)
            StatCard(value: "\(mySegments.count)", label: "My Segments", color: team?.color ?? .secondary)
        }.padding(.horizontal)
    }
    
    // MARK: - Progress Bar (matches admin)
    private var progressBar: some View {
        HStack(spacing: 3) {
            ForEach(segments) { seg in
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(seg.status == .completed ? Color.bhqGreen : seg.status == .live ? Color.bhqTint : Color(.systemFill))
                    .frame(height: 5)
            }
        }.padding(.horizontal)
    }
    
    // MARK: - You Are Live Card (matches admin liveNowCard)
    private var youAreLiveCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(Color.bhqTint).frame(width: 7, height: 7).pulsing()
                    Text("YOU'RE ON").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.bhqTint).tracking(0.5)
                }
                Spacer()
                Text("Segment \(liveIndex + 1) of \(segments.count)").font(.system(size: 12)).foregroundStyle(Color.secondary)
            }
            
            Text(liveSegment?.title ?? "No active segment").font(.system(size: 22, weight: .bold))
            Text("\(liveSegment?.assignedRole ?? "") · \(liveSegment?.notes ?? "")").font(.subheadline).foregroundStyle(Color.secondary)
            
            // Timer — same as admin
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("REMAINING").font(.system(size: 11, weight: .medium)).foregroundStyle(Color.secondary.opacity(0.5)).tracking(0.5)
                    Text(Segment.formatTime(remaining)).font(.system(size: 40, weight: .bold, design: .rounded)).monospacedDigit()
                        .foregroundStyle(remaining < 60 ? Color.bhqTint : Color.primary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(Int(progress * 100))%").font(.subheadline).foregroundStyle(Color.secondary)
                    Text(Segment.formatTime(broadcastElapsed))
                        .font(.system(size: 12, weight: .medium, design: .rounded)).monospacedDigit()
                        .foregroundStyle(Color.secondary.opacity(0.5))
                }
            }
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(Color(.systemFill))
                    RoundedRectangle(cornerRadius: 2).fill(remaining < 60 ? Color.bhqTint : Color.bhqGreen)
                        .frame(width: geo.size.width * progress).animation(.linear(duration: 1), value: progress)
                }
            }.frame(height: 4)
        }
        .padding(16)
        .background(LinearGradient(colors: [Color.bhqTint.opacity(0.1), Color.bhqCard], startPoint: .topLeading, endPoint: .bottomTrailing))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.bhqTint.opacity(0.2), lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 16)).padding(.horizontal)
    }
    
    // MARK: - Broadcast Live Card (someone else is on — same style)
    private var broadcastLiveCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(Color.bhqTint).frame(width: 7, height: 7).pulsing()
                    Text("ON AIR").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.bhqTint).tracking(0.5)
                }
                Spacer()
                Text("Segment \(liveIndex + 1) of \(segments.count)").font(.system(size: 12)).foregroundStyle(Color.secondary)
            }
            
            Text(liveSegment?.title ?? "").font(.system(size: 22, weight: .bold))
            Text("\(liveSegment?.assignedRole ?? "") · \(liveSegment?.notes ?? "")").font(.subheadline).foregroundStyle(Color.secondary)
            
            // Timer — matches admin
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("REMAINING").font(.system(size: 11, weight: .medium)).foregroundStyle(Color.secondary.opacity(0.5)).tracking(0.5)
                    Text(Segment.formatTime(remaining)).font(.system(size: 40, weight: .bold, design: .rounded)).monospacedDigit()
                        .foregroundStyle(remaining < 60 ? Color.bhqTint : Color.primary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(Int(progress * 100))%").font(.subheadline).foregroundStyle(Color.secondary)
                    Text(Segment.formatTime(broadcastElapsed))
                        .font(.system(size: 12, weight: .medium, design: .rounded)).monospacedDigit()
                        .foregroundStyle(Color.secondary.opacity(0.5))
                }
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(Color(.systemFill))
                    RoundedRectangle(cornerRadius: 2).fill(remaining < 60 ? Color.bhqTint : Color.bhqGreen)
                        .frame(width: geo.size.width * progress).animation(.linear(duration: 1), value: progress)
                }
            }.frame(height: 4)
        }
        .padding(16)
        .background(LinearGradient(colors: [Color.bhqTint.opacity(0.1), Color.bhqCard], startPoint: .topLeading, endPoint: .bottomTrailing))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.bhqTint.opacity(0.2), lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 16)).padding(.horizontal)
    }
    
    // MARK: - Standby
    private var standbyBanner: some View {
        VStack(spacing: 8) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 28))
                .foregroundStyle(Color.secondary.opacity(0.4))
            Text("Standby")
                .font(.system(size: 18, weight: .semibold))
            Text("Waiting for broadcast to begin")
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color.bhqCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
    
    // MARK: - Up Next Card
    private func upNextCard(segment: Segment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.right.circle.fill").foregroundStyle(Color.bhqYellow).font(.system(size: 14))
                Text("UP NEXT FOR YOU").font(.system(size: 11, weight: .bold)).foregroundStyle(Color.bhqYellow).tracking(0.5)
            }
            Text(segment.title).font(.system(size: 16, weight: .semibold))
            Text("\(segment.formattedDuration) · \(segment.notes)").font(.system(size: 13)).foregroundStyle(Color.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.bhqYellow.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.bhqYellow.opacity(0.2), lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
    
    // MARK: - Quick Actions
    private var memberQuickActions: some View {
        HStack(spacing: 10) {
            Button { selectTab = .comms } label: {
                StatCard(value: "💬", label: "Comms", color: .bhqBlue)
            }.buttonStyle(.plain)
            Button { selectTab = .dms } label: {
                StatCard(value: "✉️", label: "DMs", color: .purple)
            }.buttonStyle(.plain)
            Button { selectTab = .equipment } label: {
                StatCard(value: "🔧", label: "Gear", color: .bhqYellow)
            }.buttonStyle(.plain)
        }.padding(.horizontal)
    }
    
    // MARK: - Messages
    private struct MemberMessageGroup: Identifiable {
        let id: String
        let name: String
        let initials: String
        let text: String
        let count: Int
        let time: Date
        let teamId: String?
    }
    
    private var memberMessageGroups: [MemberMessageGroup] {
        let myId = currentUser.id
        let relevant = authState.messages.filter { ($0.recipientId == myId || $0.recipientId == nil) && $0.senderId != myId }
        var grouped: [String: [ChatMessage]] = [:]
        for msg in relevant { grouped[msg.senderId, default: []].append(msg) }
        return grouped.compactMap { senderId, msgs -> MemberMessageGroup? in
            guard let latest = msgs.last else { return nil }
            return MemberMessageGroup(id: senderId, name: latest.senderName, initials: latest.senderInitials, text: latest.text, count: msgs.count, time: latest.timestamp, teamId: authState.accounts.first { $0.id == senderId }?.team)
        }.sorted { $0.time > $1.time }.prefix(5).map { $0 }
    }
    
    private var memberMessagesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Recent Messages")
            
            if memberMessageGroups.isEmpty {
                HStack {
                    Image(systemName: "bubble.left").foregroundStyle(Color.secondary)
                    Text("No messages yet").font(.subheadline).foregroundStyle(Color.secondary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(Color.bhqCard).clipShape(RoundedRectangle(cornerRadius: 12)).padding(.horizontal)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(memberMessageGroups.enumerated()), id: \.element.id) { index, group in
                        HStack(spacing: 10) {
                            let senderTeam = Team.find(group.teamId ?? "")
                            ProfileAvatar(userId: group.id, initials: group.initials, size: 32, color: senderTeam?.color ?? .secondary)
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(group.name).font(.system(size: 13, weight: .semibold))
                                    if group.count > 1 {
                                        HStack(spacing: 2) {
                                            Image(systemName: "bubble.left.fill").font(.system(size: 7))
                                            Text("\(group.count)").font(.system(size: 9, weight: .bold))
                                        }
                                        .foregroundStyle(Color.bhqBlue)
                                        .padding(.horizontal, 4).padding(.vertical, 2)
                                        .background(Color.bhqBlue.opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                    }
                                    Spacer()
                                    Text(group.time, style: .relative)
                                        .font(.system(size: 11)).foregroundStyle(Color.secondary.opacity(0.4))
                                }
                                Text(group.text).font(.system(size: 13)).foregroundStyle(Color.secondary).lineLimit(1)
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        if index < memberMessageGroups.count - 1 { Divider().padding(.leading, 56) }
                    }
                }
                .background(Color.bhqCard).clipShape(RoundedRectangle(cornerRadius: 12)).padding(.horizontal)
            }
        }
    }
    
    // MARK: - My Segments
    private var mySegmentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Your Segments")
            
            if mySegments.isEmpty {
                HStack {
                    Image(systemName: "list.bullet").foregroundStyle(Color.secondary)
                    Text("No segments assigned").font(.subheadline).foregroundStyle(Color.secondary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(Color.bhqCard).clipShape(RoundedRectangle(cornerRadius: 12)).padding(.horizontal)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(mySegments.enumerated()), id: \.element.id) { index, seg in
                        HStack(spacing: 10) {
                            statusIcon(for: seg)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(seg.title).font(.body).fontWeight(seg.status == .live ? .semibold : .regular)
                                    .foregroundStyle(seg.status == .completed ? Color.secondary : Color.primary)
                                Text("\(seg.formattedDuration) · \(seg.notes)").font(.system(size: 13)).foregroundStyle(Color.secondary).lineLimit(1)
                            }
                            Spacer()
                            if seg.status == .live {
                                Text("NOW").font(.system(size: 10, weight: .bold)).foregroundStyle(Color.bhqTint)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Color.bhqTint.opacity(0.18)).clipShape(RoundedRectangle(cornerRadius: 5))
                            } else if seg.status == .completed {
                                Image(systemName: "checkmark").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.bhqGreen)
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 11)
                        .background(seg.status == .live ? Color.bhqTint.opacity(0.04) : Color.clear)
                        if index < mySegments.count - 1 { Divider().padding(.leading, 52) }
                    }
                }
                .background(Color.bhqCard).clipShape(RoundedRectangle(cornerRadius: 12)).padding(.horizontal)
            }
        }
    }
    
    private func statusIcon(for seg: Segment) -> some View {
        let bgColor: Color = seg.status == .live ? Color.bhqTint.opacity(0.18) : seg.status == .completed ? Color.bhqGreen.opacity(0.15) : Color(.systemFill)
        let fgColor: Color = seg.status == .live ? Color.bhqTint : seg.status == .completed ? Color.bhqGreen : Color.secondary
        return Circle().fill(bgColor).frame(width: 28, height: 28)
            .overlay { Image(systemName: seg.status == .live ? "waveform" : seg.status == .completed ? "checkmark" : "clock").font(.system(size: 11, weight: .semibold)).foregroundStyle(fgColor) }
    }
    
    // MARK: - My Equipment
    private var myEquipmentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Your Equipment")
            if myEquipment.isEmpty {
                HStack {
                    Image(systemName: "tray").foregroundStyle(Color.secondary)
                    Text("No equipment checked out").font(.subheadline).foregroundStyle(Color.secondary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 20)
                .background(Color.bhqCard).clipShape(RoundedRectangle(cornerRadius: 12)).padding(.horizontal)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(myEquipment.enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: 12) {
                            Image(systemName: "wrench.and.screwdriver").font(.system(size: 14)).foregroundStyle(Color.secondary)
                                .frame(width: 28, height: 28).background(Color(.systemFill)).clipShape(RoundedRectangle(cornerRadius: 6))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.name).font(.body)
                                Text(item.type).font(.subheadline).foregroundStyle(Color.secondary)
                            }
                            Spacer()
                            if item.hasIssue {
                                Text(item.condition.rawValue.uppercased()).font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(item.condition == .missing ? Color.bhqYellow : Color.bhqTint)
                                    .padding(.horizontal, 6).padding(.vertical, 3)
                                    .background((item.condition == .missing ? Color.bhqYellow : Color.bhqTint).opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            } else {
                                Text("OK").font(.system(size: 10, weight: .semibold)).foregroundStyle(Color.bhqGreen)
                                    .padding(.horizontal, 6).padding(.vertical, 3)
                                    .background(Color.bhqGreen.opacity(0.15)).clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 11)
                        if index < myEquipment.count - 1 { Divider().padding(.leading, 52) }
                    }
                }
                .background(Color.bhqCard).clipShape(RoundedRectangle(cornerRadius: 12)).padding(.horizontal)
            }
        }
    }
    
    // MARK: - My Team
    private var myTeamSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { SectionHeader(title: "\(team?.name ?? "My") Team"); Spacer() }
            VStack(spacing: 0) {
                ForEach(Array(myTeam.enumerated()), id: \.element.id) { index, member in
                    NavigationLink(destination: MemberDetailView(member: member)) {
                        HStack(spacing: 12) {
                            ProfileAvatar(userId: member.id, initials: member.initials, size: 32, color: team?.color ?? .secondary)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(member.displayName).font(.subheadline).foregroundStyle(Color.primary)
                                Text(member.position).font(.caption).foregroundStyle(Color.secondary)
                            }
                            Spacer()
                            StatusIndicator(status: member.status)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 9)
                    }.buttonStyle(.plain)
                    if index < myTeam.count - 1 { Divider().padding(.leading, 56) }
                }
            }
            .background(Color.bhqCard).clipShape(RoundedRectangle(cornerRadius: 12)).padding(.horizontal)
        }
    }
}

#Preview("Member - Live & On") {
    NavigationStack {
        MemberDashboardView(selectTab: .constant(.dashboard), segments: .constant(Segment.samples), isBroadcastLive: .constant(true), currentUser: AppUser.samples[2])
            .navigationTitle("Dashboard").environmentObject(AuthState())
    }.preferredColorScheme(.dark)
}
