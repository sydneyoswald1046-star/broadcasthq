import AVFoundation
import Combine
import MultipeerConnectivity
import SwiftUI

class PTTAudioService: NSObject, ObservableObject {
    static let shared = PTTAudioService()
    
    @Published var connectedPeers: Int = 0
    @Published var connectedPeerNames: [String] = []
    @Published var isReceivingAudio: Bool = false
    @Published var receivingFromName: String = ""
    @Published var lastError: String?
    
    // MultipeerConnectivity
    private var peerID: MCPeerID?
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    
    // Capture (mic → send)
    private var captureEngine: AVAudioEngine?
    private var isCapturing: Bool = false
    
    // Playback (receive → speaker) — kept alive independently
    private var playbackEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var playbackFormat: AVAudioFormat?
    private var isPlaybackReady: Bool = false
    
    private var isStarted: Bool = false
    private var micPermissionGranted: Bool = false
    
    private var currentOrgCode: String = ""
    private var currentUserId: String = ""
    private var currentUserTeam: String = ""
    private var targetChannel: String = "global"
    
    // Silence detection — only updates UI, doesn't tear down engine
    private var silenceTimer: DispatchWorkItem?
    private var lastAudioReceived: Date = .distantPast
    
    // Audio route change observer
    private var routeChangeObserver: Any?
    
    override init() {
        super.init()
        checkMicPermission()
    }
    
