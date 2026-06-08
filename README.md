# BroadcastHQ — Live Broadcast Team Coordination for iOS

A native SwiftUI iOS app for real-time broadcast team management. Push-to-talk communications, NDI video monitoring, rundown control, equipment tracking, and multi-screen support — built for live production environments.

Branded as **Valor.Live** in production.

---

## Features

| Feature | Description |
|---------|-------------|
| **Live Dashboard** | Start/end broadcasts, manage segments, real-time timer with progress bar |
| **Push-to-Talk** | Zero-internet PTT via MultipeerConnectivity (Bluetooth/WiFi mesh), volume button and Bluetooth controller triggers |
| **NDI Monitoring** | Discover and preview NDI video sources on the local network in real time |
| **Rundown Management** | Create, edit, reorder broadcast segments with save/load templates |
| **Team Comms** | Team channels (5 broadcast teams) + direct messages with unread badges |
| **Equipment Tracking** | Gear checkout system with condition tracking (good/damaged/missing) |
| **External Display** | AirPlay/HDMI output — auditorium timer on Apple TV via Scene API (not mirroring) |
| **Role-Based Access** | Admin, Team Lead, and Member roles with approval flow for new signups |
| **Event Scheduler** | Schedule upcoming broadcasts with reminders |
| **Push Notifications** | FCM-powered alerts for broadcast events, segment changes, DMs, equipment issues |
| **Onboarding** | Role-aware walkthrough with gesture tutorials, replayable from settings |
| **Customizable UI** | Text scaling, 5 accent colors, compact mode, live border indicator, animation toggles |

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| **Framework** | SwiftUI, iOS 16+ |
| **Language** | Swift 5 |
| **State** | Combine (ObservableObject, @Published) + Firestore real-time listeners |
| **Auth** | Firebase Auth — PIN login, Apple Sign-In, Google Sign-In |
| **Database** | Cloud Firestore (users, segments, equipment, messages, PTT state, rundowns, orgs) |
| **Push** | Firebase Cloud Messaging (FCM) + APNs |
| **Storage** | Firebase Storage (profile images) |
| **Audio** | AVAudioEngine for PTT capture/playback, MultipeerConnectivity for local mesh |
| **Video** | NDI Advanced SDK via C bridging header, Bonjour discovery |
| **Hardware** | GameController framework for Bluetooth PTT triggers |
| **Display** | UIWindowScene API for non-mirrored external display output |

---

## Architecture

```
BroadcastHQ/
├── App/                  # @main entry, Firebase init, scene setup
├── Models/               # AppUser, Team, Segment, Equipment, ChatMessage
├── Services/             # AuthState, FirestoreService, FCMService,
│                         # PTTAudioService, NDIService, ExternalScreenManager,
│                         # VolumeButtonPTT, ProfileImageService, AppSettings
├── Views/
│   ├── Dashboard/        # Admin + Member dashboards
│   ├── Rundown/          # Segment CRUD, save/load templates
│   ├── Comms/            # Team channels + direct messages
│   ├── Equipment/        # Gear checkout and condition tracking
│   ├── NDI/              # Video source picker + live preview
│   ├── Admin/            # Admin panel, member approval
│   ├── Auth/             # PIN, signup, permissions, pending approval
│   ├── Profile/          # User profile + member detail
│   ├── Settings/         # Appearance, notifications, help
│   └── Components/       # Shared UI (avatars, banners, overlays)
└── Extensions/           # Color+Theme design system
```

**Pattern:** MVVM with Combine. `AuthState` is the central observable holding broadcast status, segments, users, messages, and Firestore listeners. Services are injected via `@EnvironmentObject`.

---

## Broadcast Teams

| Team | Role |
|------|------|
| Photography | Camera operators and media capture |
| Broadcast | Switching, streaming, and technical direction |
| Projection | Slides, lyrics, and screen content |
| Choir | Worship team and audio coordination |
| Lights | Lighting design and operation |

---

## PTT System

Push-to-talk operates over **MultipeerConnectivity** — no internet required. Audio routes through AVAudioEngine with low-latency capture and playback.

**Triggers:**
- Long-press UI button
- iOS volume buttons
- Bluetooth controller (A button via GameController framework)

**Safety:** Organization-isolated channels, encryption, team targeting, queue-based transmit lock to prevent simultaneous broadcast.

---

## Getting Started

### Prerequisites

- Xcode 15+
- iOS 16+ device (NDI requires physical device)
- Firebase project (Auth, Firestore, FCM, Storage)
- NDI Advanced SDK (optional — for live video monitoring)

### Setup

```bash
# Clone the repo
git clone https://github.com/sydneyoswald1046-star/broadcasthq.git

# Open in Xcode
open BroadcastHQ.xcodeproj

# Add your Firebase config
# Place GoogleService-Info.plist in BroadcastHQ/Resources/

# Build and run on device
```

### NDI Setup (Optional)

The NDI Advanced SDK binary (`libndi_advanced_ios.a`, 256MB) is excluded from the repo. To enable live NDI monitoring:

1. Obtain the NDI Advanced SDK from [NDI.tv](https://ndi.tv/sdk/)
2. Place `libndi_advanced_ios.a` in the project root
3. Build on a physical device (NDI is not available in Simulator — a stub is provided)

---

## Screens

| Screen | Access | Purpose |
|--------|--------|---------|
| `DashboardView` | Admin | Broadcast control, segment timer, team alerts, quick actions |
| `MemberDashboardView` | Member | Broadcast status, current segment, team updates |
| `RundownView` | Admin/Lead | Segment CRUD, save/load templates, total runtime |
| `CommsView` | All | Team channels with PTT + text messaging |
| `DMView` | All | Private 1-to-1 direct messages |
| `NDIMonitorView` | All | Live NDI video source preview |
| `EquipmentView` | All | Gear checkout, condition tracking |
| `AdminPanelView` | Admin | Member management, pending approvals |
| `EventSchedulerView` | Admin/Lead | Schedule upcoming broadcasts |
| `AuditoriumTimerView` | External | Large-format timer on Apple TV / external display |
| `SettingsView` | All | Appearance, notifications, accessibility |

---

## Multi-Organization Support

BroadcastHQ supports multiple organizations with isolated data. Admins create organizations, generate join codes, and approve new members. All Firestore data is scoped per-organization.

---

## License

This project is source-available for portfolio purposes. All rights reserved.
