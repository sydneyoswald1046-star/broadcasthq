# Conference Groups Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add ephemeral conference call voice rooms with WebRTC full mesh audio to BroadcastHQ.

**Architecture:** New `conferenceRooms` Firestore collection under org, with signaling subcollection for WebRTC handshake. `ConferenceAudioService` manages peer connections. UI lives under Comms tab with segmented control. Mutual exclusion with PTT — can't use both simultaneously.

**Tech Stack:** SwiftUI, Firestore (real-time listeners + transactions), WebRTC iOS SDK (Google, via SPM), AVAudioSession

## Global Constraints

- iOS 16+ minimum deployment target
- All Firestore paths scoped under `organizations/{orgCode}/`
- Follow existing patterns: singleton services, `@EnvironmentObject` for AuthState, `ListenerRegistration` for real-time sync
- No CocoaPods — project uses Swift Package Manager exclusively
- Dark mode default — match existing `.bhqBackground`, `.bhqCard`, `.bhqBlue`, `.bhqGreen`, `.bhqTint` color scheme
- WebRTC iOS SDK: `https://github.com/nicklemann/WebRTC.git` (Swift package wrapper for Google's WebRTC)

---

### Task 1: ConferenceRoom Model

**Files:**
- Create: `BroadcastHQ/Models/ConferenceRoom.swift`

**Interfaces:**
- Consumes: Nothing
- Produces: `ConferenceRoom` struct (used by Tasks 2–6), `ConferenceParticipant` struct, `ConferenceAccessMode` enum

- [ ] **Step 1: Create the model file**

```swift
import Foundation

enum ConferenceAccessMode: String, Codable {
    case open
    case invite
}

struct ConferenceParticipant: Identifiable, Codable, Hashable {
    var id: String { userId }
    var userId: String
    var displayName: String
    var joinedAt: Date
    var lastSeen: Date
}

struct ConferenceRoom: Identifiable, Codable {
    var id: String
    var name: String
    var createdBy: String
    var createdByName: String
    var createdAt: Date
    var accessMode: ConferenceAccessMode
    var invitedUserIds: [String]
    var participants: [ConferenceParticipant]
    var isActive: Bool

    var participantCount: Int { participants.count }
    var isEmpty: Bool { participants.isEmpty }

    func isUserInvited(_ userId: String) -> Bool {
        accessMode == .open || createdBy == userId || invitedUserIds.contains(userId)
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild -project BroadcastHQ.xcodeproj -scheme BroadcastHQ -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add BroadcastHQ/Models/ConferenceRoom.swift
git commit -m "feat(conference): add ConferenceRoom model"
```

---

### Task 2: FirestoreService — Conference CRUD + Signaling

**Files:**
- Modify: `BroadcastHQ/Services/FirestoreService.swift`

**Interfaces:**
- Consumes: `ConferenceRoom`, `ConferenceParticipant`, `ConferenceAccessMode` from Task 1
- Produces: `createConferenceRoom(name:createdBy:createdByName:accessMode:invitedUserIds:) async throws -> String` (returns roomId), `endConferenceRoom(roomId:) async throws`, `joinConferenceRoom(roomId:participant:) async throws`, `leaveConferenceRoom(roomId:userId:) async throws`, `updateParticipantHeartbeat(roomId:userId:) async throws`, `listenToConferenceRooms(onChange:) -> ListenerRegistration`, `listenToConferenceRoom(roomId:onChange:) -> ListenerRegistration`, `writeSignalingOffer(roomId:fromUserId:toUserId:sdp:) async throws`, `writeSignalingAnswer(roomId:fromUserId:toUserId:sdp:) async throws`, `addIceCandidate(roomId:fromUserId:toUserId:candidate:) async throws`, `listenToSignaling(roomId:forUserId:onChange:) -> ListenerRegistration`, `cleanupSignaling(roomId:userId:) async throws`

- [ ] **Step 1: Add conference room CRUD methods**

Add at end of `FirestoreService.swift`, before the closing `}`:

```swift
// MARK: - Conference Rooms

func createConferenceRoom(name: String, createdBy: String, createdByName: String, accessMode: ConferenceAccessMode, invitedUserIds: [String]) async throws -> String {
    let roomId = UUID().uuidString
    let data: [String: Any] = [
        "name": name,
        "createdBy": createdBy,
        "createdByName": createdByName,
        "createdAt": Timestamp(date: Date()),
        "accessMode": accessMode.rawValue,
        "invitedUserIds": invitedUserIds,
        "participants": [],
        "isActive": true,
    ]
    try await orgRef().collection("conferenceRooms").document(roomId).setData(data)
    return roomId
}

func endConferenceRoom(roomId: String) async throws {
    try await orgRef().collection("conferenceRooms").document(roomId).updateData([
        "isActive": false,
        "participants": [],
    ])
}

func joinConferenceRoom(roomId: String, participant: ConferenceParticipant) async throws {
    let ref = orgRef().collection("conferenceRooms").document(roomId)
    _ = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Bool, Error>) in
        db.runTransaction({ (txn, errorPointer) -> Any? in
            let snap: DocumentSnapshot
            do { snap = try txn.getDocument(ref) } catch let err as NSError {
                errorPointer?.pointee = err
                return false
            }
            guard let data = snap.data(), data["isActive"] as? Bool == true else { return false }
            var participants = (data["participants"] as? [[String: Any]]) ?? []
            if participants.contains(where: { $0["userId"] as? String == participant.userId }) {
                return true
            }
            participants.append([
                "userId": participant.userId,
                "displayName": participant.displayName,
                "joinedAt": Timestamp(date: participant.joinedAt),
                "lastSeen": Timestamp(date: participant.lastSeen),
            ])
            txn.updateData(["participants": participants], forDocument: ref)
            return true
        }) { (result, error) in
            if let error = error { cont.resume(throwing: error) }
            else { cont.resume(returning: (result as? Bool) ?? false) }
        }
    }
}

func leaveConferenceRoom(roomId: String, userId: String) async throws {
    let ref = orgRef().collection("conferenceRooms").document(roomId)
    _ = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Bool, Error>) in
        db.runTransaction({ (txn, errorPointer) -> Any? in
            let snap: DocumentSnapshot
            do { snap = try txn.getDocument(ref) } catch let err as NSError {
                errorPointer?.pointee = err
                return false
            }
            guard let data = snap.data() else { return false }
            var participants = (data["participants"] as? [[String: Any]]) ?? []
            participants.removeAll { $0["userId"] as? String == userId }
            if participants.isEmpty {
                txn.updateData(["participants": [], "isActive": false], forDocument: ref)
            } else {
                txn.updateData(["participants": participants], forDocument: ref)
            }
            return true
        }) { (result, error) in
            if let error = error { cont.resume(throwing: error) }
            else { cont.resume(returning: (result as? Bool) ?? false) }
        }
    }
}

func updateParticipantHeartbeat(roomId: String, userId: String) async throws {
    let ref = orgRef().collection("conferenceRooms").document(roomId)
    _ = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Bool, Error>) in
        db.runTransaction({ (txn, errorPointer) -> Any? in
            let snap: DocumentSnapshot
            do { snap = try txn.getDocument(ref) } catch let err as NSError {
                errorPointer?.pointee = err
                return false
            }
            guard let data = snap.data() else { return false }
            var participants = (data["participants"] as? [[String: Any]]) ?? []
            if let idx = participants.firstIndex(where: { $0["userId"] as? String == userId }) {
                participants[idx]["lastSeen"] = Timestamp(date: Date())
                txn.updateData(["participants": participants], forDocument: ref)
            }
            return true
        }) { (result, error) in
            if let error = error { cont.resume(throwing: error) }
            else { cont.resume(returning: (result as? Bool) ?? false) }
        }
    }
}

func listenToConferenceRooms(onChange: @escaping ([ConferenceRoom]) -> Void) -> ListenerRegistration {
    return orgRef().collection("conferenceRooms")
        .whereField("isActive", isEqualTo: true)
        .addSnapshotListener { snapshot, error in
            guard let docs = snapshot?.documents, error == nil else { onChange([]); return }
            let rooms = docs.compactMap { doc -> ConferenceRoom? in
                let data = doc.data()
                guard let name = data["name"] as? String,
                      let createdBy = data["createdBy"] as? String,
                      let createdByName = data["createdByName"] as? String,
                      let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
                      let accessModeStr = data["accessMode"] as? String,
                      let accessMode = ConferenceAccessMode(rawValue: accessModeStr),
                      let isActive = data["isActive"] as? Bool
                else { return nil }
                let invitedUserIds = data["invitedUserIds"] as? [String] ?? []
                let participantsRaw = data["participants"] as? [[String: Any]] ?? []
                let participants = participantsRaw.compactMap { p -> ConferenceParticipant? in
                    guard let userId = p["userId"] as? String,
                          let displayName = p["displayName"] as? String,
                          let joinedAt = (p["joinedAt"] as? Timestamp)?.dateValue(),
                          let lastSeen = (p["lastSeen"] as? Timestamp)?.dateValue()
                    else { return nil }
                    return ConferenceParticipant(userId: userId, displayName: displayName, joinedAt: joinedAt, lastSeen: lastSeen)
                }
                return ConferenceRoom(id: doc.documentID, name: name, createdBy: createdBy,
                    createdByName: createdByName, createdAt: createdAt, accessMode: accessMode,
                    invitedUserIds: invitedUserIds, participants: participants, isActive: isActive)
            }
            onChange(rooms)
        }
}

func listenToConferenceRoom(roomId: String, onChange: @escaping (ConferenceRoom?) -> Void) -> ListenerRegistration {
    return orgRef().collection("conferenceRooms").document(roomId)
        .addSnapshotListener { snapshot, error in
            guard let data = snapshot?.data(), error == nil else { onChange(nil); return }
            guard let name = data["name"] as? String,
                  let createdBy = data["createdBy"] as? String,
                  let createdByName = data["createdByName"] as? String,
                  let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
                  let accessModeStr = data["accessMode"] as? String,
                  let accessMode = ConferenceAccessMode(rawValue: accessModeStr),
                  let isActive = data["isActive"] as? Bool
            else { onChange(nil); return }
            let invitedUserIds = data["invitedUserIds"] as? [String] ?? []
            let participantsRaw = data["participants"] as? [[String: Any]] ?? []
            let participants = participantsRaw.compactMap { p -> ConferenceParticipant? in
                guard let userId = p["userId"] as? String,
                      let displayName = p["displayName"] as? String,
                      let joinedAt = (p["joinedAt"] as? Timestamp)?.dateValue(),
                      let lastSeen = (p["lastSeen"] as? Timestamp)?.dateValue()
                else { return nil }
                return ConferenceParticipant(userId: userId, displayName: displayName, joinedAt: joinedAt, lastSeen: lastSeen)
            }
            let room = ConferenceRoom(id: snapshot!.documentID, name: name, createdBy: createdBy,
                createdByName: createdByName, createdAt: createdAt, accessMode: accessMode,
                invitedUserIds: invitedUserIds, participants: participants, isActive: isActive)
            onChange(room)
        }
}
```

- [ ] **Step 2: Add signaling methods**

Add after the conference room methods:

```swift
// MARK: - Conference Signaling

struct SignalingData {
    let fromUserId: String
    let offer: String?
    let answer: String?
    let iceCandidates: [String]
}

func writeSignalingOffer(roomId: String, fromUserId: String, toUserId: String, sdp: String) async throws {
    try await orgRef().collection("conferenceRooms").document(roomId)
        .collection("signaling").document(toUserId)
        .collection("peers").document(fromUserId)
        .setData([
            "offer": sdp,
            "iceCandidates": [String](),
            "updatedAt": Timestamp(date: Date()),
        ], merge: true)
}

func writeSignalingAnswer(roomId: String, fromUserId: String, toUserId: String, sdp: String) async throws {
    try await orgRef().collection("conferenceRooms").document(roomId)
        .collection("signaling").document(toUserId)
        .collection("peers").document(fromUserId)
        .setData([
            "answer": sdp,
            "updatedAt": Timestamp(date: Date()),
        ], merge: true)
}

func addIceCandidate(roomId: String, fromUserId: String, toUserId: String, candidate: String) async throws {
    try await orgRef().collection("conferenceRooms").document(roomId)
        .collection("signaling").document(toUserId)
        .collection("peers").document(fromUserId)
        .updateData([
            "iceCandidates": FieldValue.arrayUnion([candidate]),
            "updatedAt": Timestamp(date: Date()),
        ])
}

func listenToSignaling(roomId: String, forUserId: String, onChange: @escaping (SignalingData) -> Void) -> ListenerRegistration {
    return orgRef().collection("conferenceRooms").document(roomId)
        .collection("signaling").document(forUserId)
        .collection("peers")
        .addSnapshotListener { snapshot, error in
            guard let docs = snapshot?.documents, error == nil else { return }
            for doc in docs {
                let data = doc.data()
                let signal = SignalingData(
                    fromUserId: doc.documentID,
                    offer: data["offer"] as? String,
                    answer: data["answer"] as? String,
                    iceCandidates: data["iceCandidates"] as? [String] ?? []
                )
                onChange(signal)
            }
        }
}

func cleanupSignaling(roomId: String, userId: String) async throws {
    let peerDocs = try await orgRef().collection("conferenceRooms").document(roomId)
        .collection("signaling").document(userId)
        .collection("peers").getDocuments()
    let batch = db.batch()
    for doc in peerDocs.documents { batch.deleteDocument(doc.reference) }
    try await batch.commit()
}
```

- [ ] **Step 3: Verify it compiles**

Run: `xcodebuild -project BroadcastHQ.xcodeproj -scheme BroadcastHQ -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add BroadcastHQ/Services/FirestoreService.swift
git commit -m "feat(conference): add Firestore CRUD and signaling methods"
```

---

### Task 3: AuthState — Conference Room State + Listeners

**Files:**
- Modify: `BroadcastHQ/Services/AuthState.swift`

**Interfaces:**
- Consumes: `ConferenceRoom` from Task 1, Firestore methods from Task 2
- Produces: `@Published var conferenceRooms: [ConferenceRoom]`, `@Published var activeConferenceRoom: ConferenceRoom?`, `func createConferenceRoom(name:accessMode:invitedUserIds:) async throws -> String`, `func joinConference(roomId:)`, `func leaveConference()`, `func endConference()`, `var isInConference: Bool`

- [ ] **Step 1: Add conference published properties**

In `AuthState`, after the PTT properties (around line 69), add:

```swift
// Conference rooms
@Published var conferenceRooms: [ConferenceRoom] = []
@Published var activeConferenceRoom: ConferenceRoom?
@Published var isMuted: Bool = false
private var conferenceRoomsListener: ListenerRegistration?
private var activeRoomListener: ListenerRegistration?
private var conferenceHeartbeatTimer: Timer?

var isInConference: Bool { activeConferenceRoom != nil }
```

- [ ] **Step 2: Add conference room listener to startListeners()**

In `startListeners()`, after the team alert listener block (around line 277), add:

```swift
// Conference rooms listener
conferenceRoomsListener?.remove()
conferenceRoomsListener = firestore.listenToConferenceRooms { [weak self] rooms in
    DispatchQueue.main.async {
        guard let self = self else { return }
        let userId = self.currentUser?.id ?? ""
        self.conferenceRooms = rooms.filter { room in
            room.accessMode == .open || room.createdBy == userId || room.invitedUserIds.contains(userId)
        }
    }
}
```

- [ ] **Step 3: Add conference CRUD methods**

After the PTT section (after `stopAudioService()`), add:

```swift
// MARK: - Conference Rooms

func createConferenceRoom(name: String, accessMode: ConferenceAccessMode, invitedUserIds: [String]) async throws -> String {
    guard let user = currentUser else { throw NSError(domain: "AuthState", code: 0, userInfo: [NSLocalizedDescriptionKey: "Not logged in"]) }
    let roomId = try await firestore.createConferenceRoom(
        name: name, createdBy: user.id, createdByName: user.displayName,
        accessMode: accessMode, invitedUserIds: invitedUserIds
    )
    // Send push to invited users
    if accessMode == .invite {
        for userId in invitedUserIds {
            PushNotificationService.shared.sendConferenceInviteNotification(
                roomName: name, fromName: user.displayName
            )
        }
    }
    return roomId
}

func joinConference(roomId: String) {
    guard let user = currentUser else { return }
    // Leave current conference first
    if isInConference { leaveConference() }
    // Stop PTT if active
    if isLocalTransmitting { stopPTT() }

    let participant = ConferenceParticipant(
        userId: user.id, displayName: user.displayName,
        joinedAt: Date(), lastSeen: Date()
    )
    Task {
        try? await firestore.joinConferenceRoom(roomId: roomId, participant: participant)
    }

    // Listen to room updates
    activeRoomListener?.remove()
    activeRoomListener = firestore.listenToConferenceRoom(roomId: roomId) { [weak self] room in
        DispatchQueue.main.async {
            guard let self = self else { return }
            if let room = room, room.isActive {
                self.activeConferenceRoom = room
            } else {
                self.leaveConference()
            }
        }
    }

    // Start heartbeat
    conferenceHeartbeatTimer?.invalidate()
    conferenceHeartbeatTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
        guard let self = self, let room = self.activeConferenceRoom else { return }
        Task { try? await self.firestore.updateParticipantHeartbeat(roomId: room.id, userId: user.id) }
    }

    isMuted = false
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

func toggleMute() {
    isMuted.toggle()
}
```

- [ ] **Step 4: Update logout() to clean up conference state**

In `logout()`, after `teamAlertListener?.remove()` (around line 639), add:

```swift
conferenceRoomsListener?.remove()
activeRoomListener?.remove()
conferenceHeartbeatTimer?.invalidate()
conferenceHeartbeatTimer = nil
if isInConference { leaveConference() }
```

And in the "Clear data" section of `logout()`, after `messages = []`, add:

```swift
conferenceRooms = []
activeConferenceRoom = nil
isMuted = false
```

- [ ] **Step 5: Update deinit to remove conference listeners**

In `deinit`, add `conferenceRoomsListener?.remove(); activeRoomListener?.remove(); conferenceHeartbeatTimer?.invalidate()`.

- [ ] **Step 6: Verify it compiles**

Run: `xcodebuild -project BroadcastHQ.xcodeproj -scheme BroadcastHQ -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED (will fail on `sendConferenceInviteNotification` — add stub in next step)

- [ ] **Step 7: Add push notification method**

In `PushNotificationService.swift`, add before the closing `}`:

```swift
func sendConferenceInviteNotification(roomName: String, fromName: String) {
    let content = UNMutableNotificationContent()
    content.title = "Conference Invite"
    content.subtitle = fromName
    content.body = "You're invited to \(roomName)"
    content.sound = .default

    let request = UNNotificationRequest(
        identifier: "conference-\(UUID().uuidString)",
        content: content,
        trigger: nil
    )
    UNUserNotificationCenter.current().add(request)
}
```

- [ ] **Step 8: Verify it compiles**

Run: `xcodebuild -project BroadcastHQ.xcodeproj -scheme BroadcastHQ -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 9: Commit**

