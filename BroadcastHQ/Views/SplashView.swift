import SwiftUI

struct SplashView: View {
    @State private var imageOpacity: Double = 0
    @State private var imageScale: CGFloat = 1.05
    @State private var sloganOpacity: Double = 0
    
    let onFinished: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            Image("SplashLogo")
                .resizable()
                .scaledToFit()
                .opacity(imageOpacity)
                .scaleEffect(imageScale)
        }
        .ignoresSafeArea()
        .onAppear { runAnimation() }
    }
    
    private func runAnimation() {
        // Image fades in with subtle scale
        withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
            imageOpacity = 1
            imageScale = 1.0
        }
        
        // Slogan fades in
        withAnimation(.easeOut(duration: 0.6).delay(1.0)) {
            sloganOpacity = 1
        }
        
        // Transition to app
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            onFinished()
        }
    }
}

#Preview {
    SplashView(onFinished: {})
}
