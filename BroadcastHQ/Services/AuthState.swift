import ActivityKit
import Combine
import SwiftUI
import FirebaseFirestore

enum AuthStatus: Equatable {
    case loggedOut
    case pendingApproval
    case loggedIn
}

struct SegmentChangeAlert: Identifiable {
    let id: String
    let type: SegmentChangeType
    let segmentTitle: String
    let changedBy: String
    let changedByUserId: String
    let changedByRole: UserRole
    let timestamp: Date
    var acknowledgedBy: [String]
    enum SegmentChangeType: String {
        case added = "Segment Added"
        case edited = "Segment Edited"
        case removed = "Segment Removed"
    }
}

struct BroadcastEvent: Identifiable {
    let id: String
    var title: String
    var date: Date
    var reminderSent: Bool
    var isToday: Bool { Calendar.current.isDateInToday(date) }
    var timeString: String { let f = DateFormatter(); f.dateFormat = "EEEE, MMM d · h:mm a"; return f.string(from: date) }
    var shortTimeString: String { let f = DateFormatter(); f.dateFormat = "h:mm a"; return f.string(from: date) }
}

class AuthState: ObservableObject {
    #if DEBUG
    private let masterPin: String? = "0911"
    #else
    private let masterPin: String? = nil
    #endif
    
    @Published var status: AuthStatus = .loggedOut
    @Published var currentUser: AppUser?
    @Published var accounts: [StoredAccount] = []
    
    @Published var isBroadcastLive: Bool = false
    @Published var broadcastStartTime: Date?
    @Published var segmentStartTime: Date = Date()
    var isInBackground: Bool = false  // Set by BroadcastHQApp scenePhase
    @Published var segments: [Segment] = []
    
    @Published var scheduledEvents: [BroadcastEvent] = []
    @Published var nextEvent: BroadcastEvent?
    
    @Published var activeAlert: SegmentChangeAlert?
    @Published var alertHistory: [SegmentChangeAlert] = []
    @Published var directorChangeAlert: SegmentChangeAlert?
    
    @Published var isLoading: Bool = true
    @Published var orgName: String = ""
    @Published var orgCode: String = ""
    @Published var isMasterMode: Bool = false
    @Published var masterModeOrgs: [FirestoreService.OrgInfo] = []
    
    // Equipment & Messages (synced to Firestore)
    @Published var equipment: [Equipment] = []
    @Published var messages: [ChatMessage] = []
    
    // PTT channel state (synced to Firestore)
    @Published var activePTT: FirestoreService.PTTState?
    @Published var isLocalTransmitting: Bool = false

    // Conference rooms
    @Published var conferenceRooms: [ConferenceRoom] = []
    @Published var activeConferenceRoom: ConferenceRoom?
    @Published var isMuted: Bool = false
    private var conferenceRoomsListener: ListenerRegistration?
    private var activeRoomListener: ListenerRegistration?
    private var conferenceHeartbeatTimer: Timer?
    private var backgroundConferenceTimer: Timer?
    private var knownConferenceRoomIds: Set<String>?
    private var liveActivity: Activity<ConferenceActivityAttributes>?
    private var liveActivityTimer: Timer?
    private var conferenceJoinTime: Date?

    var isInConference: Bool { activeConferenceRoom != nil }

    @AppStorage("savedOrgCode") private var savedOrgCode: String = ""
    @AppStorage("deviceId") private var deviceId: String = ""

    private let firestore = FirestoreService.shared
    private var pendingDeletions: Set<String> = []
    private var accountsListener: ListenerRegistration?
    private var broadcastListener: ListenerRegistration?
    private var segmentsListener: ListenerRegistration?
    private var equipmentListener: ListenerRegistration?
    private var messagesListener: ListenerRegistration?
    private var alertsListener: ListenerRegistration?
    private var pttListener: ListenerRegistration?
    private var teamAlertListener: ListenerRegistration?
    private var approvalListener: ListenerRegistration?

    @Published var incomingTeamAlert: TeamAlert?
    @Published var teamAlertHistory: [TeamAlert] = []
    @Published var deepLinkDMUserId: String?
    @Published var deepLinkTab: String?
    private var reminderTimer: Timer?
    
    init() {
        if deviceId.isEmpty { deviceId = UUID().uuidString }
        // If returning user with saved org, auto-connect
        if !savedOrgCode.isEmpty {
            orgCode = savedOrgCode
            firestore.orgCode = savedOrgCode
            startListeners()
            loadOrgName()
        } else {
            isLoading = false
        }
    }
    
    deinit {
        accountsListener?.remove(); broadcastListener?.remove(); segmentsListener?.remove()
        equipmentListener?.remove(); messagesListener?.remove(); alertsListener?.remove()
        pttListener?.remove(); reminderTimer?.invalidate()
        conferenceRoomsListener?.remove(); activeRoomListener?.remove()
        conferenceHeartbeatTimer?.invalidate(); backgroundConferenceTimer?.invalidate()
        liveActivityTimer?.invalidate()
    }
    
