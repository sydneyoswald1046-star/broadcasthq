import ActivityKit
import WidgetKit
import SwiftUI

struct ConferenceLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ConferenceActivityAttributes.self) { context in
            // MARK: - Lock Screen Banner
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // MARK: - Expanded Dynamic Island
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(context.attributes.roomName)
                                .font(.system(size: 14, weight: .bold))
                                .lineLimit(1)
                            Text("\(context.state.participantCount) in room")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(formatTime(context.state.elapsedSeconds))
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.green)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 20) {
                        // Mute indicator
                        HStack(spacing: 6) {
                            Image(systemName: context.state.isMuted ? "mic.slash.fill" : "mic.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(context.state.isMuted ? .red : .green)
                            Text(context.state.isMuted ? "Muted" : "Live")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(context.state.isMuted ? .red : .green)
                        }

                        Spacer()

                        // Noise cancellation badge
                        if context.state.isNoiseCancellationOn {
                            HStack(spacing: 4) {
                                Image(systemName: "waveform.badge.minus")
                                    .font(.system(size: 11))
                                Text("NC")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundStyle(.cyan)
                        }

                        Spacer()

                        // Participant avatars
                        HStack(spacing: -6) {
                            ForEach(Array(context.state.participantNames.prefix(3).enumerated()), id: \.offset) { _, name in
                                Text(String(name.prefix(1)))
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 24, height: 24)
                                    .background(Circle().fill(.blue.opacity(0.7)))
                            }
                            if context.state.participantCount > 3 {
                                Text("+\(context.state.participantCount - 3)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 24, height: 24)
                                    .background(Circle().fill(.gray.opacity(0.5)))
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                // MARK: - Compact Leading
                Image(systemName: context.state.isMuted ? "mic.slash.fill" : "waveform")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(context.state.isMuted ? .red : .green)
            } compactTrailing: {
                // MARK: - Compact Trailing
                Text(formatTimeShort(context.state.elapsedSeconds))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.green)
            } minimal: {
                // MARK: - Minimal (when multiple activities)
                Image(systemName: "waveform")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.green)
            }
        }
    }

    // MARK: - Lock Screen View

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<ConferenceActivityAttributes>) -> some View {
        VStack(spacing: 0) {
            // Top bar — room info
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(.green.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.green)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.roomName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(.green)
                                .frame(width: 6, height: 6)
                            Text("LIVE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.green)
                                .tracking(0.5)
                        }
                        Text("·")
                            .foregroundStyle(.gray)
                        Text("\(context.state.participantCount) participant\(context.state.participantCount == 1 ? "" : "s")")
                            .font(.system(size: 11))
                            .foregroundStyle(.gray)
                    }
                }

                Spacer()

                // Timer
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatTime(context.state.elapsedSeconds))
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundStyle(.green)
                    if context.state.isNoiseCancellationOn {
                        HStack(spacing: 3) {
                            Image(systemName: "waveform.badge.minus")
                                .font(.system(size: 9))
                            Text("NC")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundStyle(.cyan)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)

            // Divider
            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(height: 1)

            // Bottom bar — controls + participants
            HStack(spacing: 16) {
                // Mute status
                HStack(spacing: 6) {
                    Image(systemName: context.state.isMuted ? "mic.slash.fill" : "mic.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(context.state.isMuted ? .red : .green)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(context.state.isMuted ? .red.opacity(0.15) : .green.opacity(0.15))
                        )
                    Text(context.state.isMuted ? "Muted" : "Unmuted")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(context.state.isMuted ? .red : .green)
                }

                Spacer()

                // Participant avatars
                HStack(spacing: -8) {
                    ForEach(Array(context.state.participantNames.prefix(4).enumerated()), id: \.offset) { index, name in
                        let initial = String(name.prefix(1)).uppercased()
                        Text(initial)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(avatarColor(index: index))
                                    .overlay(Circle().stroke(.black.opacity(0.3), lineWidth: 1.5))
                            )
                    }
                    if context.state.participantCount > 4 {
                        Text("+\(context.state.participantCount - 4)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(.gray.opacity(0.6))
                                    .overlay(Circle().stroke(.black.opacity(0.3), lineWidth: 1.5))
                            )
                    }
                }

                Spacer()

                // Open app hint
                HStack(spacing: 4) {
                    Text("Open")
                        .font(.system(size: 12, weight: .semibold))
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.blue.opacity(0.15))
                .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(white: 0.1))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    private func formatTimeShort(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private func avatarColor(index: Int) -> Color {
        let colors: [Color] = [.blue, .purple, .orange, .pink, .teal]
        return colors[index % colors.count]
    }
}
