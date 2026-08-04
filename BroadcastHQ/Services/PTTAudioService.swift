import AVFoundation
import Combine
import MultipeerConnectivity
import SwiftUI
import os

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

    // Dedicated queue for MPC sends — keeps work off the real-time audio thread
    private let sendQueue = DispatchQueue(label: "ptt.send", qos: .userInteractive)

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

    // Playback queue depth management — prevents latency buildup
    // Lock-protected to avoid data races between MPC receive thread and audio completion callback
    private var _scheduledBufferCount: Int32 = 0
    private let bufferCountLock = OSAllocatedUnfairLock()
    private let maxQueuedBuffers: Int32 = 3

    // Capture format for resending to late-joining peers
    private var captureFormat: AVAudioFormat?

    // Delayed work item for post-capture session restore (cancelled on rapid re-capture)
    private var postCaptureRestore: DispatchWorkItem?

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
        
        // displayName carries routing info: "name|userId|team|role". MCPeerID crashes
        // if it's empty or > 63 chars, so truncate only the name part if needed.
        let safeName = userName.isEmpty ? "user-\(UUID().uuidString.prefix(8))" : userName
        let suffix = "|\(userId)|\(userTeam)|\(userRole)"
        var displayName = safeName + suffix
        if displayName.count > 63 {
            let maxName = max(1, 63 - suffix.count)
            displayName = String(safeName.prefix(maxName)) + suffix
        }

        peerID = MCPeerID(displayName: displayName)
        guard let pid = peerID else { return }

        // .required → audio is encrypted on the wire between peers.
        session = MCSession(peer: pid, securityIdentity: nil, encryptionPreference: .required)
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
        AudioNoiseProcessor.configureSessionForNoiseCancellation()
    }
    
    private func activatePlaybackSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            if !isCapturing {
                try session.setCategory(.playAndRecord, mode: .voiceChat, options: [
                    .defaultToSpeaker,
                    .allowBluetooth,
                    .allowBluetoothA2DP,
                    .mixWithOthers
                ])
                try session.setPreferredIOBufferDuration(0.002)
                try session.setActive(true)
            }
        } catch {
            // Silently fail
        }
    }
    
    private func handleRouteChange() {
        AudioNoiseProcessor.preferBluetoothInputIfAvailable()
        if isPlaybackReady {
            preparePlaybackEngine()
        }
    }
    
    // MARK: - Capture (Mic → Send)
    
    func startCapturing(channel: String = "global") {
        guard !isCapturing, isStarted else { return }

        postCaptureRestore?.cancel()
        postCaptureRestore = nil
        targetChannel = channel

        if !micPermissionGranted { checkMicPermission(); return }
        guard let session = session else { return }
        
        activateCaptureSession()
        
        captureEngine = AVAudioEngine()
        guard let engine = captureEngine else { return }

        let inputNode = engine.inputNode

        // Enable Apple's hardware-accelerated voice processing (AEC + NS + AGC)
        AudioNoiseProcessor.enableVoiceProcessing(on: inputNode)

        let format = inputNode.outputFormat(forBus: 0)

        guard format.sampleRate > 0, format.channelCount > 0 else { return }

        captureFormat = format

        // Send format info only to the peers that should receive this channel.
        sendFormatInfo(format, channel: channel, to: targetPeers(for: channel, among: session.connectedPeers))

        // 256 frames at 48 kHz ≈ 5.3 ms per buffer — minimal capture latency.
        // Apple Voice Processing on inputNode already handles AEC + NS + AGC,
        // so skip the custom noise processor to avoid redundant per-sample work.
        inputNode.installTap(onBus: 0, bufferSize: 256, format: format) { [weak self] buffer, _ in
            guard let self = self, let session = self.session, !session.connectedPeers.isEmpty else { return }
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameCount = Int(buffer.frameLength)
            guard frameCount > 0 else { return }

            let targets = self.targetPeers(for: self.targetChannel, among: session.connectedPeers)
            guard !targets.isEmpty else { return }

            // Copy audio data and dispatch MPC send off the real-time audio thread
            let channelBytes = self.targetChannel.data(using: .utf8) ?? Data()
            var data = Data([0x41, UInt8(channelBytes.count)])
            data.append(channelBytes)
            data.append(Data(bytes: channelData, count: frameCount * MemoryLayout<Float>.size))

            self.sendQueue.async {
                try? session.send(data, toPeers: targets, with: .unreliable)
            }
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
        captureFormat = nil

        postCaptureRestore?.cancel()
        let restore = DispatchWorkItem { [weak self] in
            guard let self = self, !self.isCapturing else { return }
            self.activatePlaybackSession()
            if let engine = self.playbackEngine, !engine.isRunning {
                try? engine.start()
                self.playerNode?.play()
            }
        }
        postCaptureRestore = restore
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: restore)
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
        bufferCountLock.withLock { _scheduledBufferCount = 0 }
        
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
    
    // MARK: - Send targeting (which peers receive this channel)

    /// Peers that should receive audio for `channel`. Routing is enforced here at the
    /// send level (not just receiver-side), so a team only ever gets its own channel.
    private func targetPeers(for channel: String, among peers: [MCPeerID]) -> [MCPeerID] {
        if channel == "global" || channel == "all" { return peers }

        if channel.hasPrefix("dm:") {
            let uid = String(channel.dropFirst(3))
            return peers.filter { Self.peerUserId($0) == uid }
        }

        // Team channel — that team, plus admins/team_leads who monitor everything.
        let ch = channel == "choirlead" ? "choir" : channel
        return peers.filter { peer in
            let role = Self.peerRole(peer)
            if role == "admin" || role == "team_lead" { return true }
            let tm = Self.peerTeam(peer) == "choirlead" ? "choir" : Self.peerTeam(peer)
            return tm == ch
        }
    }

    private static func peerField(_ peer: MCPeerID, _ index: Int) -> String {
        let parts = peer.displayName.split(separator: "|", omittingEmptySubsequences: false)
        return index < parts.count ? String(parts[index]) : ""
    }
    private static func peerUserId(_ peer: MCPeerID) -> String { peerField(peer, 1) }
    private static func peerTeam(_ peer: MCPeerID) -> String { peerField(peer, 2) }
    private static func peerRole(_ peer: MCPeerID) -> String { peerField(peer, 3) }

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

        // Drop incoming audio if too many buffers queued — keeps latency tight
        let currentCount = bufferCountLock.withLock { _scheduledBufferCount }
        guard currentCount < maxQueuedBuffers else { return }

        let frameCount = UInt32(data.count / MemoryLayout<Float>.size)
        guard frameCount > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount

        data.withUnsafeBytes { raw in
            if let src = raw.baseAddress?.assumingMemoryBound(to: Float.self), let dst = buffer.floatChannelData?[0] {
                dst.update(from: src, count: Int(frameCount))
            }
        }

        bufferCountLock.withLock { _scheduledBufferCount += 1 }
        player.scheduleBuffer(buffer) { [weak self] in
            guard let self = self else { return }
            self.bufferCountLock.withLock { self._scheduledBufferCount -= 1 }
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if !self.isReceivingAudio {
                self.isReceivingAudio = true
                self.receivingFromName = name
            }
            self.silenceTimer?.cancel()
            let timer = DispatchWorkItem { [weak self] in
                self?.isReceivingAudio = false
            }
            self.silenceTimer = timer
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: timer)
        }
    }
    
    deinit { stop() }
}

// MARK: - MCSessionDelegate

extension PTTAudioService: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        // Send format info to newly connected peers so late joiners get the right playback format
        if state == .connected, isCapturing, let fmt = captureFormat {
            sendFormatInfo(fmt, channel: targetChannel, to: [peerID])
        }

        let name = peerID.displayName.split(separator: "|").first.map(String.init) ?? peerID.displayName
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
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
        // Only accept peers from the same org (church). The inviter puts its org code
        // in the context; reject anything that doesn't match so Church B never joins
        // Church A's audio session.
        let theirOrg = context.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        guard !currentOrgCode.isEmpty, theirOrg == currentOrgCode else {
            invitationHandler(false, nil)
            return
        }
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
        // Carry our org in the context so the other side can verify on accept.
        browser.invitePeer(peerID, to: session, withContext: currentOrgCode.data(using: .utf8), timeout: 10)
    }
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        DispatchQueue.main.async { self.lastError = "Discovery error" }
    }
}
