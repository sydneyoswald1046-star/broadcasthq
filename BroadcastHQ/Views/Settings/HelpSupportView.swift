import SwiftUI

struct HelpSupportView: View {
    @State private var expandedFAQ: String?
    
    private let faqs: [(String, String, String)] = [
        ("faq1", "How do I use Push-to-Talk?", "Hold the PTT button (microphone icon) to transmit your voice to your team. Release to stop. PTT works on the Dashboard, Comms tab, and in Direct Messages."),
        ("faq2", "How do I check out equipment?", "Go to the Gear tab, find the item you need, and tap 'Check Out'. The item will be assigned to your profile. Check it back in when you're done."),
        ("faq3", "What does each role see?", "Admins and Directors have full control — Go Live, segment management, team approvals. Team Members see a simplified dashboard focused on their assignments and team."),
        ("faq4", "How do segments work?", "Segments are the building blocks of a broadcast rundown. Each segment has a title, duration, assigned role, and notes. Admins can add, edit, delete, and reorder segments."),
        ("faq5", "How do I change my PIN?", "Go to your Profile → Information → tap your current PIN to change it. Your PIN must be 4 digits and unique."),
        ("faq6", "What do the border colors mean?", "Red pulsing border = broadcast is LIVE. Green pulsing border = standby mode, waiting to go live."),
        ("faq7", "Can I message someone directly?", "Yes! Tap any team member's profile, then tap the 'Message' button to open a private Direct Message with built-in PTT."),
    ]
    
    var body: some View {
        List {
            // About section
            Section {
                VStack(spacing: 12) {
                    valorLogo
                        .frame(width: 60, height: 60)
                    
                    HStack(spacing: 0) {
                        Text("Valor").font(.system(size: 22, weight: .bold)).foregroundStyle(Color.white)
                        Text(".").font(.system(size: 22, weight: .bold)).foregroundStyle(Color(red: 1, green: 0.42, blue: 0.1))
                        Text("Live").font(.system(size: 22, weight: .bold)).foregroundStyle(Color.white)
                    }
                    
                    Text("Never miss a moment")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.secondary)
                        .tracking(2)
                    
                    Text("Version 1.0.0 · Build 1")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondary.opacity(0.5))
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            
            // Getting Started
            Section {
                Button {
                    NotificationCenter.default.post(name: .replayWalkthrough, object: nil)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.white)
                            .frame(width: 28, height: 28)
                            .background(Color.bhqTint)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        Text("Replay App Walkthrough").font(.body).foregroundStyle(Color.primary)
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.secondary.opacity(0.5))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } header: { Text("Getting Started") }

            // FAQ
            Section {
                ForEach(faqs, id: \.0) { faq in
                    faqRow(id: faq.0, question: faq.1, answer: faq.2)
                }
            } header: { Text("Frequently Asked Questions") }
            
            // Contact
            Section {
                contactRow(icon: "envelope.fill", label: "Email Support", value: "support@valor.live", color: Color.bhqBlue)
                contactRow(icon: "globe", label: "Website", value: "valor.live", color: Color.bhqGreen)
                contactRow(icon: "bubble.left.fill", label: "In-App Feedback", value: "Send feedback", color: Color.bhqPurple)
            } header: { Text("Contact Us") }
            
            // Legal
            Section {
                NavigationLink { Text("Terms of Service").padding() } label: {
                    Label("Terms of Service", systemImage: "doc.text")
                }
                NavigationLink { Text("Privacy Policy").padding() } label: {
                    Label("Privacy Policy", systemImage: "hand.raised.fill")
                }
                NavigationLink { Text("Open Source Licenses").padding() } label: {
                    Label("Open Source Licenses", systemImage: "chevron.left.forwardslash.chevron.right")
                }
            } header: { Text("Legal") }
        }
        .navigationTitle("Help & Support")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - FAQ Row
    private func faqRow(id: String, question: String, answer: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                expandedFAQ = expandedFAQ == id ? nil : id
            }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(question)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.primary)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: expandedFAQ == id ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.secondary)
                }
                
                if expandedFAQ == id {
                    Text(answer)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.secondary)
                        .lineSpacing(3)
                        .padding(.top, 10)
                        .transition(.opacity)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Contact Row
    private func contactRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.white)
                .frame(width: 28, height: 28)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.body)
                Text(value).font(.subheadline).foregroundStyle(Color.secondary)
            }
        }
    }
    
    // MARK: - Logo
    private var valorLogo: some View {
        Canvas { context, size in
            let sx = size.width / 110
            let sy = size.height / 110
            
            var outerLeft = Path()
            outerLeft.addArc(center: CGPoint(x: 55*sx, y: 84*sy), radius: 48*sx, startAngle: .degrees(202), endAngle: .degrees(270), clockwise: false)
            context.stroke(outerLeft, with: .color(Color(red: 1, green: 0.39, blue: 0.12).opacity(0.9)), lineWidth: 2.8*sx)
            
            let dotRect = CGRect(x: (55-6.5)*sx, y: (84-6.5)*sy, width: 13*sx, height: 13*sy)
            context.fill(Path(ellipseIn: dotRect), with: .color(Color(red: 1, green: 0.39, blue: 0.12)))
            
            let innerDot = CGRect(x: (55-3.4)*sx, y: (84-3.4)*sy, width: 6.8*sx, height: 6.8*sy)
            context.fill(Path(ellipseIn: innerDot), with: .color(Color(red: 1, green: 0.7, blue: 0.4).opacity(0.72)))
            
            var vPath = Path()
            vPath.move(to: CGPoint(x: 30*sx, y: 38*sy))
            vPath.addLine(to: CGPoint(x: 55*sx, y: 72*sy))
            vPath.addLine(to: CGPoint(x: 80*sx, y: 38*sy))
            context.stroke(vPath, with: .color(Color.white.opacity(0.97)), style: StrokeStyle(lineWidth: 8*sx, lineCap: .round, lineJoin: .round))
        }
    }
}

#Preview {
    NavigationStack {
        HelpSupportView()
    }
    .preferredColorScheme(.dark)
}

