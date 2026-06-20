import AVFoundation
import Combine
import FirebaseFirestore

// NOTE: The WebRTC SPM package (https://github.com/nicklemann/WebRTC.git) must be
// added via Xcode: File → Add Package Dependencies → paste the URL above → Add Package.
// Select the "WebRTC" library and add it to the BroadcastHQ target.
// Once the package is resolved, remove this comment and uncomment the import below.
// import WebRTC

// ---------------------------------------------------------------------------
// Temporary stubs — replace with real WebRTC types once the package is added.
// These allow the file to compile and type-check without the package present.
// ---------------------------------------------------------------------------

#if canImport(WebRTC)
import WebRTC
#else

// MARK: - WebRTC Stubs (compile-time only — replaced by real package at runtime)

typealias RTCPeerConnectionFactory = _StubRTCPeerConnectionFactory
typealias RTCPeerConnection = _StubRTCPeerConnection
typealias RTCAudioTrack = _StubRTCAudioTrack
typealias RTCMediaConstraints = _StubRTCMediaConstraints
typealias RTCConfiguration = _StubRTCConfiguration
typealias RTCIceServer = _StubRTCIceServer
typealias RTCSessionDescription = _StubRTCSessionDescription
typealias RTCIceCandidate = _StubRTCIceCandidate
typealias RTCAudioSession = _StubRTCAudioSession
typealias RTCAudioSessionConfiguration = _StubRTCAudioSessionConfiguration
typealias RTCDefaultVideoEncoderFactory = _StubRTCDefaultVideoEncoderFactory
typealias RTCDefaultVideoDecoderFactory = _StubRTCDefaultVideoDecoderFactory
typealias RTCMediaStream = _StubRTCMediaStream
typealias RTCDataChannel = _StubRTCDataChannel
typealias RTCIceConnectionState = _StubRTCIceConnectionState
typealias RTCSignalingState = _StubRTCSignalingState
typealias RTCIceGatheringState = _StubRTCIceGatheringState
typealias RTCSdpSemantics = _StubRTCSdpSemantics

func RTCInitializeSSL() {}

enum _StubRTCIceConnectionState { case disconnected, failed, closed, connected, checking, completed, count, new }
enum _StubRTCSignalingState { case stable, haveLocalOffer, haveLocalPrAnswer, haveRemoteOffer, haveRemotePrAnswer, closed }
enum _StubRTCIceGatheringState { case new, gathering, complete }
enum _StubRTCSdpSemantics { case planB, unifiedPlan }
enum _StubRTCSdpType { case offer, pranswer, answer, rollback }

final class _StubRTCIceServer {
    init(urlStrings: [String]) {}
}

final class _StubRTCAudioSessionConfiguration {
    var category: String = ""
    var categoryOptions: UInt = 0
    var mode: String = ""
    static func webRTC() -> _StubRTCAudioSessionConfiguration { _StubRTCAudioSessionConfiguration() }
}

final class _StubRTCAudioSession {
    static func sharedInstance() -> _StubRTCAudioSession { _StubRTCAudioSession() }
    var isAudioEnabled: Bool = false
    func lockForConfiguration() {}
    func unlockForConfiguration() {}
    func setConfiguration(_ config: _StubRTCAudioSessionConfiguration) throws {}
}

final class _StubRTCDefaultVideoEncoderFactory {}
final class _StubRTCDefaultVideoDecoderFactory {}

final class _StubRTCMediaConstraints {
    init(mandatoryConstraints: [String: String]?, optionalConstraints: [String: String]?) {}
}

final class _StubRTCConfiguration {
    var iceServers: [_StubRTCIceServer] = []
    var sdpSemantics: _StubRTCSdpSemantics = .unifiedPlan
}

final class _StubRTCAudioTrack {
    var isEnabled: Bool = true
}

final class _StubRTCMediaStream {}
final class _StubRTCDataChannel {}

final class _StubRTCSessionDescription {
    let type: _StubRTCSdpType
    let sdp: String
    init(type: _StubRTCSdpType, sdp: String) {
        self.type = type
        self.sdp = sdp
    }
}

final class _StubRTCIceCandidate {
    let sdp: String
    let sdpMLineIndex: Int32
    let sdpMid: String?
    init(sdp: String, sdpMLineIndex: Int32, sdpMid: String?) {
        self.sdp = sdp
        self.sdpMLineIndex = sdpMLineIndex
        self.sdpMid = sdpMid
    }
}

