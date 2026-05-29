import SwiftUI

struct TeamAlertBanner: View {
    let alert: TeamAlert
    let onDismiss: () -> Void
    
    @State private var pulseOpacity: Double = 1.0
    @State private var slideIn: Bool = false
    @State private var timeRemaining: Double = 7.0
    
    var body: some View {
        VStack(spacing: 0) {
            // Red pulsing bar
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "megaphone.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.white)
                    
                    Text("TEAM ALERT")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.white)
                        .tracking(1.5)
                    
                    Spacer()
                    
                    Text(alert.senderName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.7))
                }
                
                Text(alert.message)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.white)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(3)
                
                // Progress bar showing time remaining
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.3))
                        .frame(width: geo.size.width * (timeRemaining / 7.0), height: 3)
                        .animation(.linear(duration: 0.1), value: timeRemaining)
                }
                .frame(height: 3)
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .padding(.top, 50) // Safe area top
            .background(
                Color.red
                    .opacity(pulseOpacity)
            )
            .overlay(
                Color.red.opacity(0.3)
                    .opacity(pulseOpacity < 0.85 ? 1 : 0)
            )
        }
        .frame(maxWidth: .infinity)
        .offset(y: slideIn ? 0 : -200)
        .onAppear {
            // Slide in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                slideIn = true
            }
            
            // Vibrate
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            
            // Double vibrate for urgency
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
            
            // Pulse animation
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                pulseOpacity = 0.75
            }
            
            // Countdown timer
            startCountdown()
        }
        .onTapGesture {
            dismiss()
        }
    }
    
    private func startCountdown() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            timeRemaining -= 0.1
            if timeRemaining <= 0 {
                timer.invalidate()
                dismiss()
            }
        }
    }
    
    private func dismiss() {
        withAnimation(.easeIn(duration: 0.3)) {
            slideIn = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}

// MARK: - Data Model

struct TeamAlert: Identifiable, Codable {
    var id: String
    var message: String
    var senderName: String
    var senderId: String
    var senderRole: String
    var timestamp: Date
    var read: Bool
    
    var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: timestamp)
    }
    
    var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, h:mm a"
        return f.string(from: timestamp)
    }
}

// MARK: - Alert Input Sheet

struct SendAlertSheet: View {
    @EnvironmentObject var authState: AuthState
    @Binding var isPresented: Bool
    @State private var message: String = ""
    @State private var isSending: Bool = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Preview
                VStack(spacing: 8) {
                    Image(systemName: "megaphone.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.bhqTint)
                    
                    Text("Send Team Alert")
                        .font(.system(size: 20, weight: .bold))
                    
                    Text("This will appear as a red banner on every team member's screen with vibration.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.top, 20)
                
                // Message input
                VStack(alignment: .leading, spacing: 6) {
                    Text("MESSAGE")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.secondary)
                        .tracking(0.5)
                    
                    TextEditor(text: $message)
                        .font(.system(size: 16))
                        .focused($isFocused)
                        .frame(minHeight: 80, maxHeight: 120)
                        .padding(12)
                        .background(Color(.systemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            Group {
                                if message.isEmpty {
                                    Text("e.g. Get to your positions, we go live in 2 minutes")
                                        .font(.system(size: 16))
                                        .foregroundStyle(Color.secondary.opacity(0.4))
                                        .padding(.leading, 16)
                                        .padding(.top, 20)
                                        .allowsHitTesting(false)
                                }
                            }, alignment: .topLeading
                        )
                }
                .padding(.horizontal, 20)
                
                // Character count
                Text("\(message.count)/200")
                    .font(.system(size: 11))
                    .foregroundStyle(message.count > 200 ? Color.red : Color.secondary)
                
                Spacer()
                
                // Send button
                Button {
                    sendAlert()
                } label: {
                    HStack(spacing: 8) {
                        if isSending {
                            ProgressView().tint(Color.white)
                        }
                        Image(systemName: "megaphone.fill")
                            .font(.system(size: 14))
                        Text(isSending ? "Sending..." : "Send Alert to Entire Team")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        message.isEmpty || message.count > 200
                            ? Color.secondary.opacity(0.3)
                            : Color.bhqTint
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(message.isEmpty || message.count > 200 || isSending)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(Color.bhqBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { isPresented = false }
                        .foregroundStyle(Color.secondary)
                }
            }
            .onAppear { isFocused = true }
        }
    }
    
    private func sendAlert() {
        guard let user = authState.currentUser else { return }
        let trimmed = message.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        isSending = true
        
        let alert = TeamAlert(
            id: UUID().uuidString,
            message: trimmed,
            senderName: user.displayName,
            senderId: user.id,
            senderRole: user.role.rawValue,
            timestamp: Date(),
            read: false
        )
        
        Task {
            try? await FirestoreService.shared.sendTeamAlert(alert)
            await MainActor.run {
                isSending = false
                isPresented = false
            }
        }
    }
}
