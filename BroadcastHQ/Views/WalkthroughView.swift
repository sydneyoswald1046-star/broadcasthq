import SwiftUI

struct WalkthroughSlide: Identifiable {
    let id = UUID()
    let icon: String
    let color: Color
    let title: String
    let body: String
}

/// First-run, role-aware welcome tour. Full-screen swipeable slides. Skippable.
/// Presented by ContentView for new users and replayable from Help & Support.
struct WalkthroughView: View {
    let role: UserRole
    let onFinish: () -> Void

    @State private var page = 0

    private var isAdmin: Bool { role == .admin || role == .teamLead }

    private var slides: [WalkthroughSlide] {
        isAdmin ? Self.adminSlides : Self.memberSlides
    }

    var body: some View {
        ZStack {
            Color.bhqBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip
                HStack {
                    Spacer()
                    Button("Skip") { onFinish() }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.secondary)
                        .padding(.horizontal, 20).padding(.top, 16)
                }

                TabView(selection: $page) {
                    ForEach(Array(slides.enumerated()), id: \.element.id) { index, slide in
                        slideView(slide).tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Page dots
                HStack(spacing: 8) {
                    ForEach(slides.indices, id: \.self) { i in
                        Circle()
                            .fill(i == page ? Color.bhqTint : Color.secondary.opacity(0.3))
                            .frame(width: i == page ? 9 : 7, height: i == page ? 9 : 7)
                            .animation(.easeOut(duration: 0.2), value: page)
                    }
                }
                .padding(.bottom, 24)

                // Primary action
                Button {
                    if page < slides.count - 1 {
                        withAnimation { page += 1 }
                    } else {
                        onFinish()
                    }
                } label: {
                    Text(page == slides.count - 1 ? "Get Started" : "Next")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.bhqTint)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }

    private func slideView(_ slide: WalkthroughSlide) -> some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                Circle().fill(slide.color.opacity(0.12)).frame(width: 140, height: 140)
                Image(systemName: slide.icon)
                    .font(.system(size: 58, weight: .medium))
                    .foregroundStyle(slide.color)
            }
            VStack(spacing: 14) {
                Text(slide.title)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Color.primary)
                    .multilineTextAlignment(.center)
                Text(slide.body)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 36)
            }
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Slide content

    private static let adminSlides: [WalkthroughSlide] = [
        WalkthroughSlide(icon: "sparkles", color: .bhqTint, title: "Welcome to Valor.Live",
                         body: "Your broadcast command center. Here's a quick tour of what you can do."),
        WalkthroughSlide(icon: "dot.radiowaves.left.and.right", color: .bhqTint, title: "Go Live",
                         body: "Start the broadcast from the Dashboard. Your whole team is notified and the live countdown begins."),
        WalkthroughSlide(icon: "list.bullet.rectangle.fill", color: .bhqBlue, title: "Run the Show",
                         body: "Build your segments in the Rundown, then advance through them live — everyone follows along in real time."),
        WalkthroughSlide(icon: "antenna.radiowaves.left.and.right", color: .bhqPurple, title: "Talk to Your Team",
                         body: "In Comms, pick a team channel and hold the mic to talk. Highlight a team to reach only them. Works over local WiFi."),
        WalkthroughSlide(icon: "tv", color: .bhqGreen, title: "Big-Screen Timer",
                         body: "Connect an Apple TV or HDMI display and send the live countdown to the auditorium screen with one tap."),
        WalkthroughSlide(icon: "person.3.sequence.fill", color: .bhqOrange, title: "Manage the Team",
                         body: "Approve new members and see who's online — grouped by team — at a glance."),
        WalkthroughSlide(icon: "video.badge.waveform", color: .bhqCyan, title: "Live Video",
                         body: "Open the NDI Monitor to view a camera or program feed from your broadcast network."),
    ]

    private static let memberSlides: [WalkthroughSlide] = [
        WalkthroughSlide(icon: "sparkles", color: .bhqTint, title: "Welcome to Valor.Live",
                         body: "Here's how to stay in sync with your team during a broadcast."),
        WalkthroughSlide(icon: "square.grid.2x2.fill", color: .bhqBlue, title: "Your Dashboard",
                         body: "See what's live, what's coming up for you, and your team's status — all in one place."),
        WalkthroughSlide(icon: "antenna.radiowaves.left.and.right", color: .bhqPurple, title: "Push to Talk",
                         body: "Open Comms, choose your team channel, and hold the mic to talk. Works over local WiFi with your team."),
        WalkthroughSlide(icon: "list.bullet.rectangle.fill", color: .bhqGreen, title: "Your Segments & Gear",
                         body: "Your assigned segments and checked-out equipment show right on your dashboard."),
        WalkthroughSlide(icon: "paperplane.fill", color: .bhqTint, title: "Direct Messages",
                         body: "Message teammates one-on-one from the DMs tab when you need a private word."),
        WalkthroughSlide(icon: "video.badge.waveform", color: .bhqCyan, title: "Live Video",
                         body: "Tap the NDI Monitor on your dashboard to watch a live video feed from the network."),
    ]
}

#Preview("Admin") {
    WalkthroughView(role: .admin) {}.preferredColorScheme(.dark)
}
#Preview("Member") {
    WalkthroughView(role: .member) {}.preferredColorScheme(.dark)
}
