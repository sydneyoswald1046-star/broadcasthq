import SwiftUI

struct PinLoginView: View {
    @EnvironmentObject var authState: AuthState
    
    enum LoginStep {
        case landing        // New device — Sign In or Create Account
        case emailPin       // New device — enter email then PIN
        case pin            // Remembered device — PIN only
        case forgotPin
        case resetPin
        case masterPicker
    }
    
    @State private var step: LoginStep = .landing
    @State private var pin: String = ""
    @State private var email: String = ""
    @State private var showError: Bool = false
    @State private var errorMessage: String = "Incorrect PIN — try again"
    @State private var shake: CGFloat = 0
    @State private var showSignup: Bool = false
    @State private var isSigningIn: Bool = false
    @State private var emailSubmitted: Bool = false

    // Rate limiting
    @State private var failedAttempts: Int = 0
    @State private var lockedUntil: Date?
    @State private var lockCountdown: Int = 0
    
    // Forgot PIN
    @State private var isGoogleSigningIn: Bool = false
    @State private var resetEmail: String = ""
    @StateObject private var appleSignInService = AppleSignInService()
    @State private var newPin: String = ""
    @State private var confirmNewPin: String = ""
    @State private var resetMessage: String?
    @State private var resetSuccess: Bool = false
    @State private var enteringConfirmReset: Bool = false
    
    // Master picker
    @State private var masterLoading: String?
    
    // Animations
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0
    @State private var buttonsOpacity: Double = 0
    