```bash
git add BroadcastHQ/Services/AuthState.swift BroadcastHQ/Services/PushNotificationService.swift
git commit -m "feat(conference): add conference state management to AuthState"
```

---

### Task 4: Conference List View + Create Room Sheet

**Files:**
- Create: `BroadcastHQ/Views/Comms/ConferenceListView.swift`
- Create: `BroadcastHQ/Views/Comms/CreateConferenceSheet.swift`
- Modify: `BroadcastHQ/Views/Comms/CommsView.swift`

**Interfaces:**
- Consumes: `ConferenceRoom` from Task 1, `AuthState.conferenceRooms`, `AuthState.createConferenceRoom()`, `AuthState.joinConference()` from Task 3
- Produces: `ConferenceListView` (used by CommsView), `CreateConferenceSheet`

- [ ] **Step 1: Create ConferenceListView**

```swift
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
```

- [ ] **Step 2: Create CreateConferenceSheet**

```swift
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
```

- [ ] **Step 3: Modify CommsView to add segmented control**

In `CommsView.swift`, add a new `@State` property near the top:

```swift
@State private var commsTab: CommsTab = .channels
enum CommsTab: String, CaseIterable {
    case channels = "Channels"
    case conference = "Conference"
}
```

Replace the `body` with:

```swift
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
```

