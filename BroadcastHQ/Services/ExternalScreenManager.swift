import Combine
import SwiftUI
import UIKit

/// Drives a connected external display (Apple TV via AirPlay screen-mirroring, or a
/// wired HDMI adapter) with a dedicated big-timer view, independent of what the phone
/// shows. Purely additive: when no screen is connected nothing happens.
///
/// Uses the legacy `UIScreen`/`UIWindow` external-display path. It is deprecated in
/// favour of scene-based external displays but remains functional through current iOS,
/// and avoids invasive `Info.plist` scene-manifest changes to this SwiftUI-lifecycle app.
final class ExternalScreenManager: ObservableObject {
    static let shared = ExternalScreenManager()

    /// True when a second screen (Apple TV / HDMI) is currently attached.
    @Published private(set) var isScreenConnected: Bool = false
    /// True when the auditorium timer is actively mirrored to that screen.
    @Published private(set) var isShowing: Bool = false

    private var externalWindow: UIWindow?
    private weak var authState: AuthState?
    private weak var settings: AppSettings?

    private init() {
        refreshConnection()
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged),
                                               name: UIScreen.didConnectNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged),
                                               name: UIScreen.didDisconnectNotification, object: nil)
    }

    /// Inject the data sources the external view renders. Call once from the root view.
    func configure(authState: AuthState, settings: AppSettings) {
        self.authState = authState
        self.settings = settings
    }

    func toggle() {
        isShowing ? detach() : attach()
    }

    // MARK: - Screen lifecycle

    @objc private func screensChanged() {
        DispatchQueue.main.async {
            self.refreshConnection()
            if !self.isScreenConnected { self.detach() }
        }
    }

    private func refreshConnection() {
        isScreenConnected = externalScreen() != nil
    }

    private func externalScreen() -> UIScreen? {
        UIScreen.screens.first { $0 !== UIScreen.main }
    }

    // MARK: - Attach / detach the big-timer window

    func attach() {
        guard externalWindow == nil,
              let screen = externalScreen(),
              let authState = authState else { return }

        let root = AuditoriumTimerView()
            .environmentObject(authState)
            .environmentObject(settings ?? AppSettings())

        let window = UIWindow(frame: screen.bounds)
        window.screen = screen
        window.rootViewController = UIHostingController(rootView: root)
        window.isHidden = false
        externalWindow = window
        isShowing = true
    }

    func detach() {
        externalWindow?.isHidden = true
        externalWindow = nil
        isShowing = false
    }
}