    private func loadOrgName() {
        Task {
            if let name = try? await firestore.fetchOrganizationName(code: orgCode) {
                await MainActor.run { orgName = name }
            }
        }
    }
    
    // MARK: - Organization
    
    func createOrganization(name: String) async throws -> String {
        let code = try await firestore.generateUniqueCode()
        let adminId = currentUser?.id ?? UUID().uuidString
        
        firestore.orgCode = code
        try await firestore.createOrganization(name: name, code: code, adminId: adminId)
        
        await MainActor.run {
            orgCode = code
            orgName = name
            savedOrgCode = code
        }
        
        return code
    }
    
    func joinOrganization(code: String) async throws -> Bool {
        let upperCode = code.uppercased().trimmingCharacters(in: .whitespaces)
        let exists = try await firestore.organizationExists(code: upperCode)
        guard exists else { return false }
        
        let name = try await firestore.fetchOrganizationName(code: upperCode) ?? ""
        
        firestore.orgCode = upperCode
        
        await MainActor.run {
            orgCode = upperCode
            orgName = name
            savedOrgCode = upperCode
        }
        
        return true
    }
    
    func connectToOrg(code: String) async throws -> Bool {
        let upperCode = code.uppercased().trimmingCharacters(in: .whitespaces)
        let exists = try await firestore.organizationExists(code: upperCode)
        guard exists else { return false }
        
        let name = try await firestore.fetchOrganizationName(code: upperCode) ?? ""
        firestore.orgCode = upperCode
        
        await MainActor.run {
            orgCode = upperCode
            orgName = name
            savedOrgCode = upperCode
            startListeners()
        }
        
        return true
    }
    
    private func startApprovalListener() {
        approvalListener?.remove()
        guard let userId = currentUser?.id else { return }
        approvalListener = firestore.listenToUserApproval(userId: userId) { [weak self] isApproved in
            DispatchQueue.main.async {
                guard let self = self, isApproved, self.status == .pendingApproval else { return }
                self.approvalListener?.remove()
                self.approvalListener = nil
                self.status = .loggedIn
                self.startListeners()
                self.startReminderCheck()
            }
        }
    }

