import SwiftUI
import Combine
import FirebaseFirestore

class ProfileImageService: ObservableObject {
    static let shared = ProfileImageService()
    
    private let db = Firestore.firestore()
    private var imageCache: [String: UIImage] = [:]
    
    // MARK: - Upload (saves to Firestore as base64)
    
    func uploadProfileImage(_ image: UIImage, orgCode: String, userId: String) async throws -> String {
        let resized = resizeImage(image, maxSize: 200)
        guard let resizedData = resized.jpegData(compressionQuality: 0.4) else {
            throw NSError(domain: "ProfileImage", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to resize image"])
        }
        
        let base64 = resizedData.base64EncodedString()
        
        try await db.collection("organizations").document(orgCode).collection("users").document(userId).updateData([
            "profileImage": base64
        ])
        
        imageCache[userId] = resized
        
        return base64
    }
    
    // MARK: - Download
    
    func getProfileImage(userId: String, orgCode: String) async -> UIImage? {
        if let cached = imageCache[userId] { return cached }
        
        guard !orgCode.isEmpty else { return nil }
        
        do {
            let doc = try await db.collection("organizations").document(orgCode)
                .collection("users").document(userId).getDocument()
            
            if let base64 = doc.data()?["profileImage"] as? String,
               let data = Data(base64Encoded: base64),
               let image = UIImage(data: data) {
                imageCache[userId] = image
                return image
            }
        } catch {
            print("❌ Profile image fetch error: \(error)")
        }
        
        return nil
    }
    
    // MARK: - Cache
    
    func getCached(userId: String) -> UIImage? {
        return imageCache[userId]
    }
    
    func cacheImage(_ image: UIImage, for userId: String) {
        imageCache[userId] = image
    }
    
    func clearCache() {
        imageCache.removeAll()
    }
    
    // MARK: - Resize
    
    private func resizeImage(_ image: UIImage, maxSize: CGFloat) -> UIImage {
        let size = image.size
        let ratio = min(maxSize / size.width, maxSize / size.height)
        if ratio >= 1 { return image }
        
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