- [ ] **Step 4: Verify it compiles**

Run: `xcodebuild -project BroadcastHQ.xcodeproj -scheme BroadcastHQ -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add BroadcastHQ/Views/Comms/ConferenceListView.swift BroadcastHQ/Views/Comms/CreateConferenceSheet.swift BroadcastHQ/Views/Comms/CommsView.swift
git commit -m "feat(conference): add conference list view, create sheet, and comms tab"
```

---

### Task 5: Conference Room View (Active Call UI)

**Files:**
- Create: `BroadcastHQ/Views/Comms/ConferenceRoomView.swift`
- Create: `BroadcastHQ/Views/Components/SpeakingIndicator.swift`

**Interfaces:**
- Consumes: `ConferenceRoom`, `ConferenceParticipant` from Task 1, `AuthState.activeConferenceRoom`, `AuthState.leaveConference()`, `AuthState.endConference()`, `AuthState.toggleMute()`, `AuthState.isMuted` from Task 3
- Produces: `ConferenceRoomView` (used by ConferenceListView navigation), `SpeakingIndicator`

- [ ] **Step 1: Create SpeakingIndicator**

```swift
import SwiftUI

struct SpeakingIndicator: View {
    let isSpeaking: Bool
    let size: CGFloat
    var color: Color = .bhqGreen

    @State private var pulse = false

    var body: some View {
        Circle()
            .stroke(color.opacity(isSpeaking ? 0.8 : 0), lineWidth: isSpeaking ? 3 : 0)
            .frame(width: size + 8, height: size + 8)
            .scaleEffect(pulse && isSpeaking ? 1.15 : 1.0)
            .animation(
                isSpeaking ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true) : .default,
                value: pulse
            )
            .onChange(of: isSpeaking) { _, speaking in
                pulse = speaking
            }
            .onAppear { pulse = isSpeaking }
    }
}
```

