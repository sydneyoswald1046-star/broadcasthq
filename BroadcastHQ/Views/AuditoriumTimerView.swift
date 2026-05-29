import Combine
import SwiftUI

/// Full-screen layout shown on a connected external display (Apple TV / HDMI).
/// LIVE: ON-AIR badge + segment title + huge remaining countdown + progress.
/// STANDBY: a large wall clock. Reads the same `AuthState` the Dashboard does, with
/// its own 1s tick, so it stays in lockstep with the in-app timer.
struct AuditoriumTimerView: View {
    @EnvironmentObject var authState: AuthState

    @State private var tick: Int = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var liveSegment: Segment? { authState.segments.first { $0.status == .live } }
    private var liveIndex: Int { authState.segments.firstIndex { $0.status == .live } ?? 0 }

    private var elapsed: Int {
        let _ = tick
        guard authState.isBroadcastLive else { return 0 }
        return max(0, Int(Date().timeIntervalSince(authState.segmentStartTime)))
    }
    private var remaining: Int {
        let _ = tick
        return max(0, (liveSegment?.duration ?? 0) - elapsed)
    }
    private var progress: Double {
        let duration = liveSegment?.duration ?? 0
        guard duration > 0 else { return 0 }
        return min(1, Double(elapsed) / Double(duration))
    }
    private var isUrgent: Bool { authState.isBroadcastLive && remaining < 60 }

    private var clockString: String {
        let _ = tick
        let f = DateFormatter()
        f.dateFormat = "h:mm:ss a"
        return f.string(from: Date())
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if authState.isBroadcastLive {
                liveLayout
            } else {
                standbyLayout
            }
        }
        .overlay {
            // Echo the app's live red edge while on air.
            if authState.isBroadcastLive {
                Rectangle()
                    .stroke(Color.bhqTint.opacity(isUrgent ? 0.9 : 0.4), lineWidth: isUrgent ? 10 : 5)
                    .ignoresSafeArea()
                    .pulsing()
                    .allowsHitTesting(false)
            }
        }
        .onReceive(timer) { _ in tick += 1 }
    }

    // MARK: - Live

    private var liveLayout: some View {
        VStack(spacing: 0) {
            HStack(spacing: 18) {
                HStack(spacing: 12) {
                    Circle().fill(Color.bhqTint).frame(width: 22, height: 22).pulsing()
                    Text("ON AIR")
                        .font(.system(size: 34, weight: .heavy)).tracking(4)
                        .foregroundStyle(Color.bhqTint)
                }
                Spacer()
                Text("Segment \(liveIndex + 1) of \(authState.segments.count)")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(.horizontal, 70)
            .padding(.top, 60)

            Text(liveSegment?.title ?? "No active segment")
                .font(.system(size: 64, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.5)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 70)
                .padding(.top, 24)

            Spacer()

            VStack(spacing: 10) {
                Text("REMAINING")
                    .font(.system(size: 30, weight: .semibold)).tracking(6)
                    .foregroundStyle(.white.opacity(0.4))
                Text(Segment.formatTime(remaining))
                    .font(.system(size: 320, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.3)
                    .lineLimit(1)
                    .foregroundStyle(isUrgent ? Color.bhqTint : .white)
            }

            Spacer()

            // Progress
            VStack(spacing: 14) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.12))
                        Capsule().fill(isUrgent ? Color.bhqTint : Color.bhqGreen)
                            .frame(width: geo.size.width * progress)
                            .animation(.linear(duration: 1), value: progress)
                    }
                }
                .frame(height: 16)
                HStack {
                    Text("\(Int(progress * 100))% complete")
                    Spacer()
                    Text(liveSegment?.assignedRole ?? "")
                }
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
            }
            .padding(.horizontal, 70)
            .padding(.bottom, 64)
        }
    }

    // MARK: - Standby

    private var standbyLayout: some View {
        VStack(spacing: 28) {
            HStack(spacing: 14) {
                Circle().fill(Color.bhqGreen).frame(width: 18, height: 18)
                Text("STANDBY")
                    .font(.system(size: 30, weight: .heavy)).tracking(6)
                    .foregroundStyle(Color.bhqGreen)
            }
            Text(clockString)
                .font(.system(size: 200, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.3)
                .lineLimit(1)
                .foregroundStyle(.white)
                .padding(.horizontal, 60)
            if !authState.orgName.isEmpty {
                Text(authState.orgName)
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }
}

#Preview {
    AuditoriumTimerView()
        .environmentObject(AuthState())
        .preferredColorScheme(.dark)
}
