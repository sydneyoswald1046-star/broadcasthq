import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authState: AuthState
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var volumePTT: VolumeButtonPTT
    @Environment(\.horizontalSizeClass) var sizeClass
    
    @State private var selectedTab: Tab = .dashboard
    @State private var borderPulse: Bool = false
    @State private var showProfile: Bool = false
    @State private var showNotifications: Bool = false
    @State private var showApprovals: Bool = false
    @State private var showMonitor: Bool = false
    @State private var userDismissedAlert: Bool = false
    @State private var greenGlowPulse: Bool = false
    @State private var isPTTActive: Bool = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .doubleColumn
    
    @ObservedObject private var audioService = PTTAudioService.shared
    
    private var currentUser: AppUser { authState.currentUser ?? AppUser.samples[0] }
    private var borderColor: Color { authState.isBroadcastLive ? Color.bhqTint : Color.bhqGreen }
    private var unreadCount: Int { authState.teamAlertHistory.filter { !$0.read }.count }
    private var isAdmin: Bool { currentUser.role == .admin || currentUser.role == .teamLead }
    private var theme: RoleTheme { RoleTheme.forUser(currentUser) }
    private var pendingCount: Int { authState.pendingMembers.count }
    private var tintColor: Color { isAdmin ? theme.primary : settings.accentColor }
    private var isIPad: Bool { sizeClass == .regular }
    
    private var totalDMCount: Int {
        let myId = currentUser.id
        return authState.messages.filter { $0.recipientId == myId }.count
    }
    
    private var shouldShowRedOverlay: Bool {
        guard let alert = authState.activeAlert else { return false }
        guard !userDismissedAlert else { return false }
        if alert.changedByUserId == currentUser.id { return false }
        if currentUser.role == .admin { return false }
        if alert.acknowledgedBy.contains(currentUser.id) { return false }
        return true
    }
    
    private var shouldShowAdminTracker: Bool {
        guard let alert = authState.activeAlert else { return false }
        if alert.changedByUserId == currentUser.id { return true }
        if currentUser.role == .admin && alert.changedByUserId != currentUser.id { return true }
        return false
    }
    
    enum Tab: String, CaseIterable, Hashable {
        case dashboard, rundown, comms, dms, equipment
        var icon: String {
            switch self {
            case .dashboard: return "square.grid.2x2.fill"; case .rundown: return "list.bullet.rectangle.fill"
            case .comms: return "message.fill"; case .dms: return "paperplane.fill"; case .equipment: return "wrench.and.screwdriver.fill"
            }
        }
        var title: String {
            switch self {
            case .dashboard: return "Dashboard"; case .rundown: return "Rundown"
            case .comms: return "Comms"; case .dms: return "DMs"; case .equipment: return "Gear"
            }
        }
    }
    
    var body: some View {
        ZStack {
            HiddenVolumeView().frame(width: 0, height: 0)
            
            if isIPad {
                iPadLayout
            } else {
                iPhoneLayout
            }
            
            // All overlays (shared between iPad and iPhone)
            overlays
        }
        .onAppear {
            borderPulse = true
            if authState.isBroadcastLive { volumePTT.activate() }
            authState.startAudioService()
            UIApplication.shared.isIdleTimerDisabled = true
            ExternalScreenManager.shared.configure(authState: authState, settings: settings)
        }
        .onDisappear {
            volumePTT.deactivate()
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: authState.isBroadcastLive) { _, isLive in
            if isLive { volumePTT.activate() } else { volumePTT.deactivate() }
        }
        .onChange(of: volumePTT.isTransmitting) { _, transmitting in
            // Volume PTT is supplementary — only works if user has already started PTT from a view
            if !transmitting && authState.isLocalTransmitting {
                authState.stopPTT()
            }
        }
        .onChange(of: authState.activeAlert?.id) { _, _ in userDismissedAlert = false }
        .onChange(of: authState.deepLinkTab) { _, tab in
            if let tab = tab, let target = Tab(rawValue: tab) {
                withAnimation(.easeOut(duration: 0.15)) { selectedTab = target }
                authState.deepLinkTab = nil
            }
        }
        .fullScreenCover(isPresented: $showMonitor) {
            NavigationStack {
                NDIMonitorView()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button { showMonitor = false } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("Close")
                                        .font(.system(size: 15, weight: .medium))
                                }
                                .foregroundStyle(Color.bhqBlue)
                            }
                        }
                    }
            }
        }
    }
    
    // MARK: - iPad Layout
    private var iPadLayout: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            iPadSidebar
                .navigationSplitViewColumnWidth(min: 260, ideal: 280, max: 320)
        } detail: {
            NavigationStack {
                detailView
                    .navigationTitle(selectedTab.title)
                    .navigationBarTitleDisplayMode(.large)
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { toolbarItems } }
                    .navigationDestination(isPresented: $showProfile) {
                        ProfileView(currentUser: Binding(get: { authState.currentUser ?? AppUser.samples[0] }, set: { authState.currentUser = $0 }))
                            .environmentObject(authState).environmentObject(settings)
                    }
                    .navigationDestination(isPresented: $showNotifications) { NotificationsView() }
                    .navigationDestination(isPresented: $showApprovals) { AdminApprovalView().environmentObject(authState) }
            }
        }
        .tint(tintColor)
        .navigationSplitViewStyle(.balanced)
    }
    
    // MARK: - iPad Sidebar
    private var iPadSidebar: some View {
        VStack(spacing: 0) {
            // Header — Logo + Org + Live Status
            VStack(spacing: 10) {
                HStack(spacing: 0) {
                    Text("Valor").font(.system(size: 22, weight: .bold)).foregroundStyle(Color.white)
                    Text(".").font(.system(size: 22, weight: .bold)).foregroundStyle(Color(red: 1, green: 0.42, blue: 0.1))
                    Text("Live").font(.system(size: 22, weight: .bold)).foregroundStyle(Color.white)
                }
                
                if !authState.orgName.isEmpty {
                    Text(authState.orgName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.secondary)
                }
                
                // Live indicator
                if authState.isBroadcastLive {
                    HStack(spacing: 6) {
                        Circle().fill(Color.bhqTint).frame(width: 8, height: 8).pulsing()
                        Text("ON AIR").font(.system(size: 11, weight: .bold)).foregroundStyle(Color.bhqTint).tracking(1)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(Color.bhqTint.opacity(0.12))
                    .clipShape(Capsule())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                LinearGradient(colors: [Color(white: 0.08), Color.bhqBackground], startPoint: .top, endPoint: .bottom)
            )
            
            Divider()
            
            // Navigation Items
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(Tab.allCases, id: \.self) { tab in
                        sidebarItem(tab: tab)
                    }
                    
                    Divider().padding(.vertical, 8).padding(.horizontal, 16)
                    
                    // Admin-only items
                    if isAdmin {
                        if pendingCount > 0 {
                            sidebarButton(icon: "person.badge.clock", title: "Approvals", badge: "\(pendingCount)", color: .bhqYellow) {
                                showApprovals = true
                            }
                        }
                    }
                    
                    sidebarButton(icon: "video.fill", title: "NDI Monitor", badge: nil, color: .bhqBlue) {
                        showMonitor = true
                    }
                    sidebarButton(icon: "bell.fill", title: "Notifications", badge: unreadCount > 0 ? "\(unreadCount)" : nil, color: .secondary) {
                        showNotifications = true
                    }
                }
                .padding(.vertical, 12)
            }
            
            Divider()
            
            // Connected Peers
            if audioService.connectedPeers > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 12)).foregroundStyle(Color.bhqGreen)
                    Text("\(audioService.connectedPeers) nearby")
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(Color.bhqGreen)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.bhqGreen.opacity(0.06))
            }
            
            // PTT is handled inside CommsView and DMView input bars
            
            Divider()
            
            // User Profile Card
            Button { showProfile = true } label: {
                HStack(spacing: 10) {
                    Text(currentUser.initials)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(isAdmin ? theme.primary : Color.secondary)
                        .frame(width: 36, height: 36)
                        .background(isAdmin ? theme.primary.opacity(0.1) : Color(.systemFill))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(
                            LinearGradient(colors: isAdmin ? theme.gradient : [statusColor, statusColor],
                                startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(currentUser.displayName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.primary)
                        
                        HStack(spacing: 4) {
                            Image(systemName: theme.icon).font(.system(size: 9))
                            Text(theme.badge).font(.system(size: 10, weight: .bold)).tracking(0.3)
                        }
                        .foregroundStyle(theme.primary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.secondary.opacity(0.4))
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
            .buttonStyle(.plain)
        }
        .background(Color.bhqBackground)
    }
    
    private func sidebarItem(tab: Tab) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) { selectedTab = tab }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: tab.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(selectedTab == tab ? tintColor : Color.secondary)
                    .frame(width: 24)
                
                Text(tab.title)
                    .font(.system(size: 15, weight: selectedTab == tab ? .semibold : .regular))
                    .foregroundStyle(selectedTab == tab ? Color.primary : Color.secondary)
                
                Spacer()
                
                if tab == .comms && authState.isChannelBusy {
                    Circle().fill(Color.bhqYellow).frame(width: 8, height: 8)
                }
                
                if tab == .dms && totalDMCount > 0 {
                    Text("\(totalDMCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(minWidth: 20, minHeight: 20)
                        .background(Color.bhqTint)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 11)
            .background(selectedTab == tab ? tintColor.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }
    
    private func sidebarButton(icon: String, title: String, badge: String?, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 16, weight: .medium)).foregroundStyle(color).frame(width: 24)
                Text(title).font(.system(size: 15)).foregroundStyle(Color.secondary)
                Spacer()
                if let badge = badge {
                    Text(badge).font(.system(size: 11, weight: .bold)).foregroundStyle(Color.white)
                        .frame(minWidth: 20, minHeight: 20).background(color).clipShape(Circle())
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 11)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }
    
    // iPad PTT in sidebar
    private var iPadPTTButton: some View {
        Button { } label: {
            HStack(spacing: 10) {
                Image(systemName: authState.isChannelBusy ? "mic.slash" : (isPTTActive || authState.isLocalTransmitting) ? "mic.fill" : "mic")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.white)
                
                Text(authState.isChannelBusy ? "\(authState.channelBusyUserName) is talking" : (isPTTActive || authState.isLocalTransmitting) ? "Transmitting..." : "Hold to Talk")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white)
                
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(
                authState.isChannelBusy ? Color.secondary.opacity(0.3) :
                (isPTTActive || authState.isLocalTransmitting) ? Color.bhqTint :
                Color.bhqGreen
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 12).padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .disabled(authState.isChannelBusy)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPTTActive && !authState.isChannelBusy {
                        isPTTActive = true
                        authState.startPTT(channel: "global")
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
    }
    
    // MARK: - iPhone Layout
    private var iPhoneLayout: some View {
        TabView(selection: $selectedTab) {
            ForEach(Tab.allCases, id: \.self) { tab in
                NavigationStack {
                    detailView
                        .navigationTitle(tab.title).navigationBarTitleDisplayMode(.large)
                        .toolbar { ToolbarItem(placement: .topBarTrailing) { toolbarItems } }
                        .navigationDestination(isPresented: $showProfile) {
                            ProfileView(currentUser: Binding(get: { authState.currentUser ?? AppUser.samples[0] }, set: { authState.currentUser = $0 }))
                                .environmentObject(authState).environmentObject(settings)
                        }
                        .navigationDestination(isPresented: $showNotifications) { NotificationsView() }
                        .navigationDestination(isPresented: $showApprovals) { AdminApprovalView().environmentObject(authState) }
                }
                .tabItem { Label(tab.title, systemImage: tab.icon) }.tag(tab)
            }
        }
        .tint(tintColor)
    }
    
    // MARK: - Shared Detail View
    private var detailView: some View {
        Group {
            switch selectedTab {
            case .dashboard:
                if isAdmin {
                    DashboardView(selectTab: $selectedTab, segments: $authState.segments, isBroadcastLive: $authState.isBroadcastLive, currentUser: currentUser)
                } else {
                    MemberDashboardView(selectTab: $selectedTab, segments: $authState.segments, isBroadcastLive: $authState.isBroadcastLive, currentUser: currentUser)
                }
            case .rundown: RundownView(segments: $authState.segments, currentUser: currentUser)
            case .comms: CommsView()
            case .dms: DMView()
            case .equipment: EquipmentView()
            }
        }
    }
    
    // MARK: - Shared Toolbar Items
    private var toolbarItems: some View {
        HStack(spacing: 10) {
            if authState.isBroadcastLive {
                HStack(spacing: 4) {
                    Circle().fill(Color.bhqTint).frame(width: 6, height: 6).pulsing()
                    Text("LIVE").font(.system(size: 10, weight: .bold)).foregroundStyle(Color.bhqTint)
                }
            }
            if isAdmin {
                HStack(spacing: 3) {
                    Image(systemName: theme.icon).font(.system(size: 8, weight: .bold))
                    Text(theme.badge).font(.system(size: 8, weight: .bold)).tracking(0.5)
                }.foregroundStyle(theme.primary).padding(.horizontal, 7).padding(.vertical, 3)
                .background(theme.primary.opacity(0.12)).clipShape(Capsule())
            }
            if isAdmin && pendingCount > 0 && !isIPad {
                Button { showApprovals = true } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "person.badge.clock").foregroundStyle(Color.bhqYellow)
                        Text("\(pendingCount)").font(.system(size: 9, weight: .bold)).foregroundStyle(Color.white)
                            .frame(width: 16, height: 16).background(Color.bhqYellow).clipShape(Circle()).offset(x: 6, y: -6)
                    }
                }
            }
            if !isIPad {
                Button { showMonitor = true } label: {
                    Image(systemName: "video.fill").foregroundStyle(Color.bhqBlue)
                }
                Button { showNotifications = true } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell.fill").foregroundStyle(Color.secondary)
                        if unreadCount > 0 {
                            Text("\(unreadCount)").font(.system(size: 9, weight: .bold)).foregroundStyle(Color.white)
                                .frame(width: 16, height: 16).background(settings.accentColor).clipShape(Circle()).offset(x: 6, y: -6)
                        }
                    }
                }
            }
            Button { showProfile = true } label: {
                if settings.showAvatars {
                    Text(currentUser.initials).font(.system(size: 11, weight: .bold))
                        .foregroundStyle(isAdmin ? theme.primary : Color.secondary)
                        .frame(width: 28, height: 28)
                        .background(isAdmin ? theme.primary.opacity(0.1) : Color(.systemFill)).clipShape(Circle())
                        .overlay(Circle().stroke(
                            isAdmin ? LinearGradient(colors: theme.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [statusColor, statusColor], startPoint: .top, endPoint: .bottom), lineWidth: 2))
                        .shadow(color: isAdmin ? theme.glow.opacity(0.3) : Color.clear, radius: 4)
                } else {
                    Image(systemName: "person.circle.fill").foregroundStyle(Color.secondary)
                }
            }
        }
    }
    
    // MARK: - Overlays (shared)
    private var overlays: some View {
        ZStack {
            if settings.showLiveBorder { liveBorderOverlay }
            
            if let dirAlert = authState.directorChangeAlert, currentUser.role == .admin {
                greenGlowOverlay
                DirectorChangeBanner(alert: dirAlert) { authState.dismissDirectorAlert() }.zIndex(99)
            }
            
            if shouldShowRedOverlay, let alert = authState.activeAlert {
                SegmentChangeOverlay(alert: alert) { withAnimation { userDismissedAlert = true } }
                    .environmentObject(authState).transition(.opacity).zIndex(100)
            }
            
            if shouldShowAdminTracker, let alert = authState.activeAlert {
                VStack { Spacer()
                    AcknowledgmentTracker(alert: alert) { withAnimation { authState.activeAlert = nil } }
                        .environmentObject(authState).padding(.bottom, isIPad ? 20 : 90)
                }.transition(.move(edge: .bottom).combined(with: .opacity)).zIndex(98)
            }
            
            // PTT is handled inside CommsView and DMView input bars
            // No floating button needed
            
            // Team Alert Banner — slides in from top with red pulse
            if let teamAlert = authState.incomingTeamAlert {
                TeamAlertBanner(alert: teamAlert) {
                    withAnimation { authState.incomingTeamAlert = nil }
                }
                .zIndex(200)
                .transition(.move(edge: .top))
            }
            
            if isPTTActive || volumePTT.isTransmitting || authState.isLocalTransmitting {
                transmitOverlay.transition(.opacity).zIndex(97)
            }
            
            if authState.isChannelBusy && !isPTTActive && !authState.isLocalTransmitting {
                channelBusyBanner.transition(.move(edge: .top).combined(with: .opacity)).zIndex(97)
            }
        }
    }
    
    private var statusColor: Color {
        switch currentUser.status {
        case .online: return Color.bhqGreen; case .busy: return Color.bhqYellow; case .offline: return Color(.systemGray3)
        }
    }
    
    // MARK: - Floating PTT (iPhone only)
    private var floatingPTTButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: authState.isChannelBusy
                                    ? [Color.secondary.opacity(0.3), Color.secondary.opacity(0.2)]
                                    : (isPTTActive || volumePTT.isTransmitting)
                                        ? [Color.bhqTint, Color(red: 0.85, green: 0.15, blue: 0.1)]
                                        : [Color.bhqGreen, Color(red: 0.1, green: 0.65, blue: 0.25)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)
                        .overlay {
                            VStack(spacing: 3) {
                                Image(systemName: authState.isChannelBusy ? "mic.slash" : (isPTTActive || volumePTT.isTransmitting) ? "mic.fill" : "mic")
                                    .font(.system(size: 26, weight: .semibold)).foregroundStyle(Color.white)
                                Text(authState.isChannelBusy ? "BUSY" : (isPTTActive || volumePTT.isTransmitting) ? "LIVE" : "PTT")
                                    .font(.system(size: 9, weight: .heavy)).foregroundStyle(Color.white.opacity(0.9)).tracking(1)
                            }
                        }
                        .overlay(Circle().stroke((isPTTActive || volumePTT.isTransmitting) ? Color.bhqTint.opacity(0.6) : Color.bhqGreen.opacity(0.4), lineWidth: 2).frame(width: 76, height: 76))
                        .shadow(color: (isPTTActive || volumePTT.isTransmitting) ? Color.bhqTint.opacity(0.5) : Color.bhqGreen.opacity(0.3), radius: (isPTTActive || volumePTT.isTransmitting) ? 12 : 6)
                        .scaleEffect((isPTTActive || volumePTT.isTransmitting) ? 1.05 : 1.0)
                        .animation(.easeOut(duration: 0.1), value: isPTTActive || volumePTT.isTransmitting)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in
                                    if !isPTTActive && !authState.isChannelBusy {
                                        isPTTActive = true; authState.startPTT(channel: "global")
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
                }
                .padding(.trailing, 16).padding(.bottom, 90)
            }
        }
    }
    
    // MARK: - Transmit Indicator
    private var transmitOverlay: some View {
        VStack {
            HStack(spacing: 10) {
                Circle().fill(Color.white).frame(width: 8, height: 8)
                Image(systemName: "mic.fill").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.white)
                Text("TRANSMITTING").font(.system(size: 12, weight: .bold)).foregroundStyle(Color.white).tracking(1)
                if audioService.connectedPeers > 0 {
                    Text("· \(audioService.connectedPeers) nearby").font(.system(size: 11)).foregroundStyle(Color.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 10)
            .background(Color.bhqTint).clipShape(Capsule())
            .shadow(color: Color.bhqTint.opacity(0.4), radius: 8)
            .padding(.top, 55)
            Spacer()
        }
    }
    
    // MARK: - Channel Busy Banner
    private var channelBusyBanner: some View {
        VStack {
            HStack(spacing: 10) {
                Image(systemName: "mic.fill").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.bhqYellow)
                Text("\(authState.channelBusyUserName) is talking").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.white)
                Spacer()
                Text("BUSY").font(.system(size: 10, weight: .bold)).foregroundStyle(Color.bhqYellow).tracking(0.5)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Color(white: 0.15)).clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.bhqYellow.opacity(0.3), lineWidth: 0.5))
            .padding(.horizontal, 16).padding(.top, 55)
            Spacer()
        }
    }
    
    // MARK: - Green Glow
    private var greenGlowOverlay: some View {
        RoundedRectangle(cornerRadius: 0)
            .stroke(LinearGradient(colors: [
                Color.bhqGreen.opacity(greenGlowPulse ? 0.7 : 0.2), Color.bhqGreen.opacity(greenGlowPulse ? 0.4 : 0.1),
                Color.clear, Color.clear, Color.clear,
                Color.bhqGreen.opacity(greenGlowPulse ? 0.4 : 0.1), Color.bhqGreen.opacity(greenGlowPulse ? 0.7 : 0.2)
            ], startPoint: .top, endPoint: .bottom), lineWidth: 3)
            .ignoresSafeArea().allowsHitTesting(false)
            .onAppear { withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { greenGlowPulse = true } }
            .overlay {
                VStack {
                    LinearGradient(colors: [Color.bhqGreen.opacity(greenGlowPulse ? 0.3 : 0.05), Color.clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: 80).allowsHitTesting(false)
                    Spacer()
                }.ignoresSafeArea().allowsHitTesting(false)
            }
    }
    
    // MARK: - Live Border
    private var liveBorderOverlay: some View {
        RoundedRectangle(cornerRadius: 0)
            .stroke(LinearGradient(colors: [
                borderColor.opacity(borderPulse ? 0.6 : 0.15), borderColor.opacity(borderPulse ? 0.3 : 0.05),
                Color.clear, Color.clear, Color.clear,
                borderColor.opacity(borderPulse ? 0.3 : 0.05), borderColor.opacity(borderPulse ? 0.6 : 0.15)
            ], startPoint: .top, endPoint: .bottom), lineWidth: 2)
            .ignoresSafeArea().allowsHitTesting(false)
            .animation(settings.animationsEnabled ? .easeInOut(duration: authState.isBroadcastLive ? 1.5 : 3.0).repeatForever(autoreverses: true) : .linear(duration: 0), value: borderPulse)
            .overlay {
                VStack {
                    LinearGradient(colors: [borderColor.opacity(borderPulse ? 0.25 : 0.05), borderColor.opacity(borderPulse ? 0.08 : 0.0), Color.clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: 60).allowsHitTesting(false)
                    Spacer()
                    LinearGradient(colors: [Color.clear, borderColor.opacity(borderPulse ? 0.08 : 0.0), borderColor.opacity(borderPulse ? 0.2 : 0.05)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 50).allowsHitTesting(false)
                }.ignoresSafeArea().allowsHitTesting(false)
            }
            .overlay {
                HStack {
                    LinearGradient(colors: [borderColor.opacity(borderPulse ? 0.15 : 0.03), Color.clear], startPoint: .leading, endPoint: .trailing).frame(width: 15).allowsHitTesting(false)
                    Spacer()
                    LinearGradient(colors: [Color.clear, borderColor.opacity(borderPulse ? 0.15 : 0.03)], startPoint: .leading, endPoint: .trailing).frame(width: 15).allowsHitTesting(false)
                }.ignoresSafeArea().allowsHitTesting(false)
            }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthState()).environmentObject(AppSettings()).environmentObject(VolumeButtonPTT())
        .preferredColorScheme(.dark)
}