protocol _StubRTCPeerConnectionDelegate: AnyObject {
    func peerConnection(_ peerConnection: _StubRTCPeerConnection, didChange stateChanged: _StubRTCSignalingState)
    func peerConnection(_ peerConnection: _StubRTCPeerConnection, didAdd stream: _StubRTCMediaStream)
    func peerConnection(_ peerConnection: _StubRTCPeerConnection, didRemove stream: _StubRTCMediaStream)
    func peerConnectionShouldNegotiate(_ peerConnection: _StubRTCPeerConnection)
    func peerConnection(_ peerConnection: _StubRTCPeerConnection, didChange newState: _StubRTCIceConnectionState)
    func peerConnection(_ peerConnection: _StubRTCPeerConnection, didChange newState: _StubRTCIceGatheringState)
    func peerConnection(_ peerConnection: _StubRTCPeerConnection, didGenerate candidate: _StubRTCIceCandidate)
    func peerConnection(_ peerConnection: _StubRTCPeerConnection, didRemove candidates: [_StubRTCIceCandidate])
    func peerConnection(_ peerConnection: _StubRTCPeerConnection, didOpen dataChannel: _StubRTCDataChannel)
}

protocol RTCPeerConnectionDelegate: _StubRTCPeerConnectionDelegate {}

final class _StubRTCPeerConnection {
    func close() {}
    func add(_ track: _StubRTCAudioTrack, streamIds: [String]) {}
    func add(_ candidate: _StubRTCIceCandidate, completionHandler: ((Error?) -> Void)?) { completionHandler?(nil) }
    func offer(for constraints: _StubRTCMediaConstraints, completionHandler: @escaping (_StubRTCSessionDescription?, Error?) -> Void) {
        completionHandler(nil, NSError(domain: "Stub", code: 0))
    }
    func answer(for constraints: _StubRTCMediaConstraints, completionHandler: @escaping (_StubRTCSessionDescription?, Error?) -> Void) {
        completionHandler(nil, NSError(domain: "Stub", code: 0))
    }
    func setLocalDescription(_ sdp: _StubRTCSessionDescription, completionHandler: @escaping ((Error?) -> Void)) {
        completionHandler(nil)
    }
    func setRemoteDescription(_ sdp: _StubRTCSessionDescription, completionHandler: @escaping ((Error?) -> Void)) {
        completionHandler(nil)
    }
}

final class _StubRTCPeerConnectionFactory {
    init(encoderFactory: _StubRTCDefaultVideoEncoderFactory, decoderFactory: _StubRTCDefaultVideoDecoderFactory) {}
    func audioSource(with constraints: _StubRTCMediaConstraints) -> AnyObject { NSObject() }
    func audioTrack(with source: AnyObject, trackId: String) -> _StubRTCAudioTrack { _StubRTCAudioTrack() }
    func peerConnection(with config: _StubRTCConfiguration, constraints: _StubRTCMediaConstraints, delegate: (any RTCPeerConnectionDelegate)?) -> _StubRTCPeerConnection? {
        _StubRTCPeerConnection()
    }
}

#endif

// MARK: - ConferenceAudioService

/// Manages WebRTC peer-to-peer audio for conference rooms.
/// Uses a full-mesh topology: every participant connects directly to every other participant.
/// Conflict resolution: the participant with the alphabetically lower userId is always the "offerer".
class ConferenceAudioService: ObservableObject {
    static let shared = ConferenceAudioService()

    // MARK: - Public state

    @Published var speakingPeers: Set<String> = []

    /// True once joinRoom has been called and the room hasn't been left yet.
    var isInRoom: Bool { roomId != nil }

    // MARK: - Private state

    private var peerConnections: [String: RTCPeerConnection] = [:]
    // Retain delegates so they aren't deallocated while the peer connection is alive.
    private var peerDelegates: [String: PeerConnectionDelegate] = [:]
    private var localAudioTrack: RTCAudioTrack?
    private var factory: RTCPeerConnectionFactory?
    private var signalingListener: ListenerRegistration?

    private var roomId: String?
    private var userId: String?
    private let firestore = FirestoreService.shared

    private static let iceServers: [RTCIceServer] = [
        RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"]),
        RTCIceServer(urlStrings: ["stun:stun1.l.google.com:19302"]),
    ]

    private init() {}

    // MARK: - Public API

