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
                NavigationLink { TermsOfServiceView() } label: {
                    Label("Terms of Service", systemImage: "doc.text")
                }
                NavigationLink { PrivacyPolicyView() } label: {
                    Label("Privacy Policy", systemImage: "hand.raised.fill")
                }
                NavigationLink { OpenSourceLicensesView() } label: {
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
        Button {
            if label == "Email Support", let url = URL(string: "mailto:\(value)") {
                UIApplication.shared.open(url)
            } else if label == "Website", let url = URL(string: "https://\(value)") {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.white)
                    .frame(width: 28, height: 28)
                    .background(color)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 1) {
                    Text(label).font(.body).foregroundStyle(Color.primary)
                    Text(value).font(.subheadline).foregroundStyle(Color.secondary)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.secondary.opacity(0.5))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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

// MARK: - Terms of Service

struct TermsOfServiceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Last updated: August 2026")
                    .font(.subheadline).foregroundStyle(Color.secondary)

                legalSection("1. Acceptance of Terms",
                    "By downloading, installing, or using Valor.Live (\"the App\"), you agree to be bound by these Terms of Service. If you do not agree, do not use the App.")

                legalSection("2. Description of Service",
                    "Valor.Live is a broadcast team coordination application that provides push-to-talk communication, equipment tracking, rundown management, and real-time team coordination features for broadcast production teams.")

                legalSection("3. Account & Organization",
                    "Access requires joining an organization via an admin-provided code. You are responsible for keeping your PIN confidential. Each organization's admin manages member access and approval.")

                legalSection("4. Acceptable Use",
                    "You agree not to: (a) use the App for unlawful purposes; (b) transmit harmful, abusive, or offensive content via PTT or messaging; (c) attempt to gain unauthorized access to other organizations; (d) interfere with the App's infrastructure or other users' experience.")

                legalSection("5. Intellectual Property",
                    "All content, design, and technology in the App are owned by Valor.Live and protected by intellectual property laws. You are granted a limited, non-exclusive, non-transferable license to use the App for its intended purpose.")

                legalSection("6. Privacy",
                    "Your use of the App is also governed by our Privacy Policy. By using the App, you consent to the collection and use of information as described therein.")

                legalSection("7. Audio & Communications",
                    "PTT audio is transmitted peer-to-peer over your local network and is not recorded or stored by Valor.Live. Conference room audio uses real-time peer connections. You are responsible for ensuring appropriate consent for any communications.")

                legalSection("8. Termination",
                    "We may suspend or terminate your access if you violate these terms. Organization admins may remove members at their discretion. You may leave an organization at any time through the app settings.")

                legalSection("9. Disclaimer of Warranties",
                    "The App is provided \"as is\" without warranties of any kind, express or implied, including but not limited to merchantability, fitness for a particular purpose, and non-infringement.")

                legalSection("10. Limitation of Liability",
                    "To the maximum extent permitted by law, Valor.Live shall not be liable for any indirect, incidental, special, consequential, or punitive damages arising from your use of the App.")

                legalSection("11. Changes to Terms",
                    "We reserve the right to modify these terms at any time. Continued use of the App after changes constitutes acceptance of the revised terms.")

                legalSection("12. Contact",
                    "Questions about these terms can be sent to support@valor.live.")
            }
            .padding(20)
        }
        .background(Color.bhqBackground)
        .navigationTitle("Terms of Service")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Privacy Policy

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Last updated: August 2026")
                    .font(.subheadline).foregroundStyle(Color.secondary)

                legalSection("Information We Collect",
                    "When you join an organization, we store your name, email address, phone number (optional), role, team assignment, and a 4-digit PIN in your organization's secure database on Google Firebase. We also store device-specific push notification tokens to deliver alerts.")

                legalSection("How We Use Your Information",
                    "Your information is used to: authenticate you within your organization, display your profile to team members, deliver push notifications for alerts and conference rooms, and track equipment assignments.")

                legalSection("Audio Data",
                    "Push-to-talk audio is transmitted in real-time over your local network using peer-to-peer connections (MultipeerConnectivity). Audio is not recorded, stored, or transmitted to any server. Conference room audio uses the same peer-to-peer technology. No audio data leaves your local network.")

                legalSection("Data Storage & Security",
                    "Your organization data is stored on Google Firebase (Firestore) with security rules that restrict access to members of your organization. Profile images are stored in Firebase Storage. All data is encrypted in transit via TLS.")

                legalSection("Third-Party Services",
                    "The App uses: Google Firebase (authentication, database, storage, push notifications), Apple Push Notification Service (APNs), and MultipeerConnectivity (local network communication). Each service has its own privacy policy.")

                legalSection("Data Retention",
                    "Your data is retained as long as your account exists within an organization. When you leave an organization or an admin removes your account, your user data is deleted from that organization. Profile images may be cached locally and are cleared on logout.")

                legalSection("Your Rights",
                    "You can: view and edit your profile information at any time, leave an organization to remove your data, request deletion of your account by contacting your organization admin or support@valor.live.")

                legalSection("Children's Privacy",
                    "The App is not intended for children under 13. We do not knowingly collect personal information from children under 13.")

                legalSection("Changes to This Policy",
                    "We may update this Privacy Policy from time to time. Changes will be reflected in the \"Last updated\" date above.")

                legalSection("Contact Us",
                    "For privacy-related questions, contact us at support@valor.live.")
            }
            .padding(20)
        }
        .background(Color.bhqBackground)
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Open Source Licenses

struct OpenSourceLicensesView: View {
    private let licenses: [(String, String, String)] = [
        ("Firebase iOS SDK", "Google LLC", "Apache License 2.0"),
        ("SwiftUI", "Apple Inc.", "Proprietary — included with iOS SDK"),
        ("MultipeerConnectivity", "Apple Inc.", "Proprietary — included with iOS SDK"),
        ("AVFoundation", "Apple Inc.", "Proprietary — included with iOS SDK"),
    ]

    var body: some View {
        List {
            Section {
                Text("Valor.Live is built with the following open source and system frameworks.")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
                    .listRowBackground(Color.clear)
            }

            Section {
                ForEach(licenses, id: \.0) { name, author, license in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(name)
                            .font(.system(size: 15, weight: .medium))
                        Text(author)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.secondary)
                        Text(license)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.secondary.opacity(0.7))
                    }
                    .padding(.vertical, 4)
                }
            } header: { Text("Frameworks & Libraries") }
        }
        .navigationTitle("Open Source Licenses")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Legal Section Helper

private func legalSection(_ title: String, _ body: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(title)
            .font(.system(size: 15, weight: .semibold))
        Text(body)
            .font(.system(size: 14))
            .foregroundStyle(Color.secondary)
            .lineSpacing(3)
    }
}

#Preview {
    NavigationStack {
        HelpSupportView()
    }
    .preferredColorScheme(.dark)
}