- [ ] **Step 2: Create ConferenceRoomView**

```swift
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
            }
            Text(room.name)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.primary)
            Text("\(room.participantCount) participant\(room.participantCount == 1 ? "" : "s")")
                .font(.system(size: 13))
                .foregroundStyle(Color.secondary)
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
```

- [ ] **Step 3: Show ConferenceRoomView when in active conference**

In `ConferenceListView.swift`, wrap the existing body in a check — if user is in an active conference, show the room view:

Update the `body` to:

```swift
var body: some View {
    VStack(spacing: 0) {
        if authState.activeConferenceRoom != nil {
            ConferenceRoomView()
        } else if authState.conferenceRooms.isEmpty {
            emptyState
        } else {
            roomList
        }
    }
    .sheet(isPresented: $showCreateSheet) {
        CreateConferenceSheet()
    }
    .overlay(alignment: .bottomTrailing) {
        if canCreate && authState.activeConferenceRoom == nil {
            createButton
        }
    }
}
```

- [ ] **Step 4: Add .pulsing() modifier if not already available**

Check if `.pulsing()` exists (used in ContentView already). If it's a custom modifier, it should already be in the project. If it causes a compile error, add this extension:

```swift
extension View {
    func pulsing() -> some View {
        modifier(PulsingModifier())
    }
}
struct PulsingModifier: ViewModifier {
    @State private var isPulsing = false
    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 0.3 : 1.0)
            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
    }
}
```