    func joinRoom(roomId: String, userId: String, existingParticipantIds: [String]) {
        self.roomId = roomId
        self.userId = userId

        setupFactory()
        setupLocalAudio()
        listenForSignaling()

        // Alphabetically lower userId is always the offerer to avoid offer collisions.
        for peerId in existingParticipantIds where peerId != userId {
            if userId < peerId {
                createOffer(for: peerId)
            }
            // If userId > peerId, we wait — the other peer will send us an offer.
        }
    }

    func leaveRoom() {
        signalingListener?.remove()
        signalingListener = nil

        for (_, pc) in peerConnections { pc.close() }
        peerConnections.removeAll()
        peerDelegates.removeAll()
        localAudioTrack = nil

        DispatchQueue.main.async { self.speakingPeers.removeAll() }

        // Restore audio session to a neutral state.
        RTCAudioSession.sharedInstance().lockForConfiguration()
        let config = RTCAudioSessionConfiguration()
        config.category = AVAudioSession.Category.ambient.rawValue
        config.mode = AVAudioSession.Mode.default.rawValue
        try? RTCAudioSession.sharedInstance().setConfiguration(config)
        RTCAudioSession.sharedInstance().unlockForConfiguration()

        roomId = nil
        userId = nil
        factory = nil
    }

    func setMuted(_ muted: Bool) {
        localAudioTrack?.isEnabled = !muted
    }

    /// Called when a new participant joins an already-active room.
    func handleNewParticipant(_ peerId: String) {
        guard let userId = userId, peerId != userId else { return }
        guard peerConnections[peerId] == nil else { return }
        // Only the alphabetically lower userId creates the offer.
        if userId < peerId {
            createOffer(for: peerId)
        }
    }

    /// Called when a participant leaves the room (detected via Firestore participant list diff).
    func handleParticipantLeft(_ peerId: String) {
        peerConnections[peerId]?.close()
        peerConnections.removeValue(forKey: peerId)
        peerDelegates.removeValue(forKey: peerId)
        DispatchQueue.main.async { self.speakingPeers.remove(peerId) }
    }

    // MARK: - Setup

    private func setupFactory() {
        RTCInitializeSSL()
        let encoderFactory = RTCDefaultVideoEncoderFactory()
        let decoderFactory = RTCDefaultVideoDecoderFactory()
        factory = RTCPeerConnectionFactory(encoderFactory: encoderFactory, decoderFactory: decoderFactory)
    }

    private func setupLocalAudio() {
        RTCAudioSession.sharedInstance().lockForConfiguration()
        let config = RTCAudioSessionConfiguration.webRTC()
        config.category = AVAudioSession.Category.playAndRecord.rawValue
        config.categoryOptions = [.defaultToSpeaker, .allowBluetooth]
        config.mode = AVAudioSession.Mode.voiceChat.rawValue
        try? RTCAudioSession.sharedInstance().setConfiguration(config)
        RTCAudioSession.sharedInstance().isAudioEnabled = true
        RTCAudioSession.sharedInstance().unlockForConfiguration()

        guard let factory = factory else { return }
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        let audioSource = factory.audioSource(with: constraints)
        localAudioTrack = factory.audioTrack(with: audioSource, trackId: "audio0")
        localAudioTrack?.isEnabled = true
    }

    // MARK: - Peer Connection Management

    private func createPeerConnection(for peerId: String) -> RTCPeerConnection? {
        guard let factory = factory else { return nil }
        let config = RTCConfiguration()
        config.iceServers = ConferenceAudioService.iceServers
        config.sdpSemantics = .unifiedPlan

        let constraints = RTCMediaConstraints(
            mandatoryConstraints: ["OfferToReceiveAudio": "true"],
            optionalConstraints: nil
        )
        let delegate = PeerConnectionDelegate(peerId: peerId, service: self)
        guard let pc = factory.peerConnection(with: config, constraints: constraints, delegate: delegate) else { return nil }

        if let track = localAudioTrack {
            pc.add(track, streamIds: ["stream0"])
        }

        peerConnections[peerId] = pc
        peerDelegates[peerId] = delegate
        return pc
    }

