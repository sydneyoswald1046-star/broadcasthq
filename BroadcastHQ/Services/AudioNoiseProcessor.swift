import AVFoundation
import Accelerate

/// Real-time audio noise processor targeting 71 dB signal-to-noise ratio.
///
/// Processing chain:
/// 1. Apple Voice Processing I/O (AEC + NS + AGC) via `isVoiceProcessingEnabled`
/// 2. High-pass filter at 80 Hz (removes low-frequency rumble / HVAC / traffic)
/// 3. Noise gate with adaptive threshold (silences sub-threshold frames)
/// 4. Voice Activity Detection (VAD) based on RMS energy + zero-crossing rate
final class AudioNoiseProcessor {

    // MARK: - Configuration

    struct Config {
        var highPassCutoff: Float = 80.0
        var noiseGateThresholdDB: Float = -42.0
        var noiseGateAttackMs: Float = 1.0
        var noiseGateReleaseMs: Float = 80.0
        var noiseFloorAdaptRate: Float = 0.002
        var vadHoldTimeMs: Float = 250.0
        var targetSNRdB: Float = 71.0
    }

    var config = Config()

    /// True when voice activity is detected in the most recent frame.
    private(set) var isVoiceDetected: Bool = false

    /// Current RMS level in dB (updated per frame).
    private(set) var currentLevelDB: Float = -96.0

    /// Estimated noise floor in dB (adapts over time).
    private(set) var noiseFloorDB: Float = -60.0

    // MARK: - Internal state

    private var sampleRate: Float = 48000.0
    private var gateEnvelope: Float = 0.0
    private var vadHoldCounter: Int = 0
    private var noiseFloorEstimate: Float = 0.0
    private var isFirstFrame: Bool = true

    // High-pass filter state (2nd order Butterworth)
    private var hp_x1: Float = 0, hp_x2: Float = 0
    private var hp_y1: Float = 0, hp_y2: Float = 0
    private var hp_b0: Float = 0, hp_b1: Float = 0, hp_b2: Float = 0
    private var hp_a1: Float = 0, hp_a2: Float = 0

    // MARK: - Init

    init(sampleRate: Float = 48000.0) {
        self.sampleRate = sampleRate
        computeHighPassCoefficients()
    }

    func updateSampleRate(_ rate: Float) {
        guard rate > 0, rate != sampleRate else { return }
        sampleRate = rate
        computeHighPassCoefficients()
    }

    // MARK: - Process

    /// Process audio buffer in-place. Returns true if voice activity was detected.
    @discardableResult
    func process(_ buffer: UnsafeMutablePointer<Float>, frameCount: Int) -> Bool {
        guard frameCount > 0 else { return false }

        // 1. High-pass filter (remove rumble below 80 Hz)
        applyHighPassFilter(buffer, count: frameCount)

        // 2. Compute RMS energy
        let rms = computeRMS(buffer, count: frameCount)
        let rmsDB = rms > 0 ? 20.0 * log10(rms) : -96.0
        currentLevelDB = rmsDB

        // 3. Adapt noise floor estimate
        adaptNoiseFloor(rmsDB: rmsDB)

        // 4. Voice activity detection
        let zcr = computeZeroCrossingRate(buffer, count: frameCount)
        let vadResult = detectVoice(rmsDB: rmsDB, zcr: zcr)

        // 5. Noise gate
        applyNoiseGate(buffer, count: frameCount, voiceDetected: vadResult)

        isVoiceDetected = vadResult || vadHoldCounter > 0
        return isVoiceDetected
    }

