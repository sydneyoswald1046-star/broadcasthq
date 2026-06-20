import Combine
import CoreGraphics
import Foundation
import QuartzCore
import UIKit

#if targetEnvironment(simulator)

// The NDI SDK ships as a device-only static library (arm64 iOS, no simulator
// slice), so it cannot link for the iOS Simulator. This stub exposes the exact
// same public surface as the real service so the rest of the app builds and
// runs in the Simulator. NDI capture is inert here — the Simulator has no NDI
// hardware or network capture path anyway. Device behavior is unchanged.
final class NDIService: ObservableObject {
    static let shared = NDIService()

    @Published var availableSources: [String] = []
    @Published var isConnected: Bool = false
    @Published var connectedSourceName: String = ""
    @Published var currentFrame: CGImage?
    @Published var resolution: String = ""
    @Published var frameRate: String = ""
    @Published var lastError: String? = "NDI is unavailable in the Simulator"
    @Published var isSearching: Bool = false

    func initialize() {}
    func startSearching() {}
    func stopSearching() {}
    func connect(to sourceName: String) {}
    func disconnect() {}
    func shutdown() {}
}

#else

class NDIService: ObservableObject {
    static let shared = NDIService()

    @Published var availableSources: [String] = []
    @Published var isConnected: Bool = false
    @Published var connectedSourceName: String = ""
    @Published var currentFrame: CGImage?
    @Published var resolution: String = ""
    @Published var frameRate: String = ""
    @Published var lastError: String?
    @Published var isSearching: Bool = false

    private var finder: NDIlib_find_instance_t?
    private var receiver: NDIlib_recv_instance_t?
    private var isInitialized: Bool = false
    private var receiveQueue: DispatchQueue?
    private var findQueue: DispatchQueue?
    private var isReceiving: Bool = false
    private var isFinding: Bool = false
    private var lastFrameTime: CFTimeInterval = 0
    private let minFrameInterval: CFTimeInterval = 1.0 / 30.0

    init() {
        initialize()
    }

    // MARK: - Initialize NDI

    func initialize() {
        guard !isInitialized else { return }

        if NDIlib_initialize() {
            isInitialized = true
            receiveQueue = DispatchQueue(label: "com.valorlive.ndi.receive", qos: .userInitiated)
            findQueue = DispatchQueue(label: "com.valorlive.ndi.find", qos: .userInitiated)
        } else {
            DispatchQueue.main.async {
                self.lastError = "Failed to initialize NDI"
            }
        }
    }

    // MARK: - Find Sources

    func startSearching() {
        if !isInitialized {
            initialize()
        }
        guard isInitialized else {
            DispatchQueue.main.async {
                self.lastError = "NDI SDK failed to initialize"
            }
            return
        }
        guard !isFinding else { return }
        isFinding = true

        DispatchQueue.main.async {
            self.isSearching = true
            self.lastError = nil
        }

        if finder == nil {
            var findSettings = NDIlib_find_create_t()
            findSettings.show_local_sources = true
            findSettings.p_groups = nil
            findSettings.p_extra_ips = nil
            finder = NDIlib_find_create_v2(&findSettings)
        }

        guard let finder = finder else {
            DispatchQueue.main.async {
                self.lastError = "Failed to create NDI finder"
                self.isSearching = false
            }
            isFinding = false
            return
        }

        findQueue?.async { [weak self] in
            guard let self = self else { return }

            let deadline = Date().addingTimeInterval(30)
            repeat {
                let _ = NDIlib_find_wait_for_sources(finder, 2000)

                var numSources: UInt32 = 0
                let sourcesPtr = NDIlib_find_get_current_sources(finder, &numSources)

                var names: [String] = []
                if let ptr = sourcesPtr, numSources > 0 {
                    for i in 0..<Int(numSources) {
                        if let namePtr = ptr[i].p_ndi_name {
                            names.append(String(cString: namePtr))
                        }
                    }
                }

                let current = names
                DispatchQueue.main.async {
                    self.availableSources = current
                    if !current.isEmpty {
                        self.lastError = nil
                        self.isSearching = false
                    }
                }

                if !names.isEmpty { break }
            } while self.isFinding && Date() < deadline

            DispatchQueue.main.async {
                self.isSearching = false
                if self.availableSources.isEmpty {
                    self.lastError = "No NDI sources found — check same WiFi network and Local Network permission in Settings"
                }
            }
            self.isFinding = false
        }
    }

    func stopSearching() {
        isFinding = false
        DispatchQueue.main.async { self.isSearching = false }
    }

    // MARK: - Connect to Source