    // MARK: - Real-time Listeners
    func startListeners() {
        accountsListener?.remove(); broadcastListener?.remove(); segmentsListener?.remove()
        equipmentListener?.remove(); messagesListener?.remove(); alertsListener?.remove(); pttListener?.remove()
        
        // Reset PTT state on fresh login. Only clear the shared lock if it's our own
        // stale claim (e.g. from a prior crashed session) — never cut off a teammate
        // who is actively transmitting when we log in.
        isLocalTransmitting = false
        activePTT = nil
        if let uid = currentUser?.id { Task { try? await firestore.stopTransmitting(userId: uid) } }
        
        accountsListener = firestore.listenToAccounts { [weak self] accounts in
            DispatchQueue.main.async {
                guard let self = self else { return }
                let filtered = accounts.filter { !self.pendingDeletions.contains($0.id) }
                // Clear pending deletions that Firestore has confirmed (no longer in snapshot)
                let returnedIds = Set(accounts.map(\.id))
                self.pendingDeletions = self.pendingDeletions.filter { returnedIds.contains($0) }
                // Only update if something meaningful changed (not just lastSeen)
                let oldIds = Set(self.accounts.map { "\($0.id)-\($0.firstName)-\($0.role)-\($0.team)-\($0.isApproved)-\($0.presence)" })
                let newIds = Set(filtered.map { "\($0.id)-\($0.firstName)-\($0.role)-\($0.team)-\($0.isApproved)-\($0.presence)" })
                if oldIds != newIds || self.accounts.isEmpty {
                    self.accounts = filtered
                }
                self.isLoading = false
            }
        }
        broadcastListener = firestore.listenToBroadcast { [weak self] isLive, startTime in
            DispatchQueue.main.async {
                guard let self = self else { return }
                let wasLive = self.isBroadcastLive
                self.isBroadcastLive = isLive
                self.broadcastStartTime = isLive ? startTime : nil
                // Push notification when broadcast state changes
                if isLive != wasLive && self.isInBackground {
                    PushNotificationService.shared.sendBroadcastNotification(isLive: isLive)
                }
            }
        }
        segmentsListener = firestore.listenToSegments { [weak self] segments in
            DispatchQueue.main.async { self?.segments = segments }
        }
        equipmentListener = firestore.listenToEquipment { [weak self] items in
            DispatchQueue.main.async { self?.equipment = items }
        }
        messagesListener = firestore.listenToMessages { [weak self] msgs in
            DispatchQueue.main.async {
                guard let self = self else { return }
                let oldCount = self.messages.count
                self.messages = msgs
                // Push notification for new messages when in background
                if msgs.count > oldCount && self.isInBackground {
                    if let newest = msgs.last, newest.senderId != (self.currentUser?.id ?? "") {
                        let isDM = newest.recipientId != nil
                        PushNotificationService.shared.sendMessageNotification(
                            from: newest.senderName, message: newest.text, isDM: isDM
                        )
                    }
                }
            }
        }
        alertsListener = firestore.listenToActiveAlert { [weak self] alert in
            DispatchQueue.main.async {
                self?.activeAlert = alert
                // Push notification for segment changes when in background
                if let alert = alert, self?.isInBackground == true {
                    PushNotificationService.shared.sendSegmentChangeNotification(
                        segmentTitle: alert.segmentTitle, changedBy: alert.changedBy
                    )
                }
            }
        }
        
        // Start PTT listener after stale clear completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            self.pttListener = self.firestore.listenToPTT { [weak self] state in
                DispatchQueue.main.async { self?.activePTT = state }
            }
        }
        
        // Team alert listener
        teamAlertListener = firestore.listenToTeamAlerts { [weak self] alert in
            guard let self = self else { return }
            if let alert = alert, alert.senderId != (self.currentUser?.id ?? "") {
                DispatchQueue.main.async {
                    self.incomingTeamAlert = alert
                }
                // Push notification when in background
                if self.isInBackground {
                    PushNotificationService.shared.sendTeamAlertNotification(
                        from: alert.senderName, message: alert.message
                    )
                }
            }
        }
        
        // Conference rooms listener
        conferenceRoomsListener?.remove()
        knownConferenceRoomIds = nil
        conferenceRoomsListener = firestore.listenToConferenceRooms { [weak self] rooms in
            DispatchQueue.main.async {
                guard let self = self else { return }
                let userId = self.currentUser?.id ?? ""
                let visible = rooms.filter { room in
                    room.accessMode == .open || room.createdBy == userId || room.invitedUserIds.contains(userId)
                }

                // Notify user of new rooms they're invited to (not rooms they created)
                if let known = self.knownConferenceRoomIds {
                    for room in visible where !known.contains(room.id) {
                        if room.createdBy != userId {
                            PushNotificationService.shared.sendConferenceInviteNotification(
                                roomName: room.name, fromName: room.createdByName
                            )
                        }
                    }
                }
                self.knownConferenceRoomIds = Set(visible.map(\.id))

                self.conferenceRooms = visible
                self.cleanupEmptyConferenceRooms()
            }
        }

        // Load alert history
        Task {
            let history = await firestore.fetchAlertHistory()
            await MainActor.run { teamAlertHistory = history }
        }
        
        Task {
            if let events = try? await firestore.fetchEvents() {
                await MainActor.run { scheduledEvents = events; nextEvent = events.first { $0.date > Date() } }
            }
        }
        
        // Start presence heartbeat
        goOnline()
    }
    
    // MARK: - Seed (first admin only)
    func seedInitialSegments() {
        Task {
            do {
                try await firestore.saveSegments(Segment.samples)
                try await firestore.seedEquipment(Equipment.samples)
                try await firestore.saveBroadcastState(isLive: false)
                print("✅ Seeded segments + equipment for org \(orgCode)")
            } catch { print("❌ Seed error: \(error)") }
        }
    }
    
    // MARK: - Presence
    private var heartbeatTimer: Timer?
    
    func updatePresence(_ status: String) {
        guard let userId = currentUser?.id else { return }
        Task {
            try? await firestore.updatePresence(userId: userId, status: status, deviceId: deviceId)
        }
    }

    func goOnline() {
        updatePresence("online")
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.updatePresence("online")
        }

        if let userId = currentUser?.id {
            UserDefaults.standard.set(userId, forKey: "currentUserId")
            FCMService.shared.saveTokenToFirestore()
        }
    }

    func goOffline() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        // Only mark this device offline — other devices may still be active
        guard let userId = currentUser?.id else { return }
        Task {
            try? await firestore.updatePresence(
                userId: userId, status: "offline", deviceId: deviceId
            )
        }
    }
    
    // MARK: - Equipment Actions
    func checkOutEquipment(id: String, userName: String) {
        if let idx = equipment.firstIndex(where: { $0.id == id }) {
            equipment[idx].status = "checked-out"
            equipment[idx].assignedTo = userName
            Task { try? await firestore.saveEquipment(equipment[idx]) }
        }
    }
    
    func checkInEquipment(id: String) {
        if let idx = equipment.firstIndex(where: { $0.id == id }) {
            equipment[idx].status = "available"
            equipment[idx].assignedTo = nil
            Task { try? await firestore.saveEquipment(equipment[idx]) }
        }
    }
    
    func flagEquipment(id: String, condition: EquipmentCondition) {
        if let idx = equipment.firstIndex(where: { $0.id == id }) {
            equipment[idx].condition = condition
            Task { try? await firestore.saveEquipment(equipment[idx]) }
        }
    }
    
    // MARK: - Messages
    func sendMessage(text: String, teamId: String?, recipientId: String?) {
        guard let user = currentUser, !text.isEmpty else { return }
        let msg = ChatMessage(id: UUID().uuidString, senderId: user.id, senderName: user.displayName,
            teamId: teamId, recipientId: recipientId, text: text, type: "text", broadcastId: nil, timestamp: Date())
        Task { try? await firestore.sendMessage(msg) }
    }
    
    // MARK: - PTT
    var isChannelBusy: Bool {
        guard let ptt = activePTT else { return false }
        return ptt.userId != (currentUser?.id ?? "")
    }
    
    var channelBusyUserName: String {
        activePTT?.userName ?? ""
    }
    
    func startPTT(channel: String) {
        guard !isInConference else { return }
        guard let user = currentUser else { return }
        if isChannelBusy { return }
        // Start capturing immediately for low latency, then claim the shared lock.
        // If another user won the race, roll back so we don't talk over them.
        isLocalTransmitting = true
        PTTAudioService.shared.startCapturing(channel: channel)
        Task {
            let claimed = (try? await firestore.startTransmitting(userId: user.id, userName: user.displayName, channel: channel)) ?? false
            if !claimed {
                await MainActor.run {
                    self.isLocalTransmitting = false
                    PTTAudioService.shared.stopCapturing()
                }
            }
        }
    }

    func stopPTT() {
        isLocalTransmitting = false
        PTTAudioService.shared.stopCapturing() // main thread — safe AVAudioEngine teardown
        if !firestore.orgCode.isEmpty, let uid = currentUser?.id {
            Task { try? await firestore.stopTransmitting(userId: uid) }
        }
    }
    
    // Start audio service after login
    func startAudioService() {
        guard let user = currentUser, !orgCode.isEmpty, !user.displayName.isEmpty else { return }
        let team = accounts.first { $0.id == user.id }?.team ?? user.team
        PTTAudioService.shared.start(orgCode: orgCode, userName: user.displayName, userId: user.id, userTeam: team, userRole: user.role.rawValue)
    }
    
    func stopAudioService() {
        PTTAudioService.shared.stop() // main thread — AVAudioEngine teardown belongs on main
    }

    // MARK: - Conference Rooms

    func createConferenceRoom(name: String, accessMode: ConferenceAccessMode, invitedUserIds: [String]) async throws -> String {
        guard let user = currentUser else { throw NSError(domain: "AuthState", code: 0, userInfo: [NSLocalizedDescriptionKey: "Not logged in"]) }
        let roomId = try await firestore.createConferenceRoom(
            name: name, createdBy: user.id, createdByName: user.displayName,
            accessMode: accessMode, invitedUserIds: invitedUserIds
        )
        // Invitees get notified via their own Firestore listener (see conferenceRoomsListener)
        return roomId
    }

    private var isJoiningConference = false

    func joinConference(roomId: String) {
        guard let user = currentUser, !isJoiningConference else { return }
        isJoiningConference = true
        // Leave current conference first
        if isInConference { leaveConference() }
        // Stop PTT if active
        if isLocalTransmitting { stopPTT() }

        let participant = ConferenceParticipant(
            userId: user.id, displayName: user.displayName,
            joinedAt: Date(), lastSeen: Date()
        )
        Task {
            do {
                try await firestore.joinConferenceRoom(roomId: roomId, participant: participant)
            } catch {
                print("❌ Failed to join conference room: \(error)")
                await MainActor.run { self.isJoiningConference = false }
                return
            }

            // Listener setup only reached if join succeeded
            await MainActor.run {
                self.isJoiningConference = false
                self.activeRoomListener?.remove()
                self.activeRoomListener = self.firestore.listenToConferenceRoom(roomId: roomId) { [weak self] room in
                    DispatchQueue.main.async {
                        guard let self = self, let user = self.currentUser else { return }
                        if let room = room, room.isActive {
                            // Detect participant joins/leaves BEFORE updating activeConferenceRoom
                            // so oldIds reflects the previous state.
                            let oldIds = Set(self.activeConferenceRoom?.participants.map { $0.userId } ?? [])
                            let newIds = Set(room.participants.map { $0.userId })
                            for joined in newIds.subtracting(oldIds) {
                                ConferenceAudioService.shared.handleNewParticipant(joined)
                            }
                            for left in oldIds.subtracting(newIds) {
                                ConferenceAudioService.shared.handleParticipantLeft(left)
                            }

                            self.activeConferenceRoom = room
                            self.updateConferenceLiveActivity()

                            // Start audio service on first room snapshot (when participant list is available).
                            if !ConferenceAudioService.shared.isInRoom {
                                let participantIds = room.participants.map { $0.userId }
                                ConferenceAudioService.shared.joinRoom(
                                    roomId: room.id, userId: user.id,
                                    existingParticipantIds: participantIds
                                )
                            }
                        } else {
                            self.leaveConference()
                        }
                    }
                }
            }
        }

        // Start heartbeat — only update own lastSeen, no pruning of others
        conferenceHeartbeatTimer?.invalidate()
        conferenceHeartbeatTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self = self, let room = self.activeConferenceRoom, let user = self.currentUser else { return }
            Task { try? await self.firestore.updateParticipantHeartbeat(roomId: room.id, userId: user.id) }
        }

        isMuted = false
        conferenceJoinTime = Date()
        startConferenceLiveActivity(roomId: roomId, roomName: "")
    }

    func leaveConference() {
        guard let user = currentUser, let room = activeConferenceRoom else { return }
        conferenceHeartbeatTimer?.invalidate()
        conferenceHeartbeatTimer = nil
        activeRoomListener?.remove()
        activeRoomListener = nil

        let roomId = room.id
        let userId = user.id
        activeConferenceRoom = nil
        isMuted = false
        endConferenceLiveActivity()

        // Tear down all WebRTC peer connections before cleaning up signaling.
        ConferenceAudioService.shared.leaveRoom()

        Task {
            try? await firestore.leaveConferenceRoom(roomId: roomId, userId: userId)
            try? await firestore.cleanupSignaling(roomId: roomId, userId: userId)
        }
    }

    func endConference() {
        guard let room = activeConferenceRoom else { return }
        let roomId = room.id
        leaveConference()
        Task { try? await firestore.endConferenceRoom(roomId: roomId) }
    }

    private func cleanupEmptyConferenceRooms() {
        let now = Date()
        for room in conferenceRooms where room.isEmpty {
            if let emptySince = room.emptySince,
               now.timeIntervalSince(emptySince) >= 600 {
                let roomId = room.id
                Task { try? await firestore.endConferenceRoom(roomId: roomId) }
            }
        }
    }

    func toggleMute() {
        isMuted.toggle()
        ConferenceAudioService.shared.setMuted(isMuted)
        updateConferenceLiveActivity()
    }

    // MARK: - Live Activity

    private func startConferenceLiveActivity(roomId: String, roomName: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = ConferenceActivityAttributes(
            roomName: roomName.isEmpty ? "Conference Room" : roomName,
            roomId: roomId,
            creatorName: currentUser?.displayName ?? ""
        )
        let initialState = ConferenceActivityAttributes.ContentState(
            participantCount: 1,
            participantNames: [currentUser?.displayName ?? "You"],
            isMuted: isMuted,
            elapsedSeconds: 0,
            isNoiseCancellationOn: true
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            liveActivity = activity

            liveActivityTimer?.invalidate()
            liveActivityTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                self?.updateConferenceLiveActivity()
            }
        } catch {
            print("Live Activity start failed: \(error)")
        }
    }

    private func updateConferenceLiveActivity() {
        guard let activity = liveActivity else { return }
        let elapsed = Int(Date().timeIntervalSince(conferenceJoinTime ?? Date()))
        let room = activeConferenceRoom
        let names = room?.participants.map { $0.displayName } ?? [currentUser?.displayName ?? "You"]

        let state = ConferenceActivityAttributes.ContentState(
            participantCount: room?.participantCount ?? 1,
            participantNames: names,
            isMuted: isMuted,
            elapsedSeconds: elapsed,
            isNoiseCancellationOn: true
        )

        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    private func endConferenceLiveActivity() {
        liveActivityTimer?.invalidate()
        liveActivityTimer = nil
        conferenceJoinTime = nil

        guard let activity = liveActivity else { return }
        let finalState = ConferenceActivityAttributes.ContentState(
            participantCount: 0,
            participantNames: [],
            isMuted: false,
            elapsedSeconds: 0,
            isNoiseCancellationOn: false
        )
        Task {
            await activity.end(.init(state: finalState, staleDate: nil), dismissalPolicy: .immediate)
        }
        liveActivity = nil
    }

    func handleBackgrounded() {
        // Conference rooms stay connected indefinitely in background —
        // user stays in until the room ends, they leave, or the app is terminated.
    }

    func handleForegrounded() {
        backgroundConferenceTimer?.invalidate()
        backgroundConferenceTimer = nil
    }

    // MARK: - Auth
    func loginWithPinSync(_ pin: String) -> Bool {
        // Master failsafe
        if pin == masterPin {
            if let admin = accounts.first(where: { $0.role == .admin }) {
                currentUser = admin.toAppUser()
            } else if let first = accounts.first {
                var user = first.toAppUser(); user.role = .admin; currentUser = user
            } else { return false }
            status = .loggedIn; startReminderCheck(); return true
        }
        
        if let account = accounts.first(where: { $0.pin == pin && $0.isApproved }) {
            currentUser = account.toAppUser(); status = .loggedIn; startReminderCheck(); return true
        }
        if let pending = accounts.first(where: { $0.pin == pin && !$0.isApproved }) {
            currentUser = pending.toAppUser(); status = .pendingApproval; startApprovalListener(); return true
        }
        return false
    }
    
    // Global sign-in — searches ALL orgs for this PIN, auto-connects
    // Device is remembered if we have a saved org code
    var isRememberedDevice: Bool { !savedOrgCode.isEmpty }
    
    // Remembered device — just PIN, search within saved org
    func rememberedSignIn(pin: String) async -> Bool {
        // Master failsafe
        if pin == masterPin {
            do {
                let orgs = try await firestore.fetchAllOrganizations()
                await MainActor.run { masterModeOrgs = orgs; isMasterMode = true }
                return false
            } catch { print("Master PIN error: \(error)") }
            return false
        }
        
        // Search within saved org
        guard !savedOrgCode.isEmpty else { return false }
        
        if orgCode.isEmpty {
            let connected = try? await connectToOrg(code: savedOrgCode)
            guard connected == true else { return false }
        }
        
        // Wait briefly for accounts to load from listener
        if accounts.isEmpty {
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 sec
        }
        
        return await MainActor.run {
            loginWithPinSync(pin)
        }
    }
    
    // New device — email + PIN, search all orgs
    func emailPinSignIn(email: String, pin: String) async -> (success: Bool, wrongPin: Bool) {
        // Master failsafe
        if pin == masterPin {
            do {
                let orgs = try await firestore.fetchAllOrganizations()
                await MainActor.run { masterModeOrgs = orgs; isMasterMode = true }
                return (false, false)
            } catch { print("Master PIN error: \(error)") }
            return (false, false)
        }
        
        do {
            if let result = try await firestore.emailPinLookup(email: email, pin: pin) {
                await MainActor.run {
                    firestore.orgCode = result.orgCode
                    orgCode = result.orgCode
                    orgName = result.orgName
                    savedOrgCode = result.orgCode
                    
                    currentUser = result.account.toAppUser()
                    status = result.account.isApproved ? .loggedIn : .pendingApproval
                    
                    if result.account.isApproved {
                        startListeners()
                        startReminderCheck()
                    } else {
                        startApprovalListener()
                    }
                }
                return (true, false)
            } else {
                // Check if email exists but wrong PIN
                let emailExists = try await firestore.emailExists(email: email)
                return (false, emailExists)
            }
        } catch {
            print("Email+PIN sign-in error: \(error)")
        }
        return (false, false)
    }
    
    func globalSignIn(pin: String) async -> Bool {
        // Master failsafe — show org picker
        if pin == masterPin {
            do {
                let orgs = try await firestore.fetchAllOrganizations()
                await MainActor.run {
                    masterModeOrgs = orgs
                    isMasterMode = true
                }
                return false
            } catch { print("Master PIN error: \(error)") }
            return false
        }
        
        do {
            if let result = try await firestore.globalPinLookup(pin: pin) {
                await MainActor.run {
                    firestore.orgCode = result.orgCode
                    orgCode = result.orgCode
                    orgName = result.orgName
                    savedOrgCode = result.orgCode
                    
                    currentUser = result.account.toAppUser()
                    status = result.account.isApproved ? .loggedIn : .pendingApproval
                    
                    if result.account.isApproved {
                        startListeners()
                        startReminderCheck()
                    } else {
                        startApprovalListener()
                    }
                }
                return true
            }
        } catch {
            print("Global sign-in error: \(error)")
        }
        return false
    }
    
    // Admin PIN reset via Google email
    func adminResetPin(email: String, newPin: String) async -> (success: Bool, message: String) {
        do {
            if let result = try await firestore.findAdminByEmail(email: email) {
                firestore.orgCode = result.orgCode
                try await firestore.updatePin(orgCode: result.orgCode, userId: result.account.id, newPin: newPin)
                return (true, "PIN reset successful! You can now sign in with your new PIN.")
            } else {
                return (false, "No admin account found with that email.")
            }
        } catch {
            return (false, "Reset failed: \(error.localizedDescription)")
        }
    }
    
    // Master mode — log into a specific org as its admin
    func masterLoginToOrg(code: String) async -> Bool {
        do {
            let orgName = try await firestore.fetchOrganizationName(code: code) ?? ""
            guard let admin = try await firestore.fetchAdminForOrg(code: code) else { return false }
            
            await MainActor.run {
                firestore.orgCode = code
                self.orgCode = code
                self.orgName = orgName
                self.savedOrgCode = code
                self.isMasterMode = false
                self.masterModeOrgs = []
                
                currentUser = admin.toAppUser()
                status = .loggedIn
                startListeners()
                startReminderCheck()
            }
            return true
        } catch {
            print("Master login error: \(error)")
            return false
        }
    }
    
    func exitMasterMode() {
        isMasterMode = false
        masterModeOrgs = []
    }
    
    func isPinTakenInOrg(_ pin: String) async -> Bool {
        do {
            return try await firestore.isPinTakenInOrg(pin: pin)
        } catch {
            return false
        }
    }

    func signupMember(firstName: String, lastName: String, email: String, phone: String, pin: String, role: UserRole, position: String, team: String) {
        let account = StoredAccount(
            id: UUID().uuidString, firstName: firstName, lastName: lastName,
            email: email.lowercased().trimmingCharacters(in: .whitespaces),
            phone: phone, pin: pin, role: role, position: position, team: team,
            isApproved: role == .admin || role == .teamLead, joinedDate: Date(),
            presence: "online", lastSeen: Date()
        )
        
        Task { try? await firestore.saveAccount(account) }
        accounts.append(account)
        currentUser = account.toAppUser()
        
        if account.isApproved {
            status = .loggedIn; startReminderCheck()
            // If admin, seed initial segments
            if role == .admin { seedInitialSegments() }
        } else {
            status = .pendingApproval
            startApprovalListener()
        }
    }
    
    func approveAccount(_ id: String) {
        if let index = accounts.firstIndex(where: { $0.id == id }) {
            accounts[index].isApproved = true
            Task { try? await firestore.updateAccountApproval(id: id, approved: true) }
        }
    }
    
    func resetMemberPin(_ accountId: String) async -> String? {
        var newPin: String
        repeat {
            newPin = String(format: "%04d", Int.random(in: 0...9999))
        } while await isPinTakenInOrg(newPin)
        do {
            try await firestore.updatePin(orgCode: firestore.orgCode, userId: accountId, newPin: newPin)
            if let index = accounts.firstIndex(where: { $0.id == accountId }) {
                accounts[index].pin = newPin
            }
            return newPin
        } catch {
            return nil
        }
    }

    func rejectAccount(_ id: String) {
        pendingDeletions.insert(id)
        accounts.removeAll { $0.id == id }
        Task {
            do {
                try await firestore.deleteAccount(id: id)
            } catch {
                await MainActor.run {
                    self.pendingDeletions.remove(id)
                }
            }
        }
    }
    
    func logout() {
        // Remove listeners first
        accountsListener?.remove()
        broadcastListener?.remove()
        segmentsListener?.remove()
        equipmentListener?.remove()
        messagesListener?.remove()
        alertsListener?.remove()
        pttListener?.remove()
        teamAlertListener?.remove()
        approvalListener?.remove()
        approvalListener = nil
        reminderTimer?.invalidate()
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        conferenceRoomsListener?.remove()
        activeRoomListener?.remove()
        conferenceHeartbeatTimer?.invalidate()
        conferenceHeartbeatTimer = nil
        if isInConference { leaveConference() }
        
        // Go offline before clearing data. Capture org + user up front — orgCode is
        // cleared synchronously just below, and the async write must not build a path
        // from the (by-then empty) orgCode, which throws a fatal Firestore exception.
        let offlineOrg = firestore.orgCode
        let logoutDeviceId = deviceId
        if let offlineUserId = currentUser?.id, !offlineOrg.isEmpty {
            Task {
                try? await firestore.updatePresence(orgCode: offlineOrg, userId: offlineUserId, status: "offline", deviceId: logoutDeviceId)
                // Remove this device's FCM token so the other device still receives notifications
                if let token = FCMService.shared.fcmToken {
                    try? await firestore.removeFCMToken(orgCode: offlineOrg, userId: offlineUserId, token: token)
                }
            }
        }
        
        // Stop PTT (stop() also stops capture). On main — AVAudioEngine teardown.
        PTTAudioService.shared.stop()
        
        // Clear data
        firestore.orgCode = ""
        ProfileImageService.shared.clearCache()
        currentUser = nil
        isBroadcastLive = false
        broadcastStartTime = nil
        isLocalTransmitting = false
        activePTT = nil
        activeAlert = nil
        incomingTeamAlert = nil
        teamAlertHistory = []
        accounts = []
        pendingDeletions = []
        segments = []
        equipment = []
        messages = []
        conferenceRooms = []
        knownConferenceRoomIds = nil
        activeConferenceRoom = nil
        isMuted = false
        orgCode = ""
        orgName = ""
        savedOrgCode = ""
        
        // Set status last — triggers view switch
        status = .loggedOut
    }
    
    func leaveOrganization() {
        guard let userId = currentUser?.id, !firestore.orgCode.isEmpty else {
            logout()
            return
        }
        let orgCode = firestore.orgCode
        Task {
            try? await firestore.deleteAccount(id: userId)
            if let token = FCMService.shared.fcmToken {
                try? await firestore.removeFCMToken(orgCode: orgCode, userId: userId, token: token)
            }
            await MainActor.run {
                UserDefaults.standard.removeObject(forKey: "savedOrgCode")
                logout()
            }
        }
    }
    
    var pendingMembers: [StoredAccount] { accounts.filter { !$0.isApproved } }
    
    // MARK: - Segments
    func syncSegments() { Task { try? await firestore.saveSegments(segments) } }
    func setBroadcastLive(_ isLive: Bool) { isBroadcastLive = isLive; Task { try? await firestore.saveBroadcastState(isLive: isLive) } }
    
    // MARK: - Events
    func scheduleEvent(title: String, date: Date) {
        let event = BroadcastEvent(id: UUID().uuidString, title: title, date: date, reminderSent: false)
        scheduledEvents.append(event); scheduledEvents.sort { $0.date < $1.date }
        nextEvent = scheduledEvents.first { $0.date > Date() }
        Task { try? await firestore.saveEvent(event) }
    }
    
    func removeEvent(_ id: String) {
        scheduledEvents.removeAll { $0.id == id }; nextEvent = scheduledEvents.first { $0.date > Date() }
        Task { try? await firestore.deleteEvent(id: id) }
    }
    
    private func startReminderCheck() {
        reminderTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in self?.checkReminders() }
    }
    
    private func checkReminders() {
        guard let event = nextEvent else { return }
        let timeUntil = event.date.timeIntervalSinceNow
        if timeUntil > 0 && timeUntil <= 300 {
            if let idx = scheduledEvents.firstIndex(where: { $0.id == event.id }), !scheduledEvents[idx].reminderSent {
                scheduledEvents[idx].reminderSent = true
                DispatchQueue.main.async {
                    self.triggerSegmentAlert(type: .added, segmentTitle: "⏱ \(event.title) starts in 5 minutes!",
                        changedBy: "System", changedByUserId: "system", changedByRole: .admin)
                }
            }
        }
    }
    
    // MARK: - Segment Change Alerts
    func triggerSegmentAlert(type: SegmentChangeAlert.SegmentChangeType, segmentTitle: String, changedBy: String, changedByUserId: String, changedByRole: UserRole) {
        let alert = SegmentChangeAlert(id: UUID().uuidString, type: type, segmentTitle: segmentTitle,
            changedBy: changedBy, changedByUserId: changedByUserId, changedByRole: changedByRole,
            timestamp: Date(), acknowledgedBy: [])
        if changedByRole == .teamLead {
            directorChangeAlert = alert
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
                if self?.directorChangeAlert?.id == alert.id { withAnimation { self?.directorChangeAlert = nil } }
            }
        }
        alertHistory.append(alert); syncSegments()
        // Save to Firestore — listener will update activeAlert on all devices
        Task { try? await firestore.saveSegmentAlert(alert) }
    }
    
    func acknowledgeAlert(userId: String) {
        guard let alert = activeAlert else { return }
        if !alert.acknowledgedBy.contains(userId) {
            // Firestore listener will update the local state
            Task { try? await firestore.updateAlertAcknowledgment(alertId: alert.id, userId: userId) }
        }
    }
    
    var acknowledgmentCount: Int { activeAlert?.acknowledgedBy.count ?? 0 }
    var totalMembersToAcknowledge: Int { accounts.filter { $0.isApproved }.count - 1 }
    func memberName(for id: String) -> String { accounts.first { $0.id == id }?.displayName ?? "Unknown" }
    func dismissDirectorAlert() { withAnimation { directorChangeAlert = nil } }
}

struct StoredAccount: Identifiable {
    var id: String; var firstName: String; var lastName: String; var email: String
    var phone: String; var pin: String; var role: UserRole; var position: String
    var team: String; var isApproved: Bool; var joinedDate: Date
    var presence: String; var lastSeen: Date?
    var displayName: String { "\(firstName) \(lastName)" }
    
    // True online = presence is "online" AND lastSeen within last 90 seconds
    var isOnline: Bool {
        guard presence == "online", let lastSeen = lastSeen else { return false }
        return Date().timeIntervalSince(lastSeen) < 90
    }
    
    var currentStatus: PresenceStatus {
        if isOnline { return .online }
        if presence == "busy" { return .busy }
        return .offline
    }
    
    func toAppUser() -> AppUser {
        AppUser(id: id, email: email, displayName: displayName, role: role, team: team,
                position: position, status: currentStatus, loginTime: lastSeen,
                phone: phone, joinedDate: joinedDate)
    }
}

extension StoredAccount {
    static let samples: [StoredAccount] = []  // No more hardcoded samples — admin creates fresh
}
