import SwiftUI

// MARK: - Status Indicator (online/busy/offline dot)
struct StatusIndicator: View {
    let status: PresenceStatus
    var size: CGFloat = 8
    
    private var color: Color {
        switch status {
        case .online: return .bhqGreen
        case .busy: return .bhqYellow
        case .offline: return Color(.systemGray3)
        }
    }
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .shadow(color: status == .online ? .bhqGreen.opacity(0.5) : .clear, radius: 3)
    }
}

// MARK: - Stat Card (dashboard number tiles)
struct StatCard: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
            
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.bhqCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Pulse Animation Modifier
struct PulseEffect: ViewModifier {
    @State private var animate = false
    
    func body(content: Content) -> some View {
        content
            .opacity(animate ? 0.3 : 1.0)
            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: animate)
            .onAppear { animate = true }
    }
}

extension View {
    func pulsing() -> some View {
        modifier(PulseEffect())
    }
}

// MARK: - Section Header Style
struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title.uppercased())
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.top, 8)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        HStack {
            StatusIndicator(status: .online)
            StatusIndicator(status: .busy)
            StatusIndicator(status: .offline)
        }
        
        HStack(spacing: 10) {
            StatCard(value: "6/8", label: "Online", color: .bhqGreen)
            StatCard(value: "2", label: "Issues", color: .bhqYellow)
            StatCard(value: "72:00", label: "Time Left", color: .bhqBlue)
        }
        .padding()
    }
    .background(Color.black)
    .preferredColorScheme(.dark)
}