- [ ] **Step 5: Verify it compiles**

Run: `xcodebuild -project BroadcastHQ.xcodeproj -scheme BroadcastHQ -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add BroadcastHQ/Views/Comms/ConferenceRoomView.swift BroadcastHQ/Views/Components/SpeakingIndicator.swift BroadcastHQ/Views/Comms/ConferenceListView.swift
git commit -m "feat(conference): add active room view with participant grid and controls"
```

---

### Task 6: WebRTC Audio Service

**Files:**
- Create: `BroadcastHQ/Services/ConferenceAudioService.swift`
- Modify: `BroadcastHQ/Services/AuthState.swift` (wire up audio service)

**Interfaces:**
- Consumes: Firestore signaling methods from Task 2, `AuthState.activeConferenceRoom` from Task 3, `AuthState.isMuted` from Task 3
- Produces: `ConferenceAudioService` class with `func joinRoom(roomId:userId:existingParticipantIds:)`, `func leaveRoom()`, `func setMuted(_:)`, `var speakingPeers: Set<String>` (for future speaking indicators)

**Note:** This task requires the WebRTC SPM package. The implementer must first add `https://github.com/nicklemann/WebRTC.git` to the Xcode project's Swift Package dependencies before writing the service. If that specific package is unavailable or doesn't compile, use `https://github.com/nicklemann/WebRTC` or `https://github.com/nicklemann/WebRTC.git` — Google's WebRTC iOS framework wrapped for SPM. If none work, use the `WebRTC` pod or manually add the `WebRTC.xcframework`.

- [ ] **Step 1: Add WebRTC SPM dependency**

In Xcode: File → Add Package Dependencies → paste `https://github.com/nicklemann/WebRTC.git` → Add Package. Select `WebRTC` library, add to BroadcastHQ target.

Alternatively from command line, you'll need to edit the `.xcodeproj` — this is easier done in Xcode GUI.

- [ ] **Step 2: Create ConferenceAudioService**

