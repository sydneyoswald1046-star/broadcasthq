import SwiftUI

struct SpeakingIndicator: View {
    let isSpeaking: Bool
    let size: CGFloat
    var color: Color = .bhqGreen

    @State private var pulse = false

    var body: some View {
        Circle()
            .stroke(color.opacity(isSpeaking ? 0.8 : 0), lineWidth: isSpeaking ? 3 : 0)
            .frame(width: size + 8, height: size + 8)
            .scaleEffect(pulse && isSpeaking ? 1.15 : 1.0)
            .animation(
                isSpeaking ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true) : .default,
                value: pulse
            )
            .onChange(of: isSpeaking) { _, speaking in
                pulse = speaking
            }
            .onAppear { pulse = isSpeaking }
    }
}
