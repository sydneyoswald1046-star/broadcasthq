import SwiftUI

struct SignupView: View {
    @EnvironmentObject var authState: AuthState
    
    @State private var step: SignupStep = .role
    @State private var selectedRole: UserRole = .member
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var email: String = ""
    @State private var phone: String = ""
    @State private var position: String = ""
    @State private var selectedTeam: String = ""
    @State private var pin: String = ""
    @State private var confirmPin: String = ""
    @State private var pinMismatch: Bool = false
    @State private var enteringConfirm: Bool = false
    @State private var pinTaken: Bool = false
    @State private var googleSignInError: String?
    @State private var isSigningIn: Bool = false
    
    // Organization
    @State private var teamName: String = ""
    @State private var joinCode: String = ""
    @State private var generatedCode: String = ""
    @State private var isCreatingOrg: Bool = false
    @State private var isJoiningOrg: Bool = false
    @State private var orgError: String?
    @State private var orgSetupDone: Bool = false
    @State private var adminOrgChoice: String = ""  // "create" or "join"
    
    enum SignupStep { case role, details, organization, pin }
    
    private let leaderPositions = ["Director", "Tech Director", "Producer", "Floor Director"]
    private let memberPositions = [
        "Camera 1", "Camera 2", "Camera 3", "Photographer", "Lead Photographer",
        "Audio Engineer", "Audio Assist", "Graphics Op", "Projection Op",
        "Choir Director", "Worship Leader", "Lighting Director", "Lighting Op", "Volunteer"
    ]
    
    private var adminExists: Bool { authState.accounts.contains { $0.role == .admin && $0.isApproved } }
    
    private var isDetailsValid: Bool {
        if selectedRole == .admin { return !firstName.isEmpty && !lastName.isEmpty && !email.isEmpty && !phone.isEmpty }
        return !firstName.isEmpty && !lastName.isEmpty && !email.isEmpty && !phone.isEmpty && !position.isEmpty && !selectedTeam.isEmpty
    }
    
