import AVFoundation
import Combine
import GameController
import SwiftUI

class VolumeButtonPTT: ObservableObject {
    @Published var isTransmitting: Bool = false
    @Published var connectedDeviceName: String?
    
    private var isActive: Bool = false
    
    func activate() {
        guard !isActive else { return }
        isActive = true
        isTransmitting = false
        
        NotificationCenter.default.addObserver(self, selector: #selector(controllerConnected), name: .GCControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(controllerDisconnected), name: .GCControllerDidDisconnect, object: nil)
        for controller in GCController.controllers() { configureController(controller) }
    }
    
    func deactivate() {
        isActive = false
        isTransmitting = false
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func controllerConnected(_ notification: Notification) {
        if let controller = notification.object as? GCController {
            configureController(controller)
            DispatchQueue.main.async { self.connectedDeviceName = controller.vendorName ?? "Bluetooth Remote" }
        }
    }
    
    @objc private func controllerDisconnected(_ notification: Notification) {
        DispatchQueue.main.async { self.connectedDeviceName = nil }
    }
    
    private func configureController(_ controller: GCController) {
        DispatchQueue.main.async { self.connectedDeviceName = controller.vendorName ?? "Bluetooth Remote" }
        if let micro = controller.microGamepad {
            micro.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in self?.handleButton(pressed) }
            micro.buttonX.pressedChangedHandler = { [weak self] _, _, pressed in self?.handleButton(pressed) }
        }
        if let extended = controller.extendedGamepad {
            extended.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in self?.handleButton(pressed) }
        }
    }
    
    private func handleButton(_ pressed: Bool) {
        guard isActive else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if pressed && !self.isTransmitting {
                self.isTransmitting = true
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } else if !pressed && self.isTransmitting {
                self.isTransmitting = false
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
    }
    
    deinit { deactivate() }
}

struct HiddenVolumeView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView { UIView() }
    func updateUIView(_ uiView: UIView, context: Context) {}
}
