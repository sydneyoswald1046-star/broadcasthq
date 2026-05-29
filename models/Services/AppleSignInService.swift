import AuthenticationServices
import Combine
import SwiftUI
import CryptoKit
import FirebaseAuth

class AppleSignInService: NSObject, ObservableObject {
    @Published var isSigningIn: Bool = false
    @Published var errorMessage: String?
    
    private var currentNonce: String?
    var onComplete: ((String, String, String) -> Void)?  // (email, fullName, appleUserId)
    
    // MARK: - Start Sign In
    
    func signIn(onComplete: @escaping (String, String, String) -> Void) {
        self.onComplete = onComplete
        isSigningIn = true
        errorMessage = nil
        
        let nonce = randomNonceString()
        currentNonce = nonce
        
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.performRequests()
    }
    
    // MARK: - Nonce Generation
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { byte in charset[Int(byte) % charset.count] })
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AppleSignInService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            let userId = appleIDCredential.user
            let email = appleIDCredential.email ?? "\(userId.prefix(8))@privaterelay.appleid.com"
            
            var fullName = "Apple User"
            if let nameComponents = appleIDCredential.fullName {
                let first = nameComponents.givenName ?? ""
                let last = nameComponents.familyName ?? ""
                if !first.isEmpty || !last.isEmpty {
                    fullName = "\(first) \(last)".trimmingCharacters(in: .whitespaces)
                }
            }
            
            DispatchQueue.main.async {
                self.isSigningIn = false
                self.onComplete?(email, fullName, userId)
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        DispatchQueue.main.async {
            self.isSigningIn = false
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
                // User cancelled — not an error
                return
            }
            self.errorMessage = "Sign in failed. Please try again."
            print("❌ Apple Sign In error: \(error)")
        }
    }
}

// MARK: - SwiftUI Button

struct AppleSignInButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 18, weight: .semibold))
                Text("Sign in with Apple")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
        }
    }
}