    private func createOffer(for peerId: String) {
        guard let pc = createPeerConnection(for: peerId) else { return }
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: ["OfferToReceiveAudio": "true"],
            optionalConstraints: nil
        )
        pc.offer(for: constraints) { [weak self] sdp, error in
            guard let self = self, let sdp = sdp, error == nil else { return }
            pc.setLocalDescription(sdp) { error in
                guard error == nil, let roomId = self.roomId, let userId = self.userId else { return }
                Task {
                    try? await self.firestore.writeSignalingOffer(
                        roomId: roomId, fromUserId: userId, toUserId: peerId, sdp: sdp.sdp
                    )
                }
            }
        }
    }

    // MARK: - Signaling Handlers

    private func handleOffer(from peerId: String, sdp: String) {
        let pc = peerConnections[peerId] ?? createPeerConnection(for: peerId)
        guard let pc = pc else { return }

        let remoteSdp = RTCSessionDescription(type: .offer, sdp: sdp)
        pc.setRemoteDescription(remoteSdp) { [weak self] error in
            guard let self = self, error == nil else { return }
            let constraints = RTCMediaConstraints(
                mandatoryConstraints: ["OfferToReceiveAudio": "true"],
                optionalConstraints: nil
            )
            pc.answer(for: constraints) { answer, error in
                guard let answer = answer, error == nil else { return }
                pc.setLocalDescription(answer) { error in
                    guard error == nil, let roomId = self.roomId, let userId = self.userId else { return }
                    Task {
                        try? await self.firestore.writeSignalingAnswer(
                            roomId: roomId, fromUserId: userId, toUserId: peerId, sdp: answer.sdp
                        )
                    }
                }
            }
        }
    }

    private func handleAnswer(from peerId: String, sdp: String) {
        guard let pc = peerConnections[peerId] else { return }
        let remoteSdp = RTCSessionDescription(type: .answer, sdp: sdp)
        pc.setRemoteDescription(remoteSdp) { _ in }
    }

    private func handleIceCandidate(from peerId: String, candidateString: String) {
        guard let pc = peerConnections[peerId] else { return }
        // Encoded as JSON: {"sdp": ..., "sdpMLineIndex": ..., "sdpMid": ...}
        guard let data = candidateString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sdp = dict["sdp"] as? String,
              let sdpMLineIndexRaw = dict["sdpMLineIndex"],
              let sdpMLineIndex = (sdpMLineIndexRaw as? NSNumber).map({ Int32($0.intValue) })
        else { return }
        let sdpMid = dict["sdpMid"] as? String
        let candidate = RTCIceCandidate(
            sdp: sdp,
            sdpMLineIndex: sdpMLineIndex,
            sdpMid: sdpMid.flatMap { $0.isEmpty ? nil : $0 }
        )
        pc.add(candidate) { _ in }
    }

    private func listenForSignaling() {
        guard let roomId = roomId, let userId = userId else { return }
        signalingListener?.remove()
        signalingListener = firestore.listenToSignaling(roomId: roomId, forUserId: userId) { [weak self] signal in
            guard let self = self else { return }
            // Only handle offer if we don't already have a peer connection for this peer.
            if let offer = signal.offer, self.peerConnections[signal.fromUserId] == nil {
                self.handleOffer(from: signal.fromUserId, sdp: offer)
            }
            if let answer = signal.answer {
                self.handleAnswer(from: signal.fromUserId, sdp: answer)
            }
            for candidate in signal.iceCandidates {
                self.handleIceCandidate(from: signal.fromUserId, candidateString: candidate)
            }
        }
    }

    // MARK: - Delegate Callbacks (called from PeerConnectionDelegate)

    fileprivate func didGenerateIceCandidate(_ candidate: RTCIceCandidate, for peerId: String) {
        guard let roomId = roomId, let userId = userId else { return }
        let dict: [String: Any] = [
            "sdp": candidate.sdp,
            "sdpMLineIndex": candidate.sdpMLineIndex,
            "sdpMid": candidate.sdpMid ?? "",
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let candidateString = String(data: data, encoding: .utf8) else { return }
        Task {
            try? await firestore.addIceCandidate(
                roomId: roomId, fromUserId: userId, toUserId: peerId, candidate: candidateString
            )
        }
    }

    fileprivate func didChangeConnectionState(_ state: RTCIceConnectionState, for peerId: String) {
        switch state {
        case .disconnected, .failed, .closed:
            handleParticipantLeft(peerId)
        default:
            break
        }
    }
}

// MARK: - Peer Connection Delegate

private class PeerConnectionDelegate: NSObject, RTCPeerConnectionDelegate {
    let peerId: String
    weak var service: ConferenceAudioService?

    init(peerId: String, service: ConferenceAudioService) {
        self.peerId = peerId
        self.service = service
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        service?.didChangeConnectionState(newState, for: peerId)
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}

    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        service?.didGenerateIceCandidate(candidate, for: peerId)
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}
}
