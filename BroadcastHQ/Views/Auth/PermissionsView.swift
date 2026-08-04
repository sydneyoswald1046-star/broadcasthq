import SwiftUI
import AVFoundation
import UserNotifications

struct PermissionsView: View {
    @EnvironmentObject var authState: AuthState
    var onComplete: () -> Void = {}
    @State private var micGranted: Bool = false
    @State private var networkTriggered: Bool = false
    @State private var pushGranted: Bool = false
    @State private var currentStep: Int = 0
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            Image(systemName: stepIcon)
                .font(.system(size: 56))
                .foregroundStyle(stepColor)
                .padding(.bottom, 20)
            
            Text(stepTitle)
                .font(.system(size: 24, weight: .bold))
                .padding(.bottom, 8)
            
            Text(stepSubtitle)
                .font(.system(size: 15))
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
            
            // Progress dots
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .fill(i <= currentStep ? Color(red: 1, green: 0.42, blue: 0.1) : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.bottom, 24)
            
            Button { handleAction() } label: {
                HStack(spacing: 10) {
                    Image(systemName: buttonIcon)
                        .font(.system(size: 16))
                    Text(buttonLabel)
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color(red: 1, green: 0.42, blue: 0.1), Color(red: 0.9, green: 0.3, blue: 0.08)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            
            if currentStep < 3 {
                Button { skipAll() } label: {
                    Text("Skip for now")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.secondary)
                }
                .padding(.top, 12)
            }
            
            Spacer().frame(height: 50)
        }
        .background(Color.bhqBackground)
        .onAppear {
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async { micGranted = granted; if granted { currentStep = 1 } }
            }
        }
    }
    
    // MARK: - Step Content
    
    private var stepIcon: String {
        switch currentStep {
        case 0: return "mic.circle.fill"
        case 1: return "wifi.circle.fill"
        case 2: return "bell.circle.fill"
        default: return "checkmark.circle.fill"
        }
    }
    
    private var stepColor: Color {
        switch currentStep {
        case 0: return Color.bhqGreen
        case 1: return Color.bhqBlue
        case 2: return Color.bhqYellow
        default: return Color.bhqGreen
        }
    }
    
    private var stepTitle: String {
        switch currentStep {
        case 0: return "Microphone Access"
        case 1: return "Local Network"
        case 2: return "Push Notifications"
        default: return "You're All Set!"
        }
    }
    
    private var stepSubtitle: String {
        switch currentStep {
        case 0: return "Valor.Live needs your microphone for push-to-talk communication with your broadcast team."
        case 1: return "Allow local network access so your device can connect with nearby team members for real-time walkie-talkie audio.\n\nMake sure all team devices are on the same WiFi."
        case 2: return "Stay in the loop even when the app is closed. Get notified when your team sends alerts, messages, or goes live."
        default: return "Your permissions are set up. You're ready to broadcast with your team."
        }
    }
    
    private var buttonLabel: String {
        switch currentStep {
        case 0: return "Allow Microphone"
        case 1: return "Enable Local Network"
        case 2: return "Enable Notifications"
        default: return "Let's Go"
        }
    }
    
    private var buttonIcon: String {
        switch currentStep {
        case 0: return "mic.fill"
        case 1: return "antenna.radiowaves.left.and.right"
        case 2: return "bell.fill"
        default: return "arrow.right"
        }
    }
    
    // MARK: - Actions
    
    private func handleAction() {
        switch currentStep {
        case 0: requestMicrophone()
        case 1: triggerLocalNetwork()
        case 2: requestPushNotifications()
        default: completeSetup()
        }
    }
    
    private func requestMicrophone() {
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                micGranted = granted
                withAnimation(.easeInOut(duration: 0.3)) { currentStep = 1 }
            }
        }
    }
    
    private func triggerLocalNetwork() {
        let service = PTTAudioService.shared
        if let user = authState.currentUser {
            service.start(orgCode: authState.orgCode, userName: user.displayName, userId: user.id, userTeam: user.team, userRole: user.role.rawValue)
        }
        networkTriggered = true
        withAnimation(.easeInOut(duration: 0.3)) { currentStep = 2 }
    }
    
    private func requestPushNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                pushGranted = granted
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                withAnimation(.easeInOut(duration: 0.3)) { currentStep = 3 }
            }
        }
    }
    
    private func skipAll() {
        completeSetup()
    }
    
    private func completeSetup() {
        UserDefaults.standard.set(true, forKey: "permissionsShown")
        authState.startAudioService()
        onComplete()
    }
}

#Preview {
    PermissionsView()
        .environmentObject(AuthState())
        .preferredColorScheme(.dark)
}