```swift
import AVFoundation
import Combine
import WebRTC
import FirebaseFirestore

class ConferenceAudioService: ObservableObject {
    static let shared = ConferenceAudioService()

    @Published var speakingPeers: Set<String> = []
    private var peerConnections: [String: RTCPeerConnection] = [:]
    private var localAudioTrack: RTCAudioTrack?
    private var factory: RTCPeerConnectionFactory?
    private var signalingListener: ListenerRegistration?

    private var roomId: String?
    private var userId: String?
    private let firestore = FirestoreService.shared

    private static let iceServers = [
        RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"]),
        RTCIceServer(urlStrings: ["stun:stun1.l.google.com:19302"]),
    ]

    func joinRoom(roomId: String, userId: String, existingParticipantIds: [String]) {
        self.roomId = roomId
        self.userId = userId

        setupFactory()
        setupLocalAudio()
        listenForSignaling()

        for peerId in existingParticipantIds where peerId != userId {
            if userId < peerId {
                createOffer(for: peerId)
            }
        }
    }

    func leaveRoom() {
        signalingListener?.remove()
        signalingListener = nil

        for (_, pc) in peerConnections {
            pc.close()
        }
        peerConnections.removeAll()
        localAudioTrack = nil
        speakingPeers.removeAll()

        if let factory = factory {
            RTCAudioSession.sharedInstance().lockForConfiguration()
            let config = RTCAudioSessionConfiguration()
            config.category = AVAudioSession.Category.ambient.rawValue
            config.mode = AVAudioSession.Mode.default.rawValue
            try? RTCAudioSession.sharedInstance().setConfiguration(config)
            RTCAudioSession.sharedInstance().unlockForConfiguration()
        }

        roomId = nil
        userId = nil
    }

    func setMuted(_ muted: Bool) {
        localAudioTrack?.isEnabled = !muted
    }

    func handleNewParticipant(_ peerId: String) {
        guard let userId = userId, peerId != userId else { return }
        if peerConnections[peerId] != nil { return }
        if userId < peerId {
            createOffer(for: peerId)
        }
    }

    func handleParticipantLeft(_ peerId: String) {
        peerConnections[peerId]?.close()
        peerConnections.removeValue(forKey: peerId)
        DispatchQueue.main.async {
            self.speakingPeers.remove(peerId)
        }
    }

    // MARK: - Private

    private func setupFactory() {
        RTCInitializeSSL()
        let encoderFactory = RTCDefaultVideoEncoderFactory()
        let decoderFactory = RTCDefaultVideoDecoderFactory()
        factory = RTCPeerConnectionFactory(encoderFactory: encoderFactory, decoderFactory: decoderFactory)
    }

    private func setupLocalAudio() {
        RTCAudioSession.sharedInstance().lockForConfiguration()
        let config = RTCAudioSessionConfiguration.webRTC()
        config.category = AVAudioSession.Category.playAndRecord.rawValue
        config.categoryOptions = [.defaultToSpeaker, .allowBluetooth]
        config.mode = AVAudioSession.Mode.voiceChat.rawValue
        try? RTCAudioSession.sharedInstance().setConfiguration(config)
        RTCAudioSession.sharedInstance().isAudioEnabled = true
        RTCAudioSession.sharedInstance().unlockForConfiguration()

        guard let factory = factory else { return }
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        let audioSource = factory.audioSource(with: constraints)
        localAudioTrack = factory.audioTrack(with: audioSource, trackId: "audio0")
        localAudioTrack?.isEnabled = true
    }

    private func createPeerConnection(for peerId: String) -> RTCPeerConnection? {
        guard let factory = factory else { return nil }
        let config = RTCConfiguration()
        config.iceServers = ConferenceAudioService.iceServers
        config.sdpSemantics = .unifiedPlan

        let constraints = RTCMediaConstraints(
            mandatoryConstraints: ["OfferToReceiveAudio": "true"],
            optionalConstraints: nil
        )
        let delegate = PeerConnectionDelegate(peerId: peerId, service: self)
        guard let pc = factory.peerConnection(with: config, constraints: constraints, delegate: delegate) else { return nil }

        if let track = localAudioTrack {
            pc.add(track, streamIds: ["stream0"])
        }

        peerConnections[peerId] = pc
        return pc
    }

    private func createOffer(for peerId: String) {
        guard let pc = createPeerConnection(for: peerId) else { return }
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: ["OfferToReceiveAudio": "true"],
            optionalConstraints: nil
        )
        pc.offer(for: constraints) { [weak self] sdp, error in
            guard let self = self, let sdp = sdp, error == nil else { return }
            pc.setLocalDescription(sdp) { error in
                guard error == nil, let roomId = self.roomId, let userId = self.userId else { return }
                Task {
                    try? await self.firestore.writeSignalingOffer(
                        roomId: roomId, fromUserId: userId, toUserId: peerId, sdp: sdp.sdp
                    )
                }
            }
        }
    }

    private func handleOffer(from peerId: String, sdp: String) {
        let pc = peerConnections[peerId] ?? createPeerConnection(for: peerId)
        guard let pc = pc else { return }

        let remoteSdp = RTCSessionDescription(type: .offer, sdp: sdp)
        pc.setRemoteDescription(remoteSdp) { [weak self] error in
            guard let self = self, error == nil else { return }
            let constraints = RTCMediaConstraints(
                mandatoryConstraints: ["OfferToReceiveAudio": "true"],
                optionalConstraints: nil
            )
            pc.answer(for: constraints) { answer, error in
                guard let answer = answer, error == nil else { return }
                pc.setLocalDescription(answer) { error in
                    guard error == nil, let roomId = self.roomId, let userId = self.userId else { return }
                    Task {
                        try? await self.firestore.writeSignalingAnswer(
                            roomId: roomId, fromUserId: userId, toUserId: peerId, sdp: answer.sdp
                        )
                    }
                }
            }
        }
    }

    private func handleAnswer(from peerId: String, sdp: String) {
        guard let pc = peerConnections[peerId] else { return }
        let remoteSdp = RTCSessionDescription(type: .answer, sdp: sdp)
        pc.setRemoteDescription(remoteSdp) { _ in }
    }

    private func handleIceCandidate(from peerId: String, candidateString: String) {
        guard let pc = peerConnections[peerId] else { return }
        let parts = candidateString.split(separator: "|")
        guard parts.count == 3,
              let sdpMLineIndex = Int32(parts[1])
        else { return }
        let candidate = RTCIceCandidate(sdp: String(parts[0]), sdpMLineIndex: sdpMLineIndex, sdpMid: String(parts[2]))
        pc.add(candidate) { _ in }
    }

    private func listenForSignaling() {
        guard let roomId = roomId, let userId = userId else { return }
        signalingListener?.remove()
        signalingListener = firestore.listenToSignaling(roomId: roomId, forUserId: userId) { [weak self] signal in
            guard let self = self else { return }
            if let offer = signal.offer, self.peerConnections[signal.fromUserId] == nil {
                self.handleOffer(from: signal.fromUserId, sdp: offer)
            }
            if let answer = signal.answer {
                self.handleAnswer(from: signal.fromUserId, sdp: answer)
            }
            for candidate in signal.iceCandidates {
                self.handleIceCandidate(from: signal.fromUserId, candidateString: candidate)
            }
        }
    }

    // MARK: - ICE Candidate Delegate Callback

    fileprivate func didGenerateIceCandidate(_ candidate: RTCIceCandidate, for peerId: String) {
        guard let roomId = roomId, let userId = userId else { return }
        let candidateString = "\(candidate.sdp)|\(candidate.sdpMLineIndex)|\(candidate.sdpMid ?? "")"
        Task {
            try? await firestore.addIceCandidate(
                roomId: roomId, fromUserId: userId, toUserId: peerId, candidate: candidateString
            )
        }
    }

    fileprivate func didChangeConnectionState(_ state: RTCIceConnectionState, for peerId: String) {
        if state == .disconnected || state == .failed || state == .closed {
            handleParticipantLeft(peerId)
        }
    }
}

// MARK: - Peer Connection Delegate

private class PeerConnectionDelegate: NSObject, RTCPeerConnectionDelegate {
    let peerId: String
    weak var service: ConferenceAudioService?

    init(peerId: String, service: ConferenceAudioService) {
        self.peerId = peerId
        self.service = service
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        service?.didChangeConnectionState(newState, for: peerId)
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}

    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        service?.didGenerateIceCandidate(candidate, for: peerId)
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}

    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}
}
```

