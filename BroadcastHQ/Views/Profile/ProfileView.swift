import SwiftUI
import PhotosUI
import AVFoundation

struct ProfileView: View {
    @Binding var currentUser: AppUser
    @EnvironmentObject var authState: AuthState
    @EnvironmentObject var settings: AppSettings
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var profileImage: UIImage?
    @State private var isUploading: Bool = false
    @State private var showEditName: Bool = false
    @State private var showEditPhone: Bool = false
    @State private var showSignOutConfirm: Bool = false
    @State private var showLeaveTeamConfirm: Bool = false
    @State private var editNameText: String = ""
    @State private var editPhoneText: String = ""
    @State private var showNotificationSettings: Bool = false
    @State private var showAppearanceSettings: Bool = false
    @State private var showHelpSupport: Bool = false
    @State private var codeCopied: Bool = false
    @State private var audioOutputName: String = "iPhone Speaker"
    @State private var audioOutputIcon: String = "speaker.wave.2.fill"
    @State private var audioOutputIsBluetooth: Bool = false
    
    private var team: Team? { Team.find(currentUser.team) }
    private var theme: RoleTheme { RoleTheme.forUser(currentUser) }
    private var isAdmin: Bool { currentUser.role == .admin || currentUser.role == .teamLead }
    private var myEquipment: [Equipment] { authState.equipment.filter { $0.assignedTo == currentUser.displayName } }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                profileHeader
                teamCodeSection
                statusSelector
                infoSection
                equipmentSection
                audioOutputSection
                accountSection
            }.padding(.vertical)
        }
        .background(Color.bhqBackground)
        .navigationTitle("Profile").navigationBarTitleDisplayMode(.large)
        .alert("Edit Name", isPresented: $showEditName) {
            TextField("Full Name", text: $editNameText)
            Button("Save") {
                if !editNameText.isEmpty {
                    currentUser.displayName = editNameText
                    let parts = editNameText.split(separator: " ", maxSplits: 1)
                    let first = String(parts.first ?? "")
                    let last = parts.count > 1 ? String(parts[1]) : ""
                    Task { try? await FirestoreService.shared.updateProfileName(id: currentUser.id, firstName: first, lastName: last) }
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .alert("Edit Phone", isPresented: $showEditPhone) {
            TextField("Phone Number", text: $editPhoneText)
            Button("Save") {
                if !editPhoneText.isEmpty {
                    currentUser.phone = editPhoneText
                    Task { try? await FirestoreService.shared.updateProfilePhone(id: currentUser.id, phone: editPhoneText) }
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .alert("Sign Out", isPresented: $showSignOutConfirm) {
            Button("Sign Out", role: .destructive) { authState.logout() }
            Button("Cancel", role: .cancel) { }
        } message: { Text("Are you sure you want to sign out?") }
        .alert("Leave Team", isPresented: $showLeaveTeamConfirm) {
            Button("Leave Team", role: .destructive) { authState.leaveOrganization() }
            Button("Cancel", role: .cancel) { }
        } message: { Text("This will disconnect you from \(authState.orgName). You'll need the team code to rejoin.") }
        .navigationDestination(isPresented: $showNotificationSettings) { NotificationSettingsView().environmentObject(settings) }
        .navigationDestination(isPresented: $showAppearanceSettings) { AppearanceSettingsView().environmentObject(settings) }
        .navigationDestination(isPresented: $showHelpSupport) { HelpSupportView() }
    }
    
    // MARK: - Profile Header
    private var profileHeader: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .bottomTrailing) {
                if let uiImage = profileImage {
                    Image(uiImage: uiImage).resizable().aspectRatio(contentMode: .fill).frame(width: 100, height: 100).clipShape(Circle())
                        .overlay(Circle().stroke(LinearGradient(colors: theme.gradient, startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: isAdmin ? 3 : 0))
                        .shadow(color: isAdmin ? theme.glow.opacity(0.3) : Color.clear, radius: 8)
                } else {
                    ProfileAvatar(userId: currentUser.id, initials: currentUser.initials, size: 100,
                        color: isAdmin ? theme.primary : team?.color ?? Color.bhqTint)
                        .overlay(Circle().stroke(LinearGradient(colors: isAdmin ? [theme.secondary, theme.primary] : [Color.clear], startPoint: .top, endPoint: .bottom), lineWidth: isAdmin ? 2 : 0).frame(width: 108, height: 108))
                        .shadow(color: isAdmin ? theme.glow.opacity(0.25) : Color.clear, radius: 10)
                }
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    ZStack {
                        Circle().fill(Color.bhqBlue).frame(width: 32, height: 32)
                        if isUploading {
                            ProgressView().tint(Color.white).scaleEffect(0.7)
                        } else {
                            Image(systemName: "camera.fill").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.white)
                        }
                    }
                    .overlay(Circle().stroke(Color.black, lineWidth: 3))
                }
                .disabled(isUploading)
                .onChange(of: selectedPhoto) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            profileImage = uiImage
                            ProfileImageService.shared.cacheImage(uiImage, for: currentUser.id)
                            
                            // Upload to Firebase
                            isUploading = true
                            do {
                                let _ = try await ProfileImageService.shared.uploadProfileImage(
                                    uiImage, orgCode: authState.orgCode, userId: currentUser.id)
                                print("✅ Profile image uploaded")
                            } catch {
                                print("❌ Upload failed: \(error)")
                            }
                            isUploading = false
                        }
                    }
                }
            }
            .onAppear {
                // Load existing profile image
                Task {
                    if let cached = ProfileImageService.shared.getCached(userId: currentUser.id) {
                        profileImage = cached
                    }
                }
            }
            Text(currentUser.displayName).font(.system(size: 24, weight: .bold))
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: theme.icon).font(.system(size: 10, weight: .bold))
                    Text(theme.badge).font(.system(size: 12, weight: .bold)).tracking(0.5)
                }.foregroundStyle(theme.primary).padding(.horizontal, 12).padding(.vertical, 5)
                .background(LinearGradient(colors: [theme.primary.opacity(0.15), theme.primary.opacity(0.08)], startPoint: .leading, endPoint: .trailing))
                .overlay(Capsule().stroke(theme.primary.opacity(0.3), lineWidth: 0.5)).clipShape(Capsule())
                if let team = team {
                    HStack(spacing: 4) { Image(systemName: team.icon).font(.system(size: 10)); Text(team.name).font(.system(size: 12, weight: .medium)) }
                    .foregroundStyle(team.color).padding(.horizontal, 10).padding(.vertical, 4).background(team.color.opacity(0.15)).clipShape(Capsule())
                }
            }
            if isAdmin { Text("\(theme.name) Theme").font(.system(size: 11, weight: .medium)).foregroundStyle(theme.primary.opacity(0.6)).tracking(1) }
            Text(currentUser.position).font(.subheadline).foregroundStyle(Color.secondary)
        }.frame(maxWidth: .infinity).padding(.vertical, 8)
    }
    
    // MARK: - Team Code Section
    private var teamCodeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TEAM").font(.footnote).foregroundStyle(Color.secondary).padding(.horizontal)
            
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "building.2.fill").font(.system(size: 14)).foregroundStyle(Color.white)
                        .frame(width: 28, height: 28).background(Color.bhqBlue).clipShape(RoundedRectangle(cornerRadius: 6))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(authState.orgName.isEmpty ? "My Team" : authState.orgName).font(.body)
                        Text("Team Code").font(.subheadline).foregroundStyle(Color.secondary)
                    }
                    Spacer()
                    Button {
                        UIPasteboard.general.string = authState.orgCode
                        withAnimation { codeCopied = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation { codeCopied = false } }
                    } label: {
                        HStack(spacing: 4) {
                            Text(authState.orgCode)
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.bhqBlue)
                            Image(systemName: codeCopied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 11))
                                .foregroundStyle(codeCopied ? Color.bhqGreen : Color.bhqBlue)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.bhqBlue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }.padding(.horizontal, 16).padding(.vertical, 11)
            }
            .background(Color.bhqCard).clipShape(RoundedRectangle(cornerRadius: 12)).padding(.horizontal)
            
            if !authState.orgCode.isEmpty {
                Text("Share this code with your team so they can join")
                    .font(.system(size: 11)).foregroundStyle(Color.secondary.opacity(0.6)).padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Status / Info / Equipment / Account (unchanged)
    private var statusSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("STATUS").font(.footnote).foregroundStyle(Color.secondary).padding(.horizontal)
            HStack(spacing: 8) {
                statusButton(.online, label: "Online", icon: "circle.fill", color: Color.bhqGreen)
                statusButton(.busy, label: "Busy", icon: "minus.circle.fill", color: Color.bhqYellow)
                statusButton(.offline, label: "Offline", icon: "moon.fill", color: Color(.systemGray3))
            }.padding(.horizontal)
        }
    }
    private func statusButton(_ status: PresenceStatus, label: String, icon: String, color: Color) -> some View {
        Button { withAnimation(.easeInOut(duration: 0.15)) { currentUser.status = status } } label: {
            HStack(spacing: 6) { Image(systemName: icon).font(.system(size: 10)); Text(label).font(.system(size: 13, weight: .medium)) }
            .foregroundStyle(currentUser.status == status ? Color.white : color).frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(currentUser.status == status ? color : color.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 10))
        }.buttonStyle(.plain)
    }
    
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("INFORMATION").font(.footnote).foregroundStyle(Color.secondary).padding(.horizontal)
            VStack(spacing: 0) {
                infoRow(icon: "envelope.fill", label: "Email", value: currentUser.email, action: nil)
                Divider().padding(.leading, 52)
                infoRow(icon: "phone.fill", label: "Phone", value: currentUser.phone ?? "Not set") { editPhoneText = currentUser.phone ?? ""; showEditPhone = true }
                Divider().padding(.leading, 52)
                infoRow(icon: "person.text.rectangle", label: "Name", value: currentUser.displayName) { editNameText = currentUser.displayName; showEditName = true }
                Divider().padding(.leading, 52)
                infoRow(icon: "person.badge.shield.checkmark", label: "Role", value: currentUser.role.displayName, action: nil)
                Divider().padding(.leading, 52)
                infoRow(icon: "clock", label: "Logged In", value: currentUser.loginTimeString, action: nil)
                Divider().padding(.leading, 52)
                infoRow(icon: "calendar", label: "Member Since", value: currentUser.joinedDateString, action: nil)
            }.background(Color.bhqCard).clipShape(RoundedRectangle(cornerRadius: 12)).padding(.horizontal)
        }
    }
    private func infoRow(icon: String, label: String, value: String, action: (() -> Void)?) -> some View {
        Button { action?() } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 14)).foregroundStyle(Color.secondary)
                    .frame(width: 28, height: 28).background(Color(.systemFill)).clipShape(RoundedRectangle(cornerRadius: 6))
                Text(label).font(.body).foregroundStyle(Color.secondary); Spacer()
                Text(value).font(.body).foregroundStyle(Color.primary).lineLimit(1)
                if action != nil { Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.secondary.opacity(0.5)) }
            }.padding(.horizontal, 16).padding(.vertical, 11).contentShape(Rectangle())
        }.buttonStyle(.plain).disabled(action == nil)
    }
    
    private var equipmentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MY EQUIPMENT").font(.footnote).foregroundStyle(Color.secondary).padding(.horizontal)
            if myEquipment.isEmpty {
                HStack { Image(systemName: "tray").foregroundStyle(Color.secondary); Text("No equipment checked out").font(.subheadline).foregroundStyle(Color.secondary) }
                .frame(maxWidth: .infinity).padding(.vertical, 20).background(Color.bhqCard).clipShape(RoundedRectangle(cornerRadius: 12)).padding(.horizontal)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(myEquipment.enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: 12) {
                            Image(systemName: "wrench.and.screwdriver").font(.system(size: 14)).foregroundStyle(Color.secondary)
                                .frame(width: 28, height: 28).background(Color(.systemFill)).clipShape(RoundedRectangle(cornerRadius: 6))
                            VStack(alignment: .leading, spacing: 1) { Text(item.name).font(.body); Text(item.type).font(.subheadline).foregroundStyle(Color.secondary) }
                            Spacer()
                            if item.hasIssue {
                                Text(item.condition.rawValue.uppercased()).font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(item.condition == .missing ? Color.bhqYellow : Color.bhqTint)
                                    .padding(.horizontal, 6).padding(.vertical, 3)
                                    .background((item.condition == .missing ? Color.bhqYellow : Color.bhqTint).opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            } else {
                                Text("OK").font(.system(size: 10, weight: .semibold)).foregroundStyle(Color.bhqGreen)
                                    .padding(.horizontal, 6).padding(.vertical, 3).background(Color.bhqGreen.opacity(0.15)).clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }.padding(.horizontal, 16).padding(.vertical, 11)
                        if index < myEquipment.count - 1 { Divider().padding(.leading, 52) }
                    }
                }.background(Color.bhqCard).clipShape(RoundedRectangle(cornerRadius: 12)).padding(.horizontal)
            }
        }
    }
    
    // MARK: - Audio Output
    private var audioOutputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AUDIO OUTPUT").font(.footnote).foregroundStyle(Color.secondary).padding(.horizontal)
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: audioOutputIcon)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.white)
                        .frame(width: 28, height: 28)
                        .background(audioOutputIsBluetooth ? Color.bhqBlue : Color(.systemGray2))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(audioOutputName)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.primary)
                        Text(audioOutputIsBluetooth ? "Bluetooth Connected" : "System Default")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.secondary)
                    }
                    Spacer()
                    if audioOutputIsBluetooth {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.bhqGreen)
                                .frame(width: 6, height: 6)
                            Text("Connected")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.bhqGreen)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.bhqGreen.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)

                if audioOutputIsBluetooth {
                    Divider().padding(.leading, 52)
                    HStack(spacing: 12) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.white)
                            .frame(width: 28, height: 28)
                            .background(Color.bhqGreen)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(audioInputName)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.primary)
                            Text("Microphone Input")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                }
            }
            .background(Color.bhqCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
        .onAppear { refreshAudioRoute() }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)) { _ in
            refreshAudioRoute()
        }
    }

    private var audioInputName: String {
        let inputs = AVAudioSession.sharedInstance().currentRoute.inputs
        return inputs.first?.portName ?? "iPhone Microphone"
    }

    private func refreshAudioRoute() {
        let route = AVAudioSession.sharedInstance().currentRoute
        guard let output = route.outputs.first else {
            audioOutputName = "iPhone Speaker"
            audioOutputIcon = "speaker.wave.2.fill"
            audioOutputIsBluetooth = false
            return
        }

        let btTypes: Set<AVAudioSession.Port> = [.bluetoothA2DP, .bluetoothHFP, .bluetoothLE]
        let isBT = btTypes.contains(output.portType)

        audioOutputIsBluetooth = isBT
        audioOutputName = output.portName

        switch output.portType {
        case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
            audioOutputIcon = "headphones"
        case .headphones:
            audioOutputIcon = "headphones"
            audioOutputName = "Wired Headphones"
        case .builtInSpeaker:
            audioOutputIcon = "speaker.wave.2.fill"
            audioOutputName = "iPhone Speaker"
        case .builtInReceiver:
            audioOutputIcon = "phone.fill"
            audioOutputName = "iPhone Earpiece"
        default:
            audioOutputIcon = "speaker.wave.2.fill"
        }
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ACCOUNT").font(.footnote).foregroundStyle(Color.secondary).padding(.horizontal)
            VStack(spacing: 0) {
                Button { showNotificationSettings = true } label: { accountRow(icon: "bell.fill", label: "Notifications", color: Color.bhqBlue) }.buttonStyle(.plain)
                Divider().padding(.leading, 52)
                Button { showAppearanceSettings = true } label: { accountRow(icon: "paintbrush.fill", label: "Appearance", color: Color.bhqPurple) }.buttonStyle(.plain)
                Divider().padding(.leading, 52)
                Button { showHelpSupport = true } label: { accountRow(icon: "questionmark.circle.fill", label: "Help & Support", color: Color.bhqGreen) }.buttonStyle(.plain)
            }.background(Color.bhqCard).clipShape(RoundedRectangle(cornerRadius: 12)).padding(.horizontal)
            
            Button { showSignOutConfirm = true } label: {
                HStack { Spacer(); Text("Sign Out").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.bhqTint); Spacer() }
                .padding(.vertical, 14).background(Color.bhqTint.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 12))
            }.padding(.horizontal)
            
            Button { showLeaveTeamConfirm = true } label: {
                HStack { Spacer(); Text("Leave Team").font(.system(size: 14, weight: .medium)).foregroundStyle(Color.secondary.opacity(0.5)); Spacer() }
                .padding(.vertical, 12)
            }.padding(.horizontal)
            
            Text("Valor.Live v1.0.0").font(.system(size: 12)).foregroundStyle(Color.secondary.opacity(0.5)).frame(maxWidth: .infinity).padding(.top, 4)
        }
    }
    
    private func accountRow(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 14)).foregroundStyle(Color.white)
                .frame(width: 28, height: 28).background(color).clipShape(RoundedRectangle(cornerRadius: 6))
            Text(label).font(.body).foregroundStyle(Color.primary); Spacer()
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.secondary.opacity(0.5))
        }.padding(.horizontal, 16).padding(.vertical, 11).contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        ProfileView(currentUser: .constant(AppUser.samples[0]))
            .environmentObject(AuthState()).environmentObject(AppSettings())
    }.preferredColorScheme(.dark)
}