    func connect(to sourceName: String) {
        guard isInitialized, let finder = finder else { return }

        // Disconnect existing
        disconnect()

        // Resolve the name to a *fresh* source pointer. The NDIlib_source_t structs from
        // get_current_sources are owned by the finder and their C string pointers can
        // dangle if cached, so we look the source up live, immediately before connecting.
        var numSources: UInt32 = 0
        let sourcesPtr = NDIlib_find_get_current_sources(finder, &numSources)
        var resolved: NDIlib_source_t?
        if let ptr = sourcesPtr, numSources > 0 {
            for i in 0..<Int(numSources) {
                if let namePtr = ptr[i].p_ndi_name, String(cString: namePtr) == sourceName {
                    resolved = ptr[i]
                    break
                }
            }
        }
        guard let source = resolved else {
            DispatchQueue.main.async { self.lastError = "Source not found" }
            return
        }

        // Create receiver
        var recvSettings = NDIlib_recv_create_v3_t()
        recvSettings.source_to_connect_to = source
        recvSettings.color_format = NDIlib_recv_color_format_BGRX_BGRA
        recvSettings.bandwidth = NDIlib_recv_bandwidth_lowest
        recvSettings.allow_video_fields = true
        recvSettings.p_ndi_recv_name = nil

        receiver = NDIlib_recv_create_v3(&recvSettings)

        guard receiver != nil else {
            DispatchQueue.main.async { self.lastError = "Failed to connect" }
            return
        }

        DispatchQueue.main.async {
            self.isConnected = true
            self.connectedSourceName = sourceName
            self.lastError = nil
        }

        // Start receiving frames
        startReceiving()
    }

    func disconnect() {
        isReceiving = false

        if let recv = receiver {
            NDIlib_recv_destroy(recv)
            receiver = nil
        }

        DispatchQueue.main.async {
            self.isConnected = false
            self.connectedSourceName = ""
            self.currentFrame = nil
            self.resolution = ""
            self.frameRate = ""
        }
    }

    // MARK: - Receive Frames

    private func startReceiving() {
        guard let recv = receiver else { return }
        isReceiving = true

        receiveQueue?.async { [weak self] in
            guard let self = self else { return }

            while self.isReceiving {
                var videoFrame = NDIlib_video_frame_v2_t()

                let frameType = NDIlib_recv_capture_v3(recv, &videoFrame, nil, nil, 100)

                switch frameType {
                case NDIlib_frame_type_video:
                    self.processVideoFrame(&videoFrame, receiver: recv)
                    NDIlib_recv_free_video_v2(recv, &videoFrame)

                case NDIlib_frame_type_none:
                    // No data yet, continue
                    break

                case NDIlib_frame_type_error:
                    DispatchQueue.main.async {
                        self.lastError = "Connection lost"
                        self.isConnected = false
                    }
                    self.isReceiving = false

                default:
                    break
                }
            }
        }
    }

    private func processVideoFrame(_ frame: inout NDIlib_video_frame_v2_t, receiver: NDIlib_recv_instance_t) {
        let now = CACurrentMediaTime()
        guard now - lastFrameTime >= minFrameInterval else { return }
        lastFrameTime = now

        let width = Int(frame.xres)
        let height = Int(frame.yres)
        let stride = Int(frame.line_stride_in_bytes)

        guard width > 0, height > 0, let data = frame.p_data else { return }

        let resString = "\(width)×\(height)"
        let fpsNum = frame.frame_rate_N
        let fpsDen = frame.frame_rate_D
        let fps = fpsDen > 0 ? Double(fpsNum) / Double(fpsDen) : 0
        let fpsString = String(format: "%.1f fps", fps)

        let byteCount = stride * height
        let dataCopy = UnsafeMutableRawPointer.allocate(byteCount: byteCount, alignment: 8)
        dataCopy.copyMemory(from: data, byteCount: byteCount)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)

        guard let provider = CGDataProvider(dataInfo: dataCopy, data: dataCopy, size: byteCount, releaseData: { info, _, _ in
            info?.deallocate()
        }) else {
            dataCopy.deallocate()
            return
        }

        guard let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: stride,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else { return }

        DispatchQueue.main.async { [weak self] in
            self?.currentFrame = cgImage
            self?.resolution = resString
            self?.frameRate = fpsString
        }
    }

    // MARK: - Cleanup

    func shutdown() {
        disconnect()

        if let find = finder {
            NDIlib_find_destroy(find)
            finder = nil
        }

        if isInitialized {
            NDIlib_destroy()
            isInitialized = false
        }
    }

    deinit {
        shutdown()
    }
}

#endif