    var body: some View {
        VStack(spacing: 0) {
            progressBar
            switch step {
            case .role: ScrollView { roleSelection.padding(.vertical, 24) }
            case .details: ScrollView { detailsForm.padding(.vertical, 24) }
            case .organization: ScrollView { organizationStep.padding(.vertical, 24) }
            case .pin: pinSetup
            }
            bottomButton
        }
        .background(Color.bhqBackground)
        .navigationTitle("Create Account")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Progress Bar
    private var progressBar: some View {
        HStack(spacing: 4) {
            progressDot(active: true)
            progressLine(active: step != .role)
            progressDot(active: step != .role)
            progressLine(active: step == .organization || step == .pin)
            progressDot(active: step == .organization || step == .pin)
            progressLine(active: step == .pin)
            progressDot(active: step == .pin)
        }.padding(.horizontal, 40).padding(.vertical, 16)
    }
    private func progressDot(active: Bool) -> some View {
        Circle().fill(active ? Color.bhqBlue : Color(.systemFill)).frame(width: 10, height: 10)
    }
    private func progressLine(active: Bool) -> some View {
        Rectangle().fill(active ? Color.bhqBlue : Color(.systemFill)).frame(height: 2)
    }
    
    // MARK: - Step 1: Role
    private var roleSelection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What's your role?").font(.system(size: 22, weight: .bold)).padding(.horizontal)
            Text("This determines your access level and sign-up process.")
                .font(.subheadline).foregroundStyle(Color.secondary).padding(.horizontal)
            VStack(spacing: 10) {
                if adminExists { lockedAdminCard }
                else { roleCard(role: .admin, title: "Admin", subtitle: "Full control over broadcasts, team, and settings", icon: "crown.fill", color: RoleTheme.admin.primary, note: "Creates a new team") }
                roleCard(role: .teamLead, title: "Director / Producer", subtitle: "Manage broadcasts, rundowns, and team operations", icon: "film.fill", color: RoleTheme.director.primary, note: "Joins existing team with code")
                roleCard(role: .member, title: "Team Member", subtitle: "Photography, broadcast, projection, choir, and lights crew", icon: "person.fill", color: Color.bhqBlue, note: "Joins existing team · Requires approval")
            }.padding(.horizontal)
        }
    }
    
    private var lockedAdminCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "crown.fill").font(.system(size: 18, weight: .semibold)).foregroundStyle(Color.secondary.opacity(0.4))
                .frame(width: 44, height: 44).background(Color(.systemFill).opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("Admin").font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.secondary.opacity(0.5))
                    Image(systemName: "lock.fill").font(.system(size: 11)).foregroundStyle(Color.secondary.opacity(0.4))
                }
                Text("Admin already registered").font(.system(size: 11, weight: .medium)).foregroundStyle(Color.bhqTint.opacity(0.7))
            }
            Spacer()
        }.padding(14).background(Color.bhqCard.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    private func roleCard(role: UserRole, title: String, subtitle: String, icon: String, color: Color, note: String) -> some View {
        Button { withAnimation { selectedRole = role } } label: {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.system(size: 18, weight: .semibold)).foregroundStyle(color)
                    .frame(width: 44, height: 44).background(color.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.primary)
                    Text(subtitle).font(.system(size: 12)).foregroundStyle(Color.secondary).lineLimit(2)
                    Text(note).font(.system(size: 11, weight: .medium)).foregroundStyle(color)
                }
                Spacer()
                Image(systemName: selectedRole == role ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22)).foregroundStyle(selectedRole == role ? color : Color.secondary.opacity(0.3))
            }.padding(14).background(selectedRole == role ? color.opacity(0.06) : Color.bhqCard)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(selectedRole == role ? color.opacity(0.4) : Color.clear, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }.buttonStyle(.plain)
    }
    
    @StateObject private var appleSignIn = AppleSignInService()
    
    // MARK: - Step 2: Details
    private var detailsForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your details").font(.system(size: 22, weight: .bold)).padding(.horizontal)
            
            if selectedRole == .admin || selectedRole == .teamLead {
                // Sign in with Apple
                AppleSignInButton {
                    appleSignIn.signIn { email, fullName, appleId in
                        let parts = fullName.split(separator: " ")
                        firstName = parts.first.map(String.init) ?? ""
                        lastName = parts.dropFirst().joined(separator: " ")
                        self.email = email
                    }
                }
                .padding(.horizontal)
                
                // Sign in with Google
                Button { signInWithGoogle() } label: {
                    HStack(spacing: 10) {
                        if isSigningIn { ProgressView().tint(Color.primary) }
                        else { Image(systemName: "g.circle.fill").font(.system(size: 20)) }
                        Text(isSigningIn ? "Signing in..." : "Sign in with Google").font(.system(size: 16, weight: .semibold))
                    }.foregroundStyle(Color.primary).frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Color.white.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }.disabled(isSigningIn).padding(.horizontal)
                
                if let error = googleSignInError {
                    Text(error).font(.system(size: 12, weight: .medium)).foregroundStyle(Color.bhqTint).padding(.horizontal)
                }
                if let error = appleSignIn.errorMessage {
                    Text(error).font(.system(size: 12, weight: .medium)).foregroundStyle(Color.bhqTint).padding(.horizontal)
                }
                
                HStack {
                    Rectangle().fill(Color.secondary.opacity(0.2)).frame(height: 0.5)
                    Text("or fill manually").font(.system(size: 13)).foregroundStyle(Color.secondary)
                    Rectangle().fill(Color.secondary.opacity(0.2)).frame(height: 0.5)
                }.padding(.horizontal)
            }
            
            VStack(spacing: 12) {
                HStack(spacing: 10) { formField("First Name", text: $firstName, icon: "person"); formField("Last Name", text: $lastName, icon: "person") }
                formField("Email", text: $email, icon: "envelope", keyboard: .emailAddress)
                formField("Phone", text: $phone, icon: "phone", keyboard: .phonePad)
                
                if selectedRole == .teamLead {
                    pickerField(icon: "briefcase", label: "Position", selection: $position, options: leaderPositions, placeholder: "Select Position")
                }
                if selectedRole == .member {
                    pickerField(icon: "briefcase", label: "Position", selection: $position, options: memberPositions, placeholder: "Select Position")
                }
                if selectedRole != .admin {
                    HStack(spacing: 8) {
                        Image(systemName: "person.3").font(.system(size: 14)).foregroundStyle(Color.secondary).frame(width: 20)
                        Picker("Team", selection: $selectedTeam) {
                            Text("Select Team").tag("")
                            ForEach(Team.all) { team in Text(team.name).tag(team.id) }
                        }.pickerStyle(.menu).tint(selectedTeam.isEmpty ? Color.secondary : Color.primary)
                    }.padding(.horizontal, 14).padding(.vertical, 12)
                    .background(Color(.systemFill).opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }.padding(.horizontal)
        }
    }
    
    // MARK: - Step 3: Organization
    private var organizationStep: some View {
        VStack(spacing: 24) {
            if selectedRole == .admin {
                if adminOrgChoice.isEmpty {
                    // Admin choice: Create or Join
                    VStack(spacing: 16) {
                        Image(systemName: "shield.lefthalf.filled").font(.system(size: 40)).foregroundStyle(RoleTheme.admin.primary)
                        Text("Admin Setup").font(.system(size: 22, weight: .bold))
                        Text("Are you the first admin setting up this organization, or joining as a second admin?")
                            .font(.subheadline).foregroundStyle(Color.secondary).multilineTextAlignment(.center).padding(.horizontal, 32)
                        
                        VStack(spacing: 10) {
                            Button {
                                withAnimation(.easeOut(duration: 0.15)) { adminOrgChoice = "create" }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "plus.circle.fill").font(.system(size: 20)).foregroundStyle(RoleTheme.admin.primary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Create New Team").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.primary)
                                        Text("I'm setting up our organization").font(.system(size: 12)).foregroundStyle(Color.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.secondary.opacity(0.4))
                                }
                                .padding(16)
                                .background(Color.bhqCard)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }.buttonStyle(.plain)
                            
                            Button {
                                withAnimation(.easeOut(duration: 0.15)) { adminOrgChoice = "join" }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "person.badge.key.fill").font(.system(size: 20)).foregroundStyle(Color.bhqBlue)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Join as Second Admin").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.primary)
                                        Text("I have a team code from the first admin").font(.system(size: 12)).foregroundStyle(Color.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.secondary.opacity(0.4))
                                }
                                .padding(16)
                                .background(Color.bhqCard)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }.buttonStyle(.plain)
                        }
                        .padding(.horizontal)
                    }
                } else if adminOrgChoice == "create" {
                    // Admin creates a new team
                    VStack(spacing: 16) {
                        Image(systemName: "building.2.fill").font(.system(size: 40)).foregroundStyle(RoleTheme.admin.primary)
                        Text("Create Your Team").font(.system(size: 22, weight: .bold))
                        Text("Give your broadcast team a name. You'll get a unique code to share with your crew.")
                            .font(.subheadline).foregroundStyle(Color.secondary).multilineTextAlignment(.center).padding(.horizontal, 32)
                        
                        formField("e.g. Grace Community Church", text: $teamName, icon: "building.2").padding(.horizontal)
                        
                        if !generatedCode.isEmpty {
                            VStack(spacing: 8) {
                                Text("Your Team Code").font(.system(size: 13, weight: .medium)).foregroundStyle(Color.secondary)
                                Text(generatedCode)
                                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                                    .foregroundStyle(RoleTheme.admin.primary)
                                    .tracking(4)
                                Text("Share this code with your team members").font(.system(size: 12)).foregroundStyle(Color.secondary)
                            }
                            .padding(20)
                            .background(RoleTheme.admin.primary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .padding(.horizontal)
                        }
                        
                        Button { withAnimation { adminOrgChoice = "" } } label: {
                            Text("← Back to options").font(.system(size: 13, weight: .medium)).foregroundStyle(Color.secondary)
                        }
                    }
                } else {
                    // Admin joins existing team as second admin
                    VStack(spacing: 16) {
                        Image(systemName: "person.badge.key.fill").font(.system(size: 40)).foregroundStyle(Color.bhqBlue)
                        Text("Join as Admin").font(.system(size: 22, weight: .bold))
                        Text("Enter the 6-character team code from your organization's first admin.")
                            .font(.subheadline).foregroundStyle(Color.secondary).multilineTextAlignment(.center).padding(.horizontal, 32)
                        
                        TextField("e.g. GRC482", text: $joinCode)
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .multilineTextAlignment(.center)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .frame(maxWidth: 200)
                            .padding(.vertical, 14)
                            .background(Color(.systemFill).opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .onChange(of: joinCode) { _, newValue in
                                joinCode = String(newValue.prefix(6)).uppercased(); orgError = nil
                            }
                        
                        if orgSetupDone {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.bhqGreen)
                                Text("Connected to \(authState.orgName)").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.bhqGreen)
                            }
                        }
                        
                        Text("Each organization can have up to 2 admins")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.secondary.opacity(0.5))
                        
                        Button { withAnimation { adminOrgChoice = ""; joinCode = ""; orgError = nil; orgSetupDone = false } } label: {
                            Text("← Back to options").font(.system(size: 13, weight: .medium)).foregroundStyle(Color.secondary)
                        }
                    }
                }
            } else {
                // Director/Member joins existing team
                VStack(spacing: 16) {
                    Image(systemName: "person.3.fill").font(.system(size: 40)).foregroundStyle(Color.bhqBlue)
                    Text("Join a Team").font(.system(size: 22, weight: .bold))
                    Text("Enter the 6-character team code from your admin.")
                        .font(.subheadline).foregroundStyle(Color.secondary).multilineTextAlignment(.center).padding(.horizontal, 32)
                    
                    TextField("e.g. GRC482", text: $joinCode)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .frame(maxWidth: 200)
                        .padding(.vertical, 14)
                        .background(Color(.systemFill).opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .onChange(of: joinCode) { _, newValue in
                            joinCode = String(newValue.prefix(6)).uppercased(); orgError = nil
                        }
                    
                    if orgSetupDone {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.bhqGreen)
                            Text("Connected to \(authState.orgName)").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.bhqGreen)
                        }
                    }
                }
            }
            
            if let error = orgError {
                Text(error).font(.system(size: 13, weight: .medium)).foregroundStyle(Color.bhqTint)
            }
        }
    }
    
    private func formField(_ placeholder: String, text: Binding<String>, icon: String, keyboard: UIKeyboardType = .default) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 14)).foregroundStyle(Color.secondary).frame(width: 20)
            TextField(placeholder, text: text).font(.body).keyboardType(keyboard).autocorrectionDisabled()
                .textInputAutocapitalization(placeholder.contains("Name") || placeholder.contains("e.g.") ? .words : .never)
        }.padding(.horizontal, 14).padding(.vertical, 12)
        .background(Color(.systemFill).opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private func pickerField(icon: String, label: String, selection: Binding<String>, options: [String], placeholder: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 14)).foregroundStyle(Color.secondary).frame(width: 20)
            Picker(label, selection: selection) {
                Text(placeholder).tag("")
                ForEach(options, id: \.self) { opt in Text(opt).tag(opt) }
            }.pickerStyle(.menu).tint(Color.primary)
        }.padding(.horizontal, 14).padding(.vertical, 12)
        .background(Color(.systemFill).opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private func signInWithGoogle() {
        isSigningIn = true; googleSignInError = nil
        Task {
            do {
                let result = try await GoogleSignInService.shared.signIn()
                await MainActor.run { firstName = result.firstName; lastName = result.lastName; email = result.email; isSigningIn = false }
            } catch {
                await MainActor.run { googleSignInError = "Sign-in failed: \(error.localizedDescription)"; isSigningIn = false }
            }
        }
    }
    
    // MARK: - Step 4: PIN
    private var pinSetup: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                Text("Set your PIN").font(.system(size: 22, weight: .bold)).padding(.top, 20)
                Text("You'll use this 4-digit PIN to log in every time.").font(.subheadline).foregroundStyle(Color.secondary)
                Text(enteringConfirm ? "Confirm PIN" : "Enter PIN")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(enteringConfirm ? Color.bhqGreen : Color.bhqBlue).padding(.top, 8)
                HStack(spacing: 16) {
                    let currentPin = enteringConfirm ? confirmPin : pin
                    ForEach(0..<4, id: \.self) { index in
                        Circle().fill(index < currentPin.count ? (enteringConfirm ? Color.bhqGreen : Color.bhqBlue) : Color.clear)
                            .frame(width: 18, height: 18)
                            .overlay(Circle().stroke(index < currentPin.count ? (enteringConfirm ? Color.bhqGreen : Color.bhqBlue) : Color.secondary.opacity(0.3), lineWidth: 1.5))
                    }
                }
                if pinMismatch { Text("PINs don't match — try again").font(.system(size: 13, weight: .medium)).foregroundStyle(Color.bhqTint) }
                if pinTaken { Text("A teammate already uses this PIN — pick another").font(.system(size: 13, weight: .medium)).foregroundStyle(Color.bhqTint) }
            }
            Spacer()
            pinNumberPad.padding(.bottom, 8)
        }
    }
    
    private var pinNumberPad: some View {
        VStack(spacing: 10) {
            ForEach(0..<3) { row in
                HStack(spacing: 20) { ForEach(1...3, id: \.self) { col in let num = row * 3 + col; pinButton("\(num)") { appendPinDigit("\(num)") } } }
            }
            HStack(spacing: 20) {
                pinButton("↺", isSystem: true) { resetPins() }
                pinButton("0") { appendPinDigit("0") }
                pinButton("⌫", isSystem: true) { deletePinDigit() }
            }
        }
    }
    
    private func pinButton(_ label: String, isSystem: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(.system(size: isSystem ? 20 : 26, weight: .medium)).foregroundStyle(Color.white)
                .frame(width: 68, height: 68).background(Color.white.opacity(0.06)).clipShape(Circle())
        }.buttonStyle(.plain)
    }
    
    private func appendPinDigit(_ digit: String) {
        pinMismatch = false; pinTaken = false
        if !enteringConfirm { guard pin.count < 4 else { return }; pin += digit
            if pin.count == 4 { DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { withAnimation { enteringConfirm = true } } }
        } else { guard confirmPin.count < 4 else { return }; confirmPin += digit }
    }
    private func deletePinDigit() {
        if enteringConfirm { if !confirmPin.isEmpty { confirmPin.removeLast() } else { withAnimation { enteringConfirm = false } } }
        else { if !pin.isEmpty { pin.removeLast() } }
        pinMismatch = false; pinTaken = false
    }
    private func resetPins() { withAnimation { pin = ""; confirmPin = ""; enteringConfirm = false; pinMismatch = false; pinTaken = false } }
    
    // MARK: - Bottom Button
    private var bottomButton: some View {
        VStack(spacing: 0) {
            Divider()
            Button { handleNext() } label: {
                HStack(spacing: 8) {
                    if isCreatingOrg || isJoiningOrg { ProgressView().tint(Color.white) }
                    Text(buttonLabel).font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(Color.white).frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(isStepValid ? Color.bhqBlue : Color.secondary.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }.disabled(!isStepValid || isCreatingOrg || isJoiningOrg)
            .padding(.horizontal).padding(.vertical, 12)
        }.background(.ultraThinMaterial)
    }
    
    private var buttonLabel: String {
        switch step {
        case .role: return "Continue"
        case .details: return "Next"
        case .organization:
            if selectedRole == .admin {
                return generatedCode.isEmpty ? "Create Team" : "Continue"
            } else {
                return orgSetupDone ? "Continue" : "Join Team"
            }
        case .pin: return selectedRole == .member ? "Submit for Approval" : "Create Account"
        }
    }
    
    private var isStepValid: Bool {
        switch step {
        case .role: return true
        case .details: return isDetailsValid
        case .organization:
            if selectedRole == .admin {
                if adminOrgChoice == "create" { return !teamName.isEmpty }
                if adminOrgChoice == "join" { return joinCode.count == 6 || orgSetupDone }
                return false  // Still on choice screen
            }
            else { return joinCode.count == 6 || orgSetupDone }
        case .pin: return pin.count == 4 && confirmPin.count == 4
        }
    }
    
    private func handleNext() {
        switch step {
        case .role: withAnimation { step = .details }
        case .details: withAnimation { step = .organization }
        case .organization: handleOrgStep()
        case .pin:
            if pin != confirmPin { pinMismatch = true; resetPins(); return }
            // Check org-scoped PIN uniqueness (local + Firestore backup)
            if authState.accounts.contains(where: { $0.pin == pin }) { pinTaken = true; resetPins(); return }
            isCreatingOrg = true
            Task {
                let taken = await authState.isPinTakenInOrg(pin)
                await MainActor.run {
                    isCreatingOrg = false
                    if taken { pinTaken = true; resetPins(); return }
                    let finalPosition = selectedRole == .admin ? "Admin" : position
                    let finalTeam = selectedRole == .admin ? "broadcast" : selectedTeam
                    authState.signupMember(firstName: firstName, lastName: lastName, email: email, phone: phone,
                        pin: pin, role: selectedRole, position: finalPosition, team: finalTeam)
                }
            }
        }
    }
    
    private func handleOrgStep() {
        if selectedRole == .admin && adminOrgChoice == "create" {
            if generatedCode.isEmpty {
                isCreatingOrg = true; orgError = nil
                Task {
                    do {
                        let code = try await authState.createOrganization(name: teamName)
                        await MainActor.run {
                            generatedCode = code; isCreatingOrg = false
                            authState.startListeners()
                        }
                    } catch {
                        await MainActor.run { orgError = "Failed to create team: \(error.localizedDescription)"; isCreatingOrg = false }
                    }
                }
            } else {
                withAnimation { step = .pin }
            }
        } else if selectedRole == .admin && adminOrgChoice == "join" {
            if orgSetupDone {
                withAnimation { step = .pin }
            } else {
                isJoiningOrg = true; orgError = nil
                Task {
                    do {
                        // Check admin count first
                        let adminCount = try await FirestoreService.shared.countAdmins(orgCode: joinCode)
                        if adminCount >= 2 {
                            await MainActor.run { orgError = "This organization already has 2 admins"; isJoiningOrg = false }
                            return
                        }
                        
                        let success = try await authState.joinOrganization(code: joinCode)
                        await MainActor.run {
                            isJoiningOrg = false
                            if success {
                                orgSetupDone = true
                                authState.startListeners()
                            } else {
                                orgError = "Team not found — check the code"
                            }
                        }
                    } catch {
                        await MainActor.run { isJoiningOrg = false; orgError = "Connection failed — try again" }
                    }
                }
            }
        } else {
            // Director/Member join
            if orgSetupDone {
                withAnimation { step = .pin }
            } else {
                isJoiningOrg = true; orgError = nil
                Task {
                    do {
                        let success = try await authState.joinOrganization(code: joinCode)
                        await MainActor.run {
                            isJoiningOrg = false
                            if success {
                                orgSetupDone = true
                                authState.startListeners()
                            } else {
                                orgError = "Team not found — check the code"
                            }
                        }
                    } catch {
                        await MainActor.run { isJoiningOrg = false; orgError = "Connection failed — try again" }
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack { SignupView().environmentObject(AuthState()) }.preferredColorScheme(.dark)
}