- [ ] **Step 3: Wire ConferenceAudioService into AuthState**

In `AuthState.swift`, at the top of `joinConference(roomId:)`, after setting `isMuted = false`, add:

```swift
// Audio service will be started once room listener fires with participant list
```

Then in the `activeRoomListener` callback inside `joinConference`, after `self.activeConferenceRoom = room`, add:

```swift
let participantIds = room.participants.map { $0.userId }
if ConferenceAudioService.shared.roomId == nil {
    ConferenceAudioService.shared.joinRoom(
        roomId: room.id, userId: user.id,
        existingParticipantIds: participantIds
    )
}
```

Wait — `roomId` is private. Instead, add a helper. In `ConferenceAudioService`, add a public computed property:

```swift
var isInRoom: Bool { roomId != nil }
```

Then the check becomes:

```swift
if !ConferenceAudioService.shared.isInRoom {
    ConferenceAudioService.shared.joinRoom(
        roomId: room.id, userId: user.id,
        existingParticipantIds: participantIds
    )
}
```

In `leaveConference()`, before the Task block, add:

```swift
ConferenceAudioService.shared.leaveRoom()
```

In `toggleMute()`, add:

```swift
func toggleMute() {
    isMuted.toggle()
    ConferenceAudioService.shared.setMuted(isMuted)
}
```

- [ ] **Step 4: Handle participant changes in AuthState**

In the `activeRoomListener` callback, after updating `self.activeConferenceRoom`, add participant change detection:

```swift
// Track participant joins/leaves for WebRTC
let oldIds = Set(self.activeConferenceRoom?.participants.map { $0.userId } ?? [])
let newIds = Set(room.participants.map { $0.userId })
for joined in newIds.subtracting(oldIds) {
    ConferenceAudioService.shared.handleNewParticipant(joined)
}
for left in oldIds.subtracting(newIds) {
    ConferenceAudioService.shared.handleParticipantLeft(left)
}
```

Note: This must be placed **before** updating `self.activeConferenceRoom = room` so `oldIds` reads the previous state.

- [ ] **Step 5: Verify it compiles**