    private func checkMicPermission() {
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                self?.micPermissionGranted = granted
                if !granted { self?.lastError = "Mic permission denied" }
            }
        }
    }
    
    // MARK: - Start / Stop
    
    func start(orgCode: String, userName: String, userId: String, userTeam: String = "", userRole: String = "") {
        guard !isStarted else { return }
        
        currentOrgCode = orgCode
        currentUserId = userId
        currentUserTeam = userTeam
        currentUserRole = userRole
        
        // MCPeerID crashes if displayName is empty or > 63 characters
        var displayName = "\(userName)|\(userId)|\(userTeam)"
        if displayName.isEmpty { displayName = "user-\(UUID().uuidString.prefix(8))" }
        if displayName.count > 63 { displayName = String(displayName.prefix(63)) }
        
        peerID = MCPeerID(displayName: displayName)
        guard let pid = peerID else { return }
        
        session = MCSession(peer: pid, securityIdentity: nil, encryptionPreference: .none)
        session?.delegate = self
        
        let svc = "valorlive-ptt"
        
        advertiser = MCNearbyServiceAdvertiser(peer: pid, discoveryInfo: ["org": orgCode], serviceType: svc)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
        
        browser = MCNearbyServiceBrowser(peer: pid, serviceType: svc)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
        
        // Prepare playback engine on start so it's ready instantly
        preparePlaybackEngine()
        
        // Watch for audio route changes (headphones, Bluetooth)
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.handleRouteChange()
        }
        
        isStarted = true
    }
    
    func stop() {
        stopCapturing()
        
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        
        // Tear down playback
        playerNode?.stop()
        playbackEngine?.stop()
        playerNode = nil
        playbackEngine = nil
        isPlaybackReady = false
        playbackFormat = nil
        
        advertiser = nil; browser = nil; session = nil; peerID = nil
        isStarted = false
        
        if let obs = routeChangeObserver {
            NotificationCenter.default.removeObserver(obs)
            routeChangeObserver = nil
        }
        
        // Deactivate on background thread
        DispatchQueue.global(qos: .background).async {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
        
        DispatchQueue.main.async {
            self.connectedPeers = 0
            self.connectedPeerNames = []
            self.isReceivingAudio = false
        }
    }
    
    private var currentUserRole: String = ""
    
    // MARK: - Audio Session
    
    private func activateCaptureSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [
                .defaultToSpeaker,
                .allowBluetoothA2DP,
                .interruptSpokenAudioAndMixWithOthers
            ])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            DispatchQueue.main.async { self.lastError = "Audio setup failed" }
        }
    }
    
    private func activatePlaybackSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            if !isCapturing {
                try session.setCategory(.playAndRecord, mode: .default, options: [
                    .defaultToSpeaker,
                    .allowBluetoothA2DP,
                    .mixWithOthers
                ])
                try session.setActive(true)
            }
        } catch {
            // Silently fail
        }
    }
    
    private func handleRouteChange() {
        // Rebuild playback engine if route changed (headphones plugged in, etc.)
        if isPlaybackReady {
            preparePlaybackEngine()
        }
    }
    
    // MARK: - Capture (Mic → Send)
    
    func startCapturing(channel: String = "global") {
        guard !isCapturing, isStarted else { return }
        
        targetChannel = channel
        
        if !micPermissionGranted { checkMicPermission(); return }
        guard let session = session else { return }
        
        activateCaptureSession()
        
        captureEngine = AVAudioEngine()
        guard let engine = captureEngine else { return }
        
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        
        guard format.sampleRate > 0, format.channelCount > 0 else { return }
        
        // Send format info so receivers know what to expect
        sendFormatInfo(format, channel: channel, to: session.connectedPeers)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self = self, let session = self.session, !session.connectedPeers.isEmpty else { return }
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameCount = Int(buffer.frameLength)
            guard frameCount > 0 else { return }
            
            let channelBytes = self.targetChannel.data(using: .utf8) ?? Data()
            var data = Data([0x41, UInt8(channelBytes.count)])
            data.append(channelBytes)
            data.append(Data(bytes: channelData, count: frameCount * MemoryLayout<Float>.size))
            
            try? session.send(data, toPeers: session.connectedPeers, with: .unreliable)
        }
        
        do {
            try engine.start()
            isCapturing = true
        } catch {
            captureEngine?.inputNode.removeTap(onBus: 0)
            captureEngine = nil
        }
    }
    
    func stopCapturing() {
        guard isCapturing else { return }
        captureEngine?.inputNode.removeTap(onBus: 0)
        captureEngine?.stop()
        captureEngine = nil
        isCapturing = false
        targetChannel = "global"
        
        // Restore playback session and ensure engine is running
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self = self else { return }
            self.activatePlaybackSession()
            // Restart playback engine if it died during capture
            if let engine = self.playbackEngine, !engine.isRunning {
                try? engine.start()
                self.playerNode?.play()
            }
        }
    }
    
    private func sendFormatInfo(_ format: AVAudioFormat, channel: String, to peers: [MCPeerID]) {
        guard let session = session, !peers.isEmpty else { return }
        let channelBytes = channel.data(using: .utf8) ?? Data()
        var data = Data([0x46, UInt8(channelBytes.count)])
        data.append(channelBytes)
        var rate = format.sampleRate
        var channels = UInt32(format.channelCount)
        data.append(Data(bytes: &rate, count: 8))
        data.append(Data(bytes: &channels, count: 4))
        try? session.send(data, toPeers: peers, with: .reliable)
    }
    
    // MARK: - Playback Engine (kept alive, not torn down on silence)
    
    private func preparePlaybackEngine(sampleRate: Double = 48000, channels: UInt32 = 1) {
        // Don't rebuild if already running with same format
        if isPlaybackReady, let fmt = playbackFormat,
           fmt.sampleRate == sampleRate, fmt.channelCount == channels {
            return
        }
        
        // Tear down old engine
        playerNode?.stop()
        playbackEngine?.stop()
        
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: channels, interleaved: false) else { return }
        
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 1.0
        
        do {
            try engine.start()
            player.play()
            playbackEngine = engine
            playerNode = player
            playbackFormat = format
            isPlaybackReady = true
        } catch {
            playbackEngine = nil
            playerNode = nil
            isPlaybackReady = false
        }
    }
    
    // MARK: - Receive & Filter
    
    private func shouldPlayAudio(channel: String) -> Bool {
        // DM — only the target user hears
        if channel.hasPrefix("dm:") {
            return String(channel.dropFirst(3)) == currentUserId
        }
        
        // Global/all — everyone hears
        if channel == "global" || channel == "all" {
            return true
        }
        
        // Specific team channel — only that team + admin/producer hear
        if currentUserRole == "admin" || currentUserRole == "team_lead" {
            return true
        }
        let ch = channel == "choirlead" ? "choir" : channel
        let tm = currentUserTeam == "choirlead" ? "choir" : currentUserTeam
        return ch == tm
    }
    
    // MARK: - Play Received Audio
    
    private func playAudioData(_ data: Data, fromPeer name: String) {
        // Ensure playback is ready — rebuild if needed
        if !isPlaybackReady || playbackEngine == nil {
            activatePlaybackSession()
            preparePlaybackEngine()
        }
        
        // Recover if engine was stopped or interrupted
        if let engine = playbackEngine, !engine.isRunning {
            activatePlaybackSession()
            try? engine.start()
            playerNode?.play()
        }
        
        // Recover if player node stopped
        if let player = playerNode, !player.isPlaying {
            player.play()
        }
        
        guard let player = playerNode, let format = playbackFormat else { return }
        
        let frameCount = UInt32(data.count / MemoryLayout<Float>.size)
        guard frameCount > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount
        
        data.withUnsafeBytes { raw in
            if let src = raw.baseAddress?.assumingMemoryBound(to: Float.self), let dst = buffer.floatChannelData?[0] {
                dst.update(from: src, count: Int(frameCount))
            }
        }
        
        player.scheduleBuffer(buffer, completionHandler: nil)
        lastAudioReceived = Date()
        
        if !isReceivingAudio {
            DispatchQueue.main.async {
                self.isReceivingAudio = true
                self.receivingFromName = name
            }
        }
        
        silenceTimer?.cancel()
        let timer = DispatchWorkItem { [weak self] in
            DispatchQueue.main.async {
                self?.isReceivingAudio = false
            }
        }
        silenceTimer = timer
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: timer)
    }
    
    deinit { stop() }
}

