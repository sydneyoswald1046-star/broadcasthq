import Combine
import SwiftUI

struct PendingApprovalView: View {
    @EnvironmentObject var authState: AuthState
    @State private var dotCount: Int = 0
    
    private let timer = Timer.publish(every: 0.6, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Animated icon
            ZStack {
                Circle()
                    .fill(Color.bhqBlue.opacity(0.08))
                    .frame(width: 120, height: 120)
                
                Circle()
                    .fill(Color.bhqBlue.opacity(0.05))
                    .frame(width: 160, height: 160)
                
                Image(systemName: "clock.badge.checkmark")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.bhqBlue)
            }
            
            Text("Waiting for Approval")
                .font(.system(size: 24, weight: .bold))
            
            Text("Your account has been submitted. An admin needs to approve your access before you can log in.")
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            // Animated dots
            Text("Pending" + String(repeating: ".", count: dotCount))
                .font(.system(size: 15, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.bhqBlue)
                .frame(width: 120, alignment: .leading)
                .onReceive(timer) { _ in
                    dotCount = (dotCount % 3) + 1
                }
            
            Spacer()
            
            // User info
            if let user = authState.currentUser {
                VStack(spacing: 6) {
                    Text(user.displayName)
                        .font(.system(size: 16, weight: .semibold))
                    Text(user.email)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.secondary)
                    Text(user.position)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(Color.bhqCard)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }
            
            // Sign out
            Button {
                authState.logout()
            } label: {
                Text("Back to Login")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.bhqTint)
            }
            .padding(.bottom, 40)
        }
        .background(Color.bhqBackground)
    }
}

#Preview {
    let auth = AuthState()
    auth.currentUser = AppUser.samples[1]
    return PendingApprovalView()
        .environmentObject(auth)
        .preferredColorScheme(.dark)
}
