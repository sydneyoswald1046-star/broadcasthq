import SwiftUI

struct SegmentChangeOverlay: View {
    @EnvironmentObject var authState: AuthState
    let alert: SegmentChangeAlert
    let onDismiss: () -> Void
    
    @State private var flashOpacity: Double = 0.3
    @State private var dragOffset: CGFloat = 0
    
    private let swipeThreshold: CGFloat = 200
    
    var body: some View {
        ZStack {
            // Red flashing background
            Color.bhqTint.opacity(flashOpacity)
                .ignoresSafeArea()
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                        flashOpacity = 0.15
                    }
                    triggerVibration()
                }
            
            VStack(spacing: 20) {
                Spacer()
                
                // Alert icon
                Image(systemName: alertIcon)
                    .font(.system(size: 56))
                    .foregroundStyle(Color.bhqTint)
                
                Text(alert.type.rawValue.uppercased())
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.bhqTint)
                    .tracking(2)
                
                Text(alert.segmentTitle)
                    .font(.system(size: 24, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                Text("by \(alert.changedBy)")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.secondary)
                
                Text(timeString)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.secondary.opacity(0.6))
                
                Spacer()
                
                // Swipe to acknowledge
                swipeButton
                    .padding(.bottom, 60)
            }
        }
    }
    
    private var alertIcon: String {
        switch alert.type {
        case .added: return "plus.rectangle.fill"
        case .edited: return "pencil.circle.fill"
        case .removed: return "trash.circle.fill"
        }
    }
    
    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm:ss a"
        return f.string(from: alert.timestamp)
    }
    
    // MARK: - Swipe Button
    private var swipeButton: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30)
                .fill(Color.bhqCard.opacity(0.9))
                .frame(height: 60)
                .overlay(RoundedRectangle(cornerRadius: 30).stroke(Color.bhqTint.opacity(0.3), lineWidth: 1))
            
            Text("Swipe to acknowledge →")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.secondary)
            
            HStack {
                Circle()
                    .fill(Color.bhqTint)
                    .frame(width: 50, height: 50)
                    .overlay {
                        Image(systemName: "chevron.right.2")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.white)
                    }
                    .shadow(color: Color.bhqTint.opacity(0.4), radius: 6)
                    .offset(x: dragOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if value.translation.width > 0 {
                                    dragOffset = min(value.translation.width, swipeThreshold)
                                }
                            }
                            .onEnded { _ in
                                if dragOffset >= swipeThreshold * 0.8 {
                                    // Send acknowledgment
                                    if let userId = authState.currentUser?.id {
                                        authState.acknowledgeAlert(userId: userId)
                                    }
                                    // Success haptic
                                    let generator = UINotificationFeedbackGenerator()
                                    generator.notificationOccurred(.success)
                                    // Dismiss immediately for this user
                                    withAnimation(.easeOut(duration: 0.3)) {
                                        onDismiss()
                                    }
                                } else {
                                    withAnimation(.spring(response: 0.3)) {
                                        dragOffset = 0
                                    }
                                }
                            }
                    )
                Spacer()
            }
            .padding(.horizontal, 5)
        }
        .frame(height: 60)
        .padding(.horizontal, 32)
    }
    
    private func triggerVibration() {
        let heavy = UIImpactFeedbackGenerator(style: .heavy)
        heavy.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { heavy.impactOccurred() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { heavy.impactOccurred() }
    }
}

// MARK: - Admin Acknowledgment Tracker (shown to admin/director who made the change)
struct AcknowledgmentTracker: View {
    @EnvironmentObject var authState: AuthState
    let alert: SegmentChangeAlert
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
            
            VStack(spacing: 12) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(alert.type.rawValue)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.bhqTint)
                            .tracking(0.5)
                        Text(alert.segmentTitle)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Spacer()
                    Button { onDismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Color.secondary.opacity(0.5))
                    }
                }
                
                // Counter
                HStack(spacing: 6) {
                    Text("\(authState.acknowledgmentCount)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Color.bhqGreen)
                    Text("/")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.secondary)
                    Text("\(authState.totalMembersToAcknowledge)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Color.secondary)
                    Text("acknowledged")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.secondary)
                        .padding(.leading, 4)
                }
                
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(Color(.systemFill))
                        RoundedRectangle(cornerRadius: 3).fill(Color.bhqGreen)
                            .frame(width: authState.totalMembersToAcknowledge > 0
                                   ? geo.size.width * CGFloat(authState.acknowledgmentCount) / CGFloat(authState.totalMembersToAcknowledge)
                                   : 0)
                            .animation(.easeInOut(duration: 0.3), value: authState.acknowledgmentCount)
                    }
                }
                .frame(height: 6)
                
                // Who responded
                if authState.acknowledgmentCount > 0 {
                    VStack(spacing: 6) {
                        ForEach(alert.acknowledgedBy, id: \.self) { userId in
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.bhqGreen)
                                Text(authState.memberName(for: userId))
                                    .font(.system(size: 14))
                                Spacer()
                                Text("Noted")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.bhqGreen)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
                
                // Who hasn't responded
                let pending = authState.accounts.filter { $0.isApproved && $0.id != alert.changedByUserId && !alert.acknowledgedBy.contains($0.id) }
                if !pending.isEmpty {
                    VStack(spacing: 6) {
                        Text("WAITING FOR")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.secondary.opacity(0.5))
                            .tracking(0.5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        ForEach(pending) { account in
                            HStack(spacing: 8) {
                                Image(systemName: "clock")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.bhqYellow)
                                Text(account.displayName)
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.secondary)
                                Spacer()
                                Text("Pending")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.bhqYellow)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(16)
        }
        .background(Color.bhqCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.bhqTint.opacity(0.2), lineWidth: 0.5))
        .shadow(color: Color.black.opacity(0.3), radius: 10)
        .padding(.horizontal, 16)
    }
}

// MARK: - Director Change Banner (green glow notification for admin)
struct DirectorChangeBanner: View {
    let alert: SegmentChangeAlert
    let onDismiss: () -> Void
    
    var body: some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: "person.badge.shield.checkmark")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.bhqGreen)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(alert.changedBy) made a change")
                        .font(.system(size: 14, weight: .semibold))
                    Text("\(alert.type.rawValue): \(alert.segmentTitle)")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.secondary)
                }
                
                Spacer()
                
                Button { onDismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.secondary.opacity(0.5))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.bhqGreen.opacity(0.12))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.bhqGreen.opacity(0.3), lineWidth: 0.5))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

#Preview {
    let auth = AuthState()
    auth.currentUser = AppUser.samples[1] // member
    auth.activeAlert = SegmentChangeAlert(
        id: "test", type: .edited, segmentTitle: "Worship Set",
        changedBy: "Marcus Johnson", changedByUserId: "1", changedByRole: .admin,
        timestamp: Date(), acknowledgedBy: []
    )
    return SegmentChangeOverlay(alert: auth.activeAlert!, onDismiss: {})
        .environmentObject(auth)
        .preferredColorScheme(.dark)
}