// MARK: - MCSessionDelegate

extension PTTAudioService: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        let name = peerID.displayName.split(separator: "|").first.map(String.init) ?? peerID.displayName
        DispatchQueue.main.async {
            self.connectedPeers = session.connectedPeers.count
            self.connectedPeerNames = session.connectedPeers.map {
                $0.displayName.split(separator: "|").first.map(String.init) ?? $0.displayName
            }
            switch state {
            case .connected: self.lastError = nil
            case .notConnected: break
            case .connecting: break
            @unknown default: break
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard data.count > 2 else { return }
        let marker = data[0]
        let channelLen = Int(data[1])
        guard data.count > 2 + channelLen else { return }
        
        let channelData = data.subdata(in: 2..<(2 + channelLen))
        let channel = String(data: channelData, encoding: .utf8) ?? "global"
        let payload = data.subdata(in: (2 + channelLen)..<data.count)
        
        let name = peerID.displayName.split(separator: "|").first.map(String.init) ?? peerID.displayName
        
        if marker == 0x46 {
            // Format info
            guard shouldPlayAudio(channel: channel) else { return }
            guard payload.count >= 12 else { return }
            let rate: Double = payload.withUnsafeBytes { $0.load(fromByteOffset: 0, as: Double.self) }
            let channels: UInt32 = payload.withUnsafeBytes { $0.load(fromByteOffset: 8, as: UInt32.self) }
            preparePlaybackEngine(sampleRate: rate, channels: channels)
            
        } else if marker == 0x41 {
            // Audio data
            guard shouldPlayAudio(channel: channel) else { return }
            playAudioData(payload, fromPeer: name)
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - Advertiser

extension PTTAudioService: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Only accept from same org
        invitationHandler(true, session)
    }
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        DispatchQueue.main.async { self.lastError = "Network error" }
    }
}

// MARK: - Browser

extension PTTAudioService: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        let peerOrg = info?["org"] ?? ""
        guard peerOrg == currentOrgCode else { return }
        guard let session = session else { return }
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
    }
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        DispatchQueue.main.async { self.lastError = "Discovery error" }
    }
}
