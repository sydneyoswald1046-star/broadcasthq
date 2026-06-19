# Conference Groups — Design Spec

**Date:** 2026-06-19
**Status:** Approved

## Overview

Add ephemeral conference call-style voice rooms to BroadcastHQ. Users join/leave rooms with simultaneous duplex audio (not PTT). Rooms are created by admins and team leads, accessible to org members based on open or invite-only access mode.

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Voice model | Simultaneous (duplex) | Real conference call feel, not walkie-talkie |
| Room creation | Admins + team leads | Members join only |
| Persistence | Ephemeral | Room dies when last person leaves or creator ends it |
| Access | Open or invite-only (per room) | Creator picks at creation time |
| Max participants | Unlimited | Broadcast-wide calls possible; mesh degrades gracefully past ~6-8 |
| Audio transport | WebRTC full mesh | No media server needed, free, low latency |
| Text chat in rooms | No | Voice only — text stays in existing channels/DMs |
| Recording | No | Simplicity + privacy |

## Data Model (Firestore)

```
organizations/{orgCode}/conferenceRooms/{roomId}
├── name: String                    // "Camera Ops Sync"
├── createdBy: String               // userId
├── createdByName: String
├── createdAt: Timestamp
├── accessMode: "open" | "invite"
├── invitedUserIds: [String]        // only when accessMode = "invite"
├── participants: [                 // live roster
│   { userId, displayName, joinedAt, lastSeen }
│ ]
├── isActive: Bool                  // false = room ended
│
└── subcollection: signaling/{recipientUserId}
    └── {senderUserId}
        ├── offer: String (SDP)
        ├── answer: String (SDP)
        ├── iceCandidates: [String]
        ├── updatedAt: Timestamp
```

**Key points:**
- `participants` array on room doc — single listener gives full roster
- Signaling subcollection for WebRTC handshake per peer pair
- `isActive: false` when creator ends or last participant leaves
- `invitedUserIds` enforced client-side + Firestore security rules

## WebRTC Service

New `ConferenceAudioService` class manages peer connections for a single room.

### Responsibilities

- Create `RTCPeerConnection` per remote participant
- Capture local mic via `RTCAudioSession`
- Exchange SDP offer/answer + ICE candidates through Firestore signaling subcollection
- Mute/unmute local mic
- Detect peer disconnect via ICE connection state
- Tear down all connections on leave

### Join/Leave Flow

```
User joins room
  → Add self to participants array (Firestore transaction)
  → Listen to participants array for changes
  → For each existing participant:
      Create RTCPeerConnection
      Create offer → write to signaling/{theirId}/{myId}
  → Listen to signaling/{myId}/ for incoming offers/answers
  → When new participant joins:
      They send offer, you send answer
  → When participant leaves:
      Close that RTCPeerConnection, clean up signaling doc

User leaves room
  → Remove self from participants array
  → Close all RTCPeerConnections
  → Delete own signaling docs
  → If participants empty → set isActive = false
```

### Conflict Resolution

When two peers join simultaneously, both might create offers. Lower userId alphabetically is always the "offerer" — other side waits for offer then answers. Prevents duplicate negotiation.

### Dependency

Google `WebRTC` iOS framework (via SPM or CocoaPods).

## UI & Navigation

### Placement

Under existing **Comms** tab. Segmented control or toggle: `Channels | Conference`.

### Conference List View

- Active rooms with name, participant count, access badge (open/invite)
- "Create Room" button — visible for admins + team leads only
- Tap room → join + navigate to room view

### Create Room Sheet

- Room name (text field)
- Access mode toggle (Open / Invite-only)
- If invite-only: member picker (multi-select from org users)
- "Start Room" button

### Active Room View

- Room name header
- Participant grid — avatars + names, speaking indicator (audio level ring around avatar)
- Mute/unmute button (prominent, center)
- Leave button (red, bottom)
- End Room button (creator only — ends for everyone)
- Participant count badge

### Notifications

- Invite-only: push notification to invited users "You're invited to {roomName}"
- Open rooms: no push, visible in list only
- Creator ends room: all participants get toast "Room ended"

### AuthState Integration

- `@Published var conferenceRooms: [ConferenceRoom] = []`
- `@Published var activeConferenceRoom: ConferenceRoom?`
- New listener: `listenToConferenceRooms()`

## Audio & Edge Cases

### Audio Session

- Join room: configure `AVAudioSession` for `.playAndRecord` with `.voiceChat` mode
- Leave room: restore previous audio session config
- Mutual exclusion with PTT: can't PTT while in conference. Disable PTT button, show "In conference" status.
- If user is PTT transmitting when joining → stop PTT first

### Speaking Indicator

- Local: monitor audio levels via `RTCAudioTrack`, animate avatar ring above threshold
- Remote: `RTCPeerConnection.getStats()` exposes audio levels per peer

### Edge Cases

| Scenario | Behavior |
|----------|----------|
| App backgrounded | iOS kills mic after ~30s. Show banner "Return to app to stay in room." Auto-leave after 60s background. |
| Network drop | ICE reconnection handles brief drops. Auto-leave after 15s disconnect. Remove from participants. |
| Creator leaves without ending | Room stays alive. Dies when last person leaves. |
| Stale participants | Heartbeat: update `lastSeen` in participants every 30s. Prune >90s stale (matches existing presence pattern). |
| Concurrent join race | Firestore transaction on participants array prevents duplicates. |
| Multiple rooms | One room at a time. Joining new room → auto-leave current. |

## Security & Permissions

### Firestore Rules

| Action | Allowed |
|--------|---------|
| Create room | `role == "admin" \|\| role == "team_lead"` |
| Join open room | Any org member |
| Join invite-only room | `userId in invitedUserIds` OR creator |
| Modify participants | Only adding/removing own userId |
| Delete signaling docs | Only own docs |
| Set `isActive: false` | Participants empty OR user is creator |
| All reads | Scoped to own org |

### App-Side Enforcement

- Create button hidden for members
- Invite-only rooms hidden from list for non-invited members
- Join blocked client-side + rules double-check

## New Files (Estimated)

| File | Purpose |
|------|---------|
| `Models/ConferenceRoom.swift` | Room model + participant struct |
| `Services/ConferenceAudioService.swift` | WebRTC peer connection management |
| `Views/Comms/ConferenceListView.swift` | Room list under Comms tab |
| `Views/Comms/CreateConferenceSheet.swift` | Room creation form |
| `Views/Comms/ConferenceRoomView.swift` | Active room UI with participant grid |
| `Views/Components/SpeakingIndicator.swift` | Audio level ring animation |

## Modified Files (Estimated)

| File | Change |
|------|--------|
| `Services/AuthState.swift` | Add conference room state + listener |
| `Services/FirestoreService.swift` | Add conference CRUD + signaling methods |
| `Views/Comms/CommsView.swift` | Add segmented control for Channels/Conference |
| `Services/FCMService.swift` | Add conference invite notification type |
