import SwiftUI
import Combine
import FirebaseFirestore

struct ProfileAvatar: View {
    let userId: String
    let initials: String
    let size: CGFloat
    var color: Color = .secondary
    var showStatus: Bool = false
    var status: PresenceStatus = .online
    
    @StateObject private var loader = AvatarLoader()
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Text(initials)
                    .font(.system(size: size * 0.38, weight: .bold))
                    .foregroundStyle(color)
                    .frame(width: size, height: size)
                    .background(color.opacity(0.12))
                    .clipShape(Circle())
            }
            
            if showStatus {
                Circle()
                    .fill(statusColor)
                    .frame(width: size * 0.25, height: size * 0.25)
                    .overlay(Circle().stroke(Color.bhqBackground, lineWidth: 2))
            }
        }
        .onAppear { loader.load(userId: userId) }
        .onChange(of: userId) { _, newId in loader.load(userId: newId) }
    }
    
    private var statusColor: Color {
        switch status {
        case .online: return Color.bhqGreen
        case .busy: return Color.bhqYellow
        case .offline: return Color(.systemGray3)
        }
    }
}

class AvatarLoader: ObservableObject {
    @Published var image: UIImage?
    private var loadedUserId: String?
    private var isLoading: Bool = false
    private var hasAttempted: Bool = false
    
    func load(userId: String) {
        guard userId != loadedUserId || (!hasAttempted && image == nil) else { return }
        guard !isLoading else { return }
        loadedUserId = userId
        
        if let cached = ProfileImageService.shared.getCached(userId: userId) {
            image = cached
            hasAttempted = true
            return
        }
        
        isLoading = true
        hasAttempted = true
        let orgCode = FirestoreService.shared.orgCode
        guard !orgCode.isEmpty else { isLoading = false; return }
        
        Task {
            let loaded = await ProfileImageService.shared.getProfileImage(userId: userId, orgCode: orgCode)
            await MainActor.run {
                self.image = loaded
                self.isLoading = false
            }
        }
    }
}
