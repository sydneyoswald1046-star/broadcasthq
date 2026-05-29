import Combine
import SwiftUI
import UIKit

/// Drives a connected external display (Apple TV via AirPlay screen-mirroring, or a
/// wired HDMI adapter) with a dedicated big-timer view, independent of the phone UI.
///
/// Uses the external-display **scene** API: the app declares
/// `UIApplicationSupportsMultipleScenes` and AppDelegate hands the external display
/// role to `ExternalDisplaySceneDelegate`, which hosts `ExternalRootView` on that
/// screen. iOS therefore stops mirroring and lets us render our own content instead.
final class ExternalScreenManager: ObservableObject {
    static let shared = ExternalScreenManager()

    /// True while a second screen is attached (its scene has connected).
    @Published private(set) var isScreenConnected: Bool = false
    /// Operator toggle — show the timer on the external screen vs. an idle placeholder.
    @Published var isShowing: Bool = false

    fileprivate weak var authState: AuthState?
    fileprivate weak var settings: AppSettings?

    private init() {}

    /// Inject the data sources the external view renders. Call once from the root view.
    func configure(authState: AuthState, settings: AppSettings) {
        self.authState = authState
        self.settings = settings
    }

    func toggle() { isShowing.toggle() }

    fileprivate func setConnected(_ connected: Bool) {
        isScreenConnected = connected
        if !connected { isShowing = false }
    }
}

// MARK: - External display content

/// Root view shown on the external screen. Idle placeholder until the operator taps
/// the TV button (`isShowing`), then the full auditorium timer.
private struct ExternalRootView: View {
    @ObservedObject private var manager = ExternalScreenManager.shared

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if manager.isShowing, let authState = manager.authState {
                AuditoriumTimerView()
                    .environmentObject(authState)
                    .environmentObject(manager.settings ?? AppSettings())
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "tv").font(.system(size: 64)).foregroundStyle(.white.opacity(0.14))
                    HStack(spacing: 0) {
                        Text("Valor").font(.system(size: 30, weight: .bold)).foregroundStyle(.white.opacity(0.3))
                        Text(".").font(.system(size: 30, weight: .bold)).foregroundStyle(Color(red: 1, green: 0.42, blue: 0.1).opacity(0.5))
                        Text("Live").font(.system(size: 30, weight: .bold)).foregroundStyle(.white.opacity(0.3))
                    }
                }
            }
        }
    }
}

// MARK: - External display scene delegate

/// Owns the window on the external display. The system creates this scene only because
/// the app supports multiple scenes; AppDelegate routes the external role here.
final class ExternalDisplaySceneDelegate: NSObject, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: ExternalRootView())
        window.isHidden = false
        self.window = window
        ExternalScreenManager.shared.setConnected(true)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        window = nil
        ExternalScreenManager.shared.setConnected(false)
    }
}
