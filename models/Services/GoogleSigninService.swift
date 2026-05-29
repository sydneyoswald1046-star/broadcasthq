import Foundation
import GoogleSignIn
import FirebaseCore

struct GoogleSignInResult {
    let email: String
    let fullName: String
    let firstName: String
    let lastName: String
}

class GoogleSignInService {
    static let shared = GoogleSignInService()
    
    func signIn() async throws -> GoogleSignInResult {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw GoogleSignInError.noClientID
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        guard let windowScene = await MainActor.run(body: {
            UIApplication.shared.connectedScenes.first as? UIWindowScene
        }),
        let rootViewController = await MainActor.run(body: {
            windowScene.windows.first?.rootViewController
        }) else {
            throw GoogleSignInError.noRootVC
        }
        
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
        let user = result.user
        
        let email = user.profile?.email ?? ""
        let fullName = user.profile?.name ?? ""
        let firstName = user.profile?.givenName ?? ""
        let lastName = user.profile?.familyName ?? ""
        
        return GoogleSignInResult(email: email, fullName: fullName, firstName: firstName, lastName: lastName)
    }
}

enum GoogleSignInError: LocalizedError {
    case noClientID
    case noRootVC
    
    var errorDescription: String? {
        switch self {
        case .noClientID: return "Firebase Client ID not found"
        case .noRootVC: return "No root view controller available"
        }
    }
}
