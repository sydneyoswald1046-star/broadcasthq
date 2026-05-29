import SwiftUI
import FirebaseCore
import FirebaseMessaging
import GoogleSignIn

@main
struct BroadcastHQApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var showSplash = true
    @StateObject private var authState = AuthState()
    @StateObject private var appSettings = AppSettings()
    @StateObject private var volumePTT = VolumeButtonPTT()
    @AppStorage("permissionsShown") private var permissionsShown = false
    @State private var permissionsComplete = false
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        FirebaseApp.configure()
        FCMService.shared.setup()
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                Group {
                    switch authState.status {
                    case .loggedOut:
                        PinLoginView()
                    case .pendingApproval:
                        PendingApprovalView()
                    case .loggedIn:
                        if !permissionsShown && !permissionsComplete {
                            PermissionsView(onComplete: {
                                permissionsComplete = true
                            })
                        } else {
                            ContentView()
                        }
                    }
                }
                .environmentObject(authState)
                .environmentObject(appSettings)
                .environmentObject(volumePTT)
                .dynamicTypeSize(appSettings.dynamicTypeSize)
                .opacity(showSplash ? 0 : 1)
                
                if showSplash {
                    SplashView {
                        withAnimation(.easeInOut(duration: 0.8)) {
                            showSplash = false
                        }
                    }
                    .transition(.opacity)
                }
            }
            .preferredColorScheme(.dark)
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard authState.status == .loggedIn else { return }
                switch newPhase {
                case .active:
                    authState.isInBackground = false
                    authState.goOnline()
                    PushNotificationService.shared.clearBadge()
                case .background, .inactive:
                    authState.isInBackground = true
                    authState.goOffline()
                @unknown default:
                    break
                }
            }
            .onAppear {
                // Handle push notification taps
                NotificationCenter.default.addObserver(forName: .pushNotificationTapped, object: nil, queue: .main) { notif in
                    guard let userInfo = notif.userInfo, authState.status == .loggedIn else { return }
                    let type = userInfo["type"] as? String ?? ""
                    switch type {
                    case "dm":
                        if let senderId = userInfo["senderId"] as? String {
                            authState.deepLinkDMUserId = senderId
                            authState.deepLinkTab = "dms"
                        }
                    case "message", "team_message":
                        authState.deepLinkTab = "comms"
                    case "broadcast_live", "broadcast_ended", "segment_change":
                        authState.deepLinkTab = "dashboard"
                    case "team_alert":
                        // Stay on current tab — banner will show
                        break
                    case "member_request":
                        // Could deep link to admin panel
                        break
                    default: break
                    }
                }
            }
        }
    }
}