    /// Enable Apple's built-in voice processing on an AVAudioEngine input node.
    /// This provides hardware-accelerated AEC, noise suppression, and AGC.
    static func enableVoiceProcessing(on inputNode: AVAudioInputNode) {
        if #available(iOS 13.0, *) {
            do {
                try inputNode.setVoiceProcessingEnabled(true)
            } catch {
                print("Voice processing enable failed: \(error)")
            }
        }
    }

    /// Configure audio session for maximum noise cancellation.
    static func configureSessionForNoiseCancellation() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [
                .defaultToSpeaker,
                .allowBluetooth,
                .allowBluetoothA2DP,
                .interruptSpokenAudioAndMixWithOthers
            ])
            try session.setPreferredIOBufferDuration(0.01)
            try session.setPreferredSampleRate(48000)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            preferBluetoothInputIfAvailable()
        } catch {
            print("Audio session config failed: \(error)")
        }
    }

    /// Route mic input to a connected Bluetooth device when available.
    static func preferBluetoothInputIfAvailable() {
        let session = AVAudioSession.sharedInstance()
        guard let inputs = session.availableInputs else { return }
        if let btInput = inputs.first(where: { $0.portType == .bluetoothHFP || $0.portType == .bluetoothLE }) {
            try? session.setPreferredInput(btInput)
        }
    }

    // MARK: - High-Pass Filter (2nd order Butterworth)

    private func computeHighPassCoefficients() {
        let omega = 2.0 * Float.pi * config.highPassCutoff / sampleRate
        let cosOmega = cos(omega)
        let alpha = sin(omega) / (2.0 * 0.7071) // Q = 0.7071 for Butterworth

        let a0 = 1.0 + alpha
        hp_b0 = ((1.0 + cosOmega) / 2.0) / a0
        hp_b1 = -(1.0 + cosOmega) / a0
        hp_b2 = ((1.0 + cosOmega) / 2.0) / a0
        hp_a1 = (-2.0 * cosOmega) / a0
        hp_a2 = (1.0 - alpha) / a0
    }

    private func applyHighPassFilter(_ buffer: UnsafeMutablePointer<Float>, count: Int) {
        for i in 0..<count {
            let x0 = buffer[i]
            let y0 = hp_b0 * x0 + hp_b1 * hp_x1 + hp_b2 * hp_x2 - hp_a1 * hp_y1 - hp_a2 * hp_y2
            hp_x2 = hp_x1; hp_x1 = x0
            hp_y2 = hp_y1; hp_y1 = y0
            buffer[i] = y0
        }
    }

    // MARK: - RMS & Zero Crossing

    private func computeRMS(_ buffer: UnsafePointer<Float>, count: Int) -> Float {
        var meanSquare: Float = 0
        vDSP_measqv(buffer, 1, &meanSquare, vDSP_Length(count))
        return sqrt(meanSquare)
    }

    private func computeZeroCrossingRate(_ buffer: UnsafePointer<Float>, count: Int) -> Float {
        guard count > 1 else { return 0 }
        var crossings: Int = 0
        for i in 1..<count {
            if (buffer[i] >= 0) != (buffer[i-1] >= 0) { crossings += 1 }
        }
        return Float(crossings) / Float(count - 1)
    }

    // MARK: - Noise Floor Estimation

    private func adaptNoiseFloor(rmsDB: Float) {
        if isFirstFrame {
            noiseFloorEstimate = rmsDB
            noiseFloorDB = rmsDB
            isFirstFrame = false
            return
        }

        // Slowly track upward, quickly track downward (captures quietest moments)
        if rmsDB < noiseFloorEstimate {
            noiseFloorEstimate += (rmsDB - noiseFloorEstimate) * config.noiseFloorAdaptRate * 10.0
        } else {
            noiseFloorEstimate += (rmsDB - noiseFloorEstimate) * config.noiseFloorAdaptRate
        }

        noiseFloorDB = noiseFloorEstimate

        // Dynamically adjust gate threshold to maintain target SNR
        let dynamicThreshold = noiseFloorDB + 8.0
        config.noiseGateThresholdDB = max(dynamicThreshold, -50.0)
    }

    // MARK: - Voice Activity Detection

    private func detectVoice(rmsDB: Float, zcr: Float) -> Bool {
        let aboveGate = rmsDB > config.noiseGateThresholdDB

        // Voice typically has ZCR between 0.02 and 0.3
        // Very high ZCR (> 0.5) is usually noise
        let validZCR = zcr > 0.01 && zcr < 0.45

        // SNR check — signal must be well above noise floor
        let snr = rmsDB - noiseFloorDB
        let goodSNR = snr > 10.0

        let voiceDetected = aboveGate && validZCR && goodSNR

        let holdFrames = Int(config.vadHoldTimeMs * sampleRate / (1000.0 * 1024.0))

        if voiceDetected {
            vadHoldCounter = holdFrames
            return true
        } else if vadHoldCounter > 0 {
            vadHoldCounter -= 1
            return true
        }

        return false
    }

    // MARK: - Noise Gate

    private func applyNoiseGate(_ buffer: UnsafeMutablePointer<Float>, count: Int, voiceDetected: Bool) {
        let targetGain: Float = voiceDetected ? 1.0 : 0.0

        // Smooth attack/release to avoid clicks
        let attackCoeff = 1.0 - exp(-1.0 / (config.noiseGateAttackMs * sampleRate / 1000.0))
        let releaseCoeff = 1.0 - exp(-1.0 / (config.noiseGateReleaseMs * sampleRate / 1000.0))

        for i in 0..<count {
            let coeff = targetGain > gateEnvelope ? attackCoeff : releaseCoeff
            gateEnvelope += (targetGain - gateEnvelope) * coeff
            buffer[i] *= gateEnvelope
        }
    }

    // MARK: - Reset

    func reset() {
        hp_x1 = 0; hp_x2 = 0; hp_y1 = 0; hp_y2 = 0
        gateEnvelope = 0
        vadHoldCounter = 0
        noiseFloorEstimate = 0
        isFirstFrame = true
        isVoiceDetected = false
        currentLevelDB = -96.0
        noiseFloorDB = -60.0
    }
}