Run: `xcodebuild -project BroadcastHQ.xcodeproj -scheme BroadcastHQ -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED (after WebRTC package resolves)

- [ ] **Step 6: Commit**

```bash
git add BroadcastHQ/Services/ConferenceAudioService.swift BroadcastHQ/Services/AuthState.swift
git commit -m "feat(conference): add WebRTC audio service with full mesh peer connections"
```

---

### Task 7: PTT Mutual Exclusion + Background Handling

**Files:**
- Modify: `BroadcastHQ/Services/AuthState.swift`
- Modify: `BroadcastHQ/Views/Comms/CommsView.swift`
- Modify: `BroadcastHQ/App/BroadcastHQApp.swift` (background handling)

**Interfaces:**
- Consumes: `AuthState.isInConference` from Task 3
- Produces: PTT disabled when in conference, auto-leave on background timeout

- [ ] **Step 1: Disable PTT when in conference**

In `AuthState.swift`, modify `startPTT(channel:)` — add at the very beginning:

```swift
guard !isInConference else { return }
```

- [ ] **Step 2: Show "In Conference" status in CommsView**

In `CommsView.swift`, in the `statusBanner` ViewBuilder, add a new condition at the top (before the PTT transmitting check):

```swift
if authState.isInConference {
    HStack(spacing: 8) {
        Image(systemName: "phone.fill")
            .font(.system(size: 12))
            .foregroundStyle(Color.bhqGreen)
        Text("In conference — \(authState.activeConferenceRoom?.name ?? "")")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.white)
        Spacer()
        Text("PTT disabled")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(Color.secondary)
            .tracking(0.5)
    }
    .padding(.horizontal, 16)
    .frame(maxWidth: .infinity)
    .padding(.vertical, 8)
    .background(Color.bhqGreen.opacity(0.15))
} else
```

Make sure the `else` connects to the existing `if isPTTActive...` chain.

- [ ] **Step 3: Disable PTT button visually when in conference**

In `CommsView.swift`, in `inputBar`, wrap the PTT circle's gesture with a check:

Add `.disabled(authState.isInConference)` to the PTT Circle and change fill to gray when in conference:

```swift
.fill(authState.isInConference ? Color.secondary.opacity(0.2) : authState.isChannelBusy ? Color.secondary.opacity(0.2) : (isPTTActive || volumePTT.isTransmitting) ? Color.bhqTint : Color.bhqGreen)
```

And update the icon:

```swift
Image(systemName: authState.isInConference ? "phone.fill" : authState.isChannelBusy ? "mic.slash.fill" : ...)
```

- [ ] **Step 4: Add background auto-leave**

In `BroadcastHQApp.swift` (or wherever `scenePhase` is observed), find the `.onChange(of: scenePhase)` handler. Add conference auto-leave logic:

In `AuthState.swift`, add a new property and method:

```swift
private var backgroundConferenceTimer: Timer?

func handleBackgrounded() {
    guard isInConference else { return }
    backgroundConferenceTimer?.invalidate()
    backgroundConferenceTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: false) { [weak self] _ in
        DispatchQueue.main.async {
            self?.leaveConference()
        }
    }
}

func handleForegrounded() {
    backgroundConferenceTimer?.invalidate()
    backgroundConferenceTimer = nil
}
```

The app's scenePhase handler should call these when `isInBackground` changes.

- [ ] **Step 5: Verify it compiles**

Run: `xcodebuild -project BroadcastHQ.xcodeproj -scheme BroadcastHQ -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add BroadcastHQ/Services/AuthState.swift BroadcastHQ/Views/Comms/CommsView.swift
git commit -m "feat(conference): add PTT mutual exclusion and background auto-leave"
```

---

### Task 8: Stale Participant Cleanup

**Files:**
- Modify: `BroadcastHQ/Services/AuthState.swift`

**Interfaces:**
- Consumes: `ConferenceRoom.participants`, `ConferenceParticipant.lastSeen` from Task 1, `AuthState.activeConferenceRoom` from Task 3
- Produces: Automatic pruning of stale participants (lastSeen > 90s)

- [ ] **Step 1: Add stale participant check to heartbeat**

In `AuthState.swift`, modify the `conferenceHeartbeatTimer` setup in `joinConference()`. Replace the existing timer block:

```swift
conferenceHeartbeatTimer?.invalidate()
conferenceHeartbeatTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
    guard let self = self, let room = self.activeConferenceRoom, let user = self.currentUser else { return }
    // Update own heartbeat
    Task { try? await self.firestore.updateParticipantHeartbeat(roomId: room.id, userId: user.id) }
    // Prune stale participants (> 90s since lastSeen)
    let staleThreshold = Date().addingTimeInterval(-90)
    let staleIds = room.participants.filter { $0.lastSeen < staleThreshold && $0.userId != user.id }.map { $0.userId }
    for staleId in staleIds {
        Task { try? await self.firestore.leaveConferenceRoom(roomId: room.id, userId: staleId) }
        ConferenceAudioService.shared.handleParticipantLeft(staleId)
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild -project BroadcastHQ.xcodeproj -scheme BroadcastHQ -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add BroadcastHQ/Services/AuthState.swift
git commit -m "feat(conference): add stale participant pruning on heartbeat"
```
