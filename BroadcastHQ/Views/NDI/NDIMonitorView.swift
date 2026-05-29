import SwiftUI

struct NDIMonitorView: View {
    @StateObject private var ndi = NDIService.shared
    @State private var showSourcePicker: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            if ndi.isConnected {
                connectedView
            } else {
                disconnectedView
            }
        }
        .background(Color.black)
        .sheet(isPresented: $showSourcePicker) {
            sourcePickerSheet
        }
    }
    
    // MARK: - Connected View (showing video)
    private var connectedView: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.bhqGreen)
                    .frame(width: 8, height: 8)
                
                Text(ndi.connectedSourceName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                
                Spacer()
                
                if !ndi.resolution.isEmpty {
                    Text(ndi.resolution)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.secondary)
                }
                
                if !ndi.frameRate.isEmpty {
                    Text(ndi.frameRate)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.secondary)
                }
                
                Button { showSourcePicker = true } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.bhqBlue)
                }
                
                Button { ndi.disconnect() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.secondary.opacity(0.5))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(white: 0.08))
            
            // Video preview
            ZStack {
                Color.black
                
                if let frame = ndi.currentFrame {
                    Image(decorative: frame, scale: 1.0)
                        .resizable()
                        .scaledToFit()
                } else {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(Color.white)
                        Text("Connecting...")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Bottom bar
            HStack(spacing: 16) {
                Image(systemName: "video.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.bhqGreen)
                
                Text("NDI")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.bhqGreen)
                    .tracking(2)
                
                Spacer()
                
                if let error = ndi.lastError {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.bhqTint)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(white: 0.08))
        }
    }
    
    // MARK: - Disconnected View
    private var disconnectedView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // NDI logo area
            ZStack {
                Circle()
                    .fill(Color(white: 0.08))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "video.badge.waveform")
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(Color.bhqBlue.opacity(0.7))
            }
            
            VStack(spacing: 8) {
                Text("NDI Monitor")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.white)
                
                Text("View a live video source from your broadcast network")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            // Search / Connect button
            Button {
                ndi.startSearching()
                showSourcePicker = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 16))
                    Text("Find Sources")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.bhqBlue)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 40)
            
            if let error = ndi.lastError {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.bhqTint)
            }
            
            // Instructions
            VStack(alignment: .leading, spacing: 12) {
                instructionRow(number: "1", text: "Make sure your NDI source is on the same WiFi network")
                instructionRow(number: "2", text: "Tap Find Sources to discover available streams")
                instructionRow(number: "3", text: "Select a source to start monitoring")
            }
            .padding(.horizontal, 30)
            .padding(.top, 10)
            
            Spacer()
            Spacer()
        }
    }
    
    private func instructionRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.bhqBlue)
                .frame(width: 22, height: 22)
                .background(Color.bhqBlue.opacity(0.12))
                .clipShape(Circle())
            
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Color.secondary)
        }
    }
    
    // MARK: - Source Picker Sheet
    private var sourcePickerSheet: some View {
        NavigationStack {
            Group {
                if ndi.isSearching {
                    VStack(spacing: 16) {
                        Spacer().frame(height: 40)
                        ProgressView()
                        Text("Searching for NDI sources...")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.secondary)
                        Spacer()
                    }
                } else if ndi.availableSources.isEmpty {
                    VStack(spacing: 16) {
                        Spacer().frame(height: 40)
                        Image(systemName: "antenna.radiowaves.left.and.right.slash")
                            .font(.system(size: 36, weight: .light))
                            .foregroundStyle(Color.secondary.opacity(0.3))
                        Text("No Sources Found")
                            .font(.system(size: 17, weight: .semibold))
                        Text("Make sure your NDI source is running and on the same network.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Button {
                            ndi.startSearching()
                        } label: {
                            Text("Search Again")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.bhqBlue)
                        }
                        .padding(.top, 8)
                        
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(Array(ndi.availableSources.enumerated()), id: \.offset) { _, source in
                            Button {
                                ndi.connect(to: source)
                                showSourcePicker = false
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: "video.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.bhqBlue)
                                        .frame(width: 36, height: 36)
                                        .background(Color.bhqBlue.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(source)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(Color.primary)
                                        Text("NDI Source")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if ndi.connectedSourceName == source {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color.bhqGreen)
                                    } else {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(Color.secondary.opacity(0.3))
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("NDI Sources")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { ndi.startSearching() } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(Color.bhqBlue)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showSourcePicker = false }
                        .foregroundStyle(Color.secondary)
                }
            }
        }
    }
}

#Preview {
    NDIMonitorView()
        .preferredColorScheme(.dark)
}