    @FocusState private var isEmailFocused: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color.bhqBackground, Color(red: 0.05, green: 0.05, blue: 0.12)],
                    startPoint: .top, endPoint: .bottom).ignoresSafeArea()
                
                if step == .landing {
                    Circle().fill(Color(red: 1, green: 0.42, blue: 0.1).opacity(0.06))
                        .frame(width: 300, height: 300).blur(radius: 60).offset(y: -120)
                }
                
                VStack(spacing: 0) {
                    switch step {
                    case .landing: landingPage
                    case .emailPin: emailPinPage
                    case .pin: pinPage
                    case .forgotPin: forgotPinPage
                    case .resetPin: resetPinPage
                    case .masterPicker: masterPickerPage
                    }
                }
            }
            .navigationDestination(isPresented: $showSignup) { SignupView() }
            .onAppear { decideInitialStep() }
            .onChange(of: authState.isLoading) { _, loading in
                if !loading && authState.isRememberedDevice { step = .pin }
            }
            .onChange(of: authState.isMasterMode) { _, isMaster in
                if isMaster { withAnimation(.easeInOut(duration: 0.3)) { step = .masterPicker; isSigningIn = false; pin = "" } }
            }
        }
    }
    
    private func decideInitialStep() {
        if authState.isRememberedDevice {
            step = .pin
        } else {
            step = .landing
            animateLanding()
        }
    }
    
    // MARK: - Landing Page (New Device)
    private var landingPage: some View {
        VStack(spacing: 0) {
            Spacer()
            valorLogo.frame(width: 200, height: 120).scaleEffect(logoScale).opacity(logoOpacity).padding(.bottom, 8)
            Text("NEVER MISS A MOMENT").font(.system(size: 11, weight: .medium)).foregroundStyle(Color.secondary.opacity(0.4)).tracking(4).opacity(logoOpacity)
            Spacer()
            VStack(spacing: 12) {
                Button { withAnimation(.easeInOut(duration: 0.3)) { step = .emailPin } } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "lock.fill").font(.system(size: 16))
                        Text("Sign In").font(.system(size: 17, weight: .semibold))
                    }.foregroundStyle(Color.white).frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(LinearGradient(colors: [Color(red: 1, green: 0.42, blue: 0.1), Color(red: 0.9, green: 0.3, blue: 0.08)], startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: Color(red: 1, green: 0.42, blue: 0.1).opacity(0.3), radius: 10, y: 4)
                }
                Button { showSignup = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill").font(.system(size: 16))
                        Text("Create Account").font(.system(size: 17, weight: .semibold))
                    }.foregroundStyle(Color.white).frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Color.white.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.15), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }.opacity(buttonsOpacity).padding(.horizontal, 24).padding(.bottom, 50)
        }
    }
    
    // MARK: - Email + PIN Page (New Device)
    private var emailPinPage: some View {
        VStack(spacing: 0) {
            HStack {
                Button { withAnimation(.easeInOut(duration: 0.3)) {
                    step = .landing; email = ""; pin = ""; showError = false; emailSubmitted = false
                }} label: {
                    HStack(spacing: 4) { Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold)); Text("Back").font(.system(size: 16)) }.foregroundStyle(Color.secondary)
                }; Spacer()
            }.padding(.horizontal, 20).padding(.top, 16)
            
            Spacer()
            
            valorLogo.frame(width: 140, height: 80).padding(.bottom, 8)
            
            if !emailSubmitted {
                // Step 1: Email
                Text("Enter your email").font(.system(size: 22, weight: .bold)).padding(.bottom, 4)
                Text("We'll find your account").font(.system(size: 14)).foregroundStyle(Color.secondary).padding(.bottom, 24)
                
                HStack(spacing: 8) {
                    Image(systemName: "envelope").font(.system(size: 14)).foregroundStyle(Color.secondary)
                    TextField("email@example.com", text: $email)
                        .font(.system(size: 16))
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($isEmailFocused)
                        .submitLabel(.next)
                        .onSubmit { if !email.isEmpty { withAnimation { emailSubmitted = true } } }
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(Color(.systemFill).opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 40)
                
                if showError {
                    Text(errorMessage).font(.system(size: 13, weight: .medium)).foregroundStyle(Color.bhqTint).padding(.top, 8)
                }
                
                Spacer()
                
                Button {
                    withAnimation { emailSubmitted = true; showError = false }
                } label: {
                    Text("Continue").font(.system(size: 17, weight: .semibold)).foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(!email.isEmpty ? Color(red: 1, green: 0.42, blue: 0.1) : Color.secondary.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }.disabled(email.isEmpty).padding(.horizontal, 24).padding(.bottom, 50)
                
            } else {
                // Step 2: PIN
                Text("Enter your PIN").font(.system(size: 22, weight: .bold)).padding(.bottom, 4)
                Text(email).font(.system(size: 14)).foregroundStyle(Color(red: 1, green: 0.42, blue: 0.1).opacity(0.7)).padding(.bottom, 20)
                
                if isSigningIn {
                    ProgressView().tint(Color.secondary)
                    Text("Signing in...").font(.system(size: 14)).foregroundStyle(Color.secondary).padding(.top, 8)
                } else {
                    HStack(spacing: 16) {
                        ForEach(0..<4, id: \.self) { index in
                            Circle().fill(index < pin.count ? Color.white : Color.clear).frame(width: 16, height: 16)
                                .overlay(Circle().stroke(index < pin.count ? Color.white : Color.secondary.opacity(0.4), lineWidth: 1.5))
                        }
                    }.offset(x: shake).padding(.bottom, 8)
                    
                    if showError {
                        Text(errorMessage).font(.system(size: 13, weight: .medium)).foregroundStyle(Color.bhqTint).padding(.top, 4)
                    }
                }
                
                Spacer()
                
                if !isSigningIn {
                    numberPad.padding(.bottom, 12)
                    
                    Button { withAnimation { emailSubmitted = false; pin = ""; showError = false } } label: {
                        Text("Change email").font(.system(size: 14, weight: .medium)).foregroundStyle(Color.bhqBlue)
                    }.padding(.bottom, 8)
                    
                    Button { withAnimation { step = .forgotPin } } label: {
                        Text("Forgot PIN?").font(.system(size: 14, weight: .medium)).foregroundStyle(Color.secondary)
                    }.padding(.bottom, 40)
                }
            }
        }
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { isEmailFocused = true } }
    }
    
    // MARK: - PIN Page (Remembered Device)
    private var pinPage: some View {
        VStack(spacing: 0) {
            // Not you? link
            HStack {
                Spacer()
                Button {
                    authState.leaveOrganization()
                    withAnimation(.easeInOut(duration: 0.3)) { step = .landing; pin = ""; showError = false; email = ""; emailSubmitted = false; animateLanding() }
                } label: {
                    Text("Not you?").font(.system(size: 14, weight: .medium)).foregroundStyle(Color.secondary)
                }
            }.padding(.horizontal, 20).padding(.top, 16)
            
            Spacer()
            
            valorLogo.frame(width: 140, height: 80).padding(.bottom, 8)
            
            HStack(spacing: 0) {
                Text("Valor").font(.system(size: 24, weight: .bold)).foregroundStyle(Color.white)
                Text(".").font(.system(size: 24, weight: .bold)).foregroundStyle(Color(red: 1, green: 0.42, blue: 0.1))
                Text("Live").font(.system(size: 24, weight: .bold)).foregroundStyle(Color.white)
            }.padding(.bottom, 4)
            
            if !authState.orgName.isEmpty {
                Text(authState.orgName).font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(red: 1, green: 0.42, blue: 0.1).opacity(0.7)).padding(.bottom, 4)
            }
            
            Text("Welcome back").font(.system(size: 14)).foregroundStyle(Color.secondary).padding(.bottom, 20)
            
            if authState.isLoading {
                ProgressView().tint(Color.secondary)
                Text("Connecting...").font(.system(size: 14)).foregroundStyle(Color.secondary).padding(.top, 8)
            } else if isSigningIn {
                ProgressView().tint(Color.secondary)
                Text("Signing in...").font(.system(size: 14)).foregroundStyle(Color.secondary).padding(.top, 8)
            } else {
                HStack(spacing: 16) {
                    ForEach(0..<4, id: \.self) { index in
                        Circle().fill(index < pin.count ? Color.white : Color.clear).frame(width: 16, height: 16)
                            .overlay(Circle().stroke(index < pin.count ? Color.white : Color.secondary.opacity(0.4), lineWidth: 1.5))
                    }
                }.offset(x: shake).padding(.bottom, 8)
                
                if showError {
                    Text(errorMessage).font(.system(size: 13, weight: .medium)).foregroundStyle(Color.bhqTint).padding(.top, 4)
                }
            }
            
            Spacer()
            
            if !authState.isLoading && !isSigningIn {
                numberPad.padding(.bottom, 12)
                
                Button { withAnimation { step = .forgotPin } } label: {
                    Text("Forgot PIN?").font(.system(size: 14, weight: .medium)).foregroundStyle(Color.bhqBlue)
                }.padding(.bottom, 40)
            }
        }
    }
    
    // MARK: - Number Pad
    private var numberPad: some View {
        VStack(spacing: 12) {
            ForEach(0..<3) { row in
                HStack(spacing: 20) {
                    ForEach(1...3, id: \.self) { col in
                        let num = row * 3 + col; pinButton("\(num)") { appendPin("\(num)") }
                    }
                }
            }
            HStack(spacing: 20) {
                Color.clear.frame(width: 72, height: 72)
                pinButton("0") { appendPin("0") }
                pinButton("⌫", isSystem: true) { deletePin() }
            }
        }
    }
    
    private func pinButton(_ label: String, isSystem: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(.system(size: isSystem ? 20 : 26, weight: .medium)).foregroundStyle(Color.white)
                .frame(width: 72, height: 72).background(Color.white.opacity(0.06)).clipShape(Circle())
        }.buttonStyle(.plain)
    }
    
    private func appendPin(_ digit: String) {
        guard pin.count < 4 else { return }; showError = false; pin += digit
        if pin.count == 4 { DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { attemptLogin() } }
    }
    
    private func deletePin() { if !pin.isEmpty { pin.removeLast(); showError = false } }
    
    private var isLockedOut: Bool {
        guard let until = lockedUntil else { return false }
        return Date() < until
    }

    private func attemptLogin() {
        if isLockedOut {
            showError = true
            errorMessage = "Too many attempts — wait \(lockCountdown)s"
            pin = ""
            return
        }

        isSigningIn = true; showError = false
        Task {
            var success = false

            if step == .pin {
                success = await authState.rememberedSignIn(pin: pin)
            } else {
                let result = await authState.emailPinSignIn(email: email, pin: pin)
                success = result.success
                if !success {
                    await MainActor.run {
                        errorMessage = result.wrongPin ? "Incorrect PIN for this email" : "Account not found — check your email"
                    }
                }
            }

            await MainActor.run {
                isSigningIn = false
                if success {
                    failedAttempts = 0
                    lockedUntil = nil
                } else if !authState.isMasterMode {
                    failedAttempts += 1
                    if failedAttempts >= 5 {
                        let delay = min(30 * Int(pow(2.0, Double(failedAttempts - 5))), 300)
                        lockedUntil = Date().addingTimeInterval(Double(delay))
                        lockCountdown = delay
                        errorMessage = "Too many attempts — wait \(delay)s"
                        startLockTimer()
                    }
                    showError = true; pin = ""
                    shakeAnimation()
                }
            }
        }
    }

    private func startLockTimer() {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            DispatchQueue.main.async {
                lockCountdown -= 1
                if lockCountdown <= 0 {
                    timer.invalidate()
                    lockedUntil = nil
                    showError = false
                }
            }
        }
    }
    
    private func shakeAnimation() {
        withAnimation(.default) { shake = -12 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { withAnimation(.default) { shake = 12 } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { withAnimation(.default) { shake = -8 } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) { withAnimation(.default) { shake = 0 } }
    }
    
    // MARK: - Forgot PIN Page
    private var forgotPinPage: some View {
        VStack(spacing: 0) {
            HStack {
                Button { withAnimation { step = authState.isRememberedDevice ? .pin : .emailPin } } label: {
                    HStack(spacing: 4) { Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold)); Text("Back").font(.system(size: 16)) }.foregroundStyle(Color.secondary)
                }; Spacer()
            }.padding(.horizontal, 20).padding(.top, 16)
            Spacer()
            Image(systemName: "lock.trianglebadge.exclamationmark").font(.system(size: 48)).foregroundStyle(Color.bhqYellow).padding(.bottom, 16)
            Text("Forgot Your PIN?").font(.system(size: 24, weight: .bold)).padding(.bottom, 8)
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "person.fill").font(.system(size: 22)).foregroundStyle(Color.bhqBlue)
                    Text("Team Member?").font(.system(size: 16, weight: .semibold))
                    Text("Ask your admin to reset your PIN from the Manage Team panel.").font(.system(size: 13)).foregroundStyle(Color.secondary).multilineTextAlignment(.center)
                }.padding(20).frame(maxWidth: .infinity).background(Color.bhqCard).clipShape(RoundedRectangle(cornerRadius: 14))
                
                Button { withAnimation { step = .resetPin } } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "crown.fill").font(.system(size: 22)).foregroundStyle(RoleTheme.admin.primary)
                        Text("Admin?").font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.primary)
                        Text("Reset your PIN with Google sign-in").font(.system(size: 13)).foregroundStyle(Color.secondary)
                        HStack(spacing: 6) {
                            Image(systemName: "g.circle.fill").font(.system(size: 16))
                            Text("Reset with Google").font(.system(size: 15, weight: .semibold))
                        }.foregroundStyle(Color.white).padding(.horizontal, 20).padding(.vertical, 10).background(Color.bhqBlue).clipShape(RoundedRectangle(cornerRadius: 10))
                    }.padding(20).frame(maxWidth: .infinity).background(Color.bhqCard).clipShape(RoundedRectangle(cornerRadius: 14))
                }.buttonStyle(.plain)
            }.padding(.horizontal, 24)
            Spacer()
        }
    }
    
    // MARK: - Admin PIN Reset
    private var resetPinPage: some View {
        VStack(spacing: 0) {
            HStack {
                Button { withAnimation { step = .forgotPin; resetMessage = nil; resetSuccess = false; newPin = ""; confirmNewPin = ""; resetEmail = ""; enteringConfirmReset = false } } label: {
                    HStack(spacing: 4) { Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold)); Text("Back").font(.system(size: 16)) }.foregroundStyle(Color.secondary)
                }; Spacer()
            }.padding(.horizontal, 20).padding(.top, 16)
            Spacer()
            if resetSuccess {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 56)).foregroundStyle(Color.bhqGreen).padding(.bottom, 12)
                Text("PIN Reset!").font(.system(size: 24, weight: .bold)).padding(.bottom, 8)
                Text(resetMessage ?? "").font(.system(size: 14)).foregroundStyle(Color.secondary).multilineTextAlignment(.center).padding(.horizontal, 32)
                Button { withAnimation { step = authState.isRememberedDevice ? .pin : .emailPin; pin = ""; showError = false; resetSuccess = false } } label: {
                    Text("Sign In Now").font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14).background(Color.bhqGreen).clipShape(RoundedRectangle(cornerRadius: 12))
                }.padding(.horizontal, 32).padding(.top, 20)
            } else if resetEmail.isEmpty {
                Image(systemName: "person.badge.shield.checkmark").font(.system(size: 48)).foregroundStyle(RoleTheme.admin.primary).padding(.bottom, 12)
                Text("Verify Your Identity").font(.system(size: 22, weight: .bold)).padding(.bottom, 8)
                Text("Sign in to verify you're the admin.").font(.system(size: 14)).foregroundStyle(Color.secondary).multilineTextAlignment(.center).padding(.horizontal, 32)
                
                // Apple Sign In for reset
                AppleSignInButton {
                    appleSignInService.signIn { email, fullName, appleId in
                        resetEmail = email
                    }
                }
                .padding(.horizontal, 32).padding(.top, 16)
                
                // Google Sign In for reset
                Button { googleSignInForReset() } label: {
                    HStack(spacing: 10) {
                        if isGoogleSigningIn { ProgressView().tint(Color.white) } else { Image(systemName: "g.circle.fill").font(.system(size: 20)) }
                        Text(isGoogleSigningIn ? "Verifying..." : "Sign in with Google").font(.system(size: 16, weight: .semibold))
                    }.foregroundStyle(Color.white).frame(maxWidth: .infinity).padding(.vertical, 14).background(Color.bhqBlue).clipShape(RoundedRectangle(cornerRadius: 12))
                }.disabled(isGoogleSigningIn).padding(.horizontal, 32).padding(.top, 8)
                if let msg = resetMessage, !resetSuccess { Text(msg).font(.system(size: 13, weight: .medium)).foregroundStyle(Color.bhqTint).padding(.top, 8) }
            } else {
                Image(systemName: "lock.rotation").font(.system(size: 48)).foregroundStyle(Color.bhqBlue).padding(.bottom, 12)
                Text("Set New PIN").font(.system(size: 22, weight: .bold)).padding(.bottom, 4)
                Text(resetEmail).font(.system(size: 13)).foregroundStyle(Color.secondary).padding(.bottom, 16)
                Text(enteringConfirmReset ? "Confirm New PIN" : "Enter New PIN").font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(enteringConfirmReset ? Color.bhqGreen : Color.bhqBlue)
                HStack(spacing: 16) {
                    let currentPin = enteringConfirmReset ? confirmNewPin : newPin
                    ForEach(0..<4, id: \.self) { index in
                        Circle().fill(index < currentPin.count ? (enteringConfirmReset ? Color.bhqGreen : Color.bhqBlue) : Color.clear).frame(width: 18, height: 18)
                            .overlay(Circle().stroke(index < currentPin.count ? (enteringConfirmReset ? Color.bhqGreen : Color.bhqBlue) : Color.secondary.opacity(0.3), lineWidth: 1.5))
                    }
                }.padding(.bottom, 8)
                if let msg = resetMessage, !resetSuccess { Text(msg).font(.system(size: 13, weight: .medium)).foregroundStyle(Color.bhqTint) }
            }
            Spacer()
            if !resetEmail.isEmpty && !resetSuccess {
                resetPinPad.padding(.bottom, 16)
                Button { submitPinReset() } label: {
                    Text("Reset PIN").font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(newPin.count == 4 && confirmNewPin.count == 4 ? Color.bhqBlue : Color.secondary.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }.disabled(newPin.count != 4 || confirmNewPin.count != 4).padding(.horizontal, 24).padding(.bottom, 40)
            }
        }
    }
    
    private var resetPinPad: some View {
        VStack(spacing: 10) {
            ForEach(0..<3) { row in HStack(spacing: 20) { ForEach(1...3, id: \.self) { col in let num = row * 3 + col; pinButton("\(num)") { appendResetDigit("\(num)") } } } }
            HStack(spacing: 20) {
                pinButton("↺", isSystem: true) { newPin = ""; confirmNewPin = ""; enteringConfirmReset = false; resetMessage = nil }
                pinButton("0") { appendResetDigit("0") }
                pinButton("⌫", isSystem: true) {
                    if enteringConfirmReset { if !confirmNewPin.isEmpty { confirmNewPin.removeLast() } else { enteringConfirmReset = false } }
                    else { if !newPin.isEmpty { newPin.removeLast() } }; resetMessage = nil
                }
            }
        }
    }
    
    private func appendResetDigit(_ digit: String) {
        resetMessage = nil
        if !enteringConfirmReset { guard newPin.count < 4 else { return }; newPin += digit
            if newPin.count == 4 { DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { withAnimation { enteringConfirmReset = true } } }
        } else { guard confirmNewPin.count < 4 else { return }; confirmNewPin += digit }
    }
    
    private func googleSignInForReset() {
        isGoogleSigningIn = true; resetMessage = nil
        Task {
            do { let result = try await GoogleSignInService.shared.signIn()
                await MainActor.run { resetEmail = result.email; isGoogleSigningIn = false }
            } catch { await MainActor.run { resetMessage = "Google sign-in failed"; isGoogleSigningIn = false } }
        }
    }
    
    private func submitPinReset() {
        if newPin != confirmNewPin { resetMessage = "PINs don't match"; newPin = ""; confirmNewPin = ""; enteringConfirmReset = false; return }
        Task {
            let result = await authState.adminResetPin(email: resetEmail, newPin: newPin)
            await MainActor.run { resetMessage = result.message; resetSuccess = result.success }
        }
    }
    
    // MARK: - Master Picker
    private var masterPickerPage: some View {
        VStack(spacing: 0) {
            HStack {
                Button { authState.exitMasterMode(); withAnimation(.easeInOut(duration: 0.3)) { step = authState.isRememberedDevice ? .pin : .emailPin } } label: {
                    HStack(spacing: 4) { Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold)); Text("Back").font(.system(size: 16)) }.foregroundStyle(Color.secondary)
                }; Spacer()
            }.padding(.horizontal, 20).padding(.top, 16)
            VStack(spacing: 12) {
                Image(systemName: "shield.lefthalf.filled.badge.checkmark").font(.system(size: 40)).foregroundStyle(Color(red: 1, green: 0.42, blue: 0.1)).padding(.top, 24)
                Text("Developer Access").font(.system(size: 24, weight: .bold))
                Text("Select an organization").font(.system(size: 14)).foregroundStyle(Color.secondary)
            }.padding(.bottom, 20)
            if authState.masterModeOrgs.isEmpty {
                Spacer()
                Image(systemName: "building.2.slash").font(.system(size: 36)).foregroundStyle(Color.secondary.opacity(0.4))
                Text("No organizations found").font(.system(size: 16, weight: .medium)).foregroundStyle(Color.secondary)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(authState.masterModeOrgs.enumerated()), id: \.element.id) { index, org in
                            Button { enterOrg(code: org.id) } label: {
                                HStack(spacing: 14) {
                                    Text(String(org.name.prefix(1))).font(.system(size: 18, weight: .bold)).foregroundStyle(Color(red: 1, green: 0.42, blue: 0.1))
                                        .frame(width: 44, height: 44).background(Color(red: 1, green: 0.42, blue: 0.1).opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 12))
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(org.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.primary)
                                        HStack(spacing: 12) {
                                            HStack(spacing: 4) { Image(systemName: "crown.fill").font(.system(size: 9)).foregroundStyle(RoleTheme.admin.primary); Text(org.adminName).font(.system(size: 12)).foregroundStyle(Color.secondary) }
                                            HStack(spacing: 4) { Image(systemName: "person.3.fill").font(.system(size: 9)).foregroundStyle(Color.secondary); Text("\(org.memberCount)").font(.system(size: 12)).foregroundStyle(Color.secondary) }
                                        }
                                        Text(org.id).font(.system(size: 11, design: .monospaced)).foregroundStyle(Color.secondary.opacity(0.5))
                                    }; Spacer()
                                    if masterLoading == org.id { ProgressView().tint(Color.secondary) }
                                    else { Image(systemName: "arrow.right.circle.fill").font(.system(size: 20)).foregroundStyle(Color(red: 1, green: 0.42, blue: 0.1)) }
                                }.padding(14).background(Color.bhqCard).contentShape(Rectangle())
                            }.buttonStyle(.plain).disabled(masterLoading != nil)
                            if index < authState.masterModeOrgs.count - 1 { Divider().padding(.leading, 72) }
                        }
                    }.clipShape(RoundedRectangle(cornerRadius: 14)).padding(.horizontal)
                }
            }
        }
    }
    
    private func enterOrg(code: String) {
        masterLoading = code
        Task { let _ = await authState.masterLoginToOrg(code: code); await MainActor.run { masterLoading = nil } }
    }
    
    private func animateLanding() {
        logoScale = 0.8; logoOpacity = 0; buttonsOpacity = 0
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) { logoScale = 1.0; logoOpacity = 1.0 }
        withAnimation(.easeOut(duration: 0.6).delay(0.6)) { buttonsOpacity = 1.0 }
    }
    
    private var valorLogo: some View {
        Image("SplashLogo")
            .resizable()
            .scaledToFit()
    }
}

#Preview { PinLoginView().environmentObject(AuthState()).preferredColorScheme(.dark) }
