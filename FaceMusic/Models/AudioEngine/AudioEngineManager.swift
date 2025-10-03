//
//  AudioEngineManager.swift
//  FaceMusic
//
//  Created by Ryan Ross on 7/23/25.
//

import AudioKit
import AVFoundation
import UIKit
import os.log

var session: AVAudioSession {
    print("🔧 AVAudioSession initialized")
    return AVAudioSession.sharedInstance()
}

final class AudioEngineManager {
    static let shared = AudioEngineManager()

    // MARK: - Audio Engine
    let engine = AudioEngine()
    private(set) var mixer: Mixer!

    // MARK: - State
    private var addedFaderIDs = Set<ObjectIdentifier>()
    private var didAttachWatchdog = false
    private var didStabilizeAfterLaunch = false

    // Centralized session reference
    private let audioSession = AVAudioSession.sharedInstance()

    // MARK: - Init
    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMediaServicesReset(_:)),
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: nil
        )
    }

    // MARK: - Public API
    func startEngine() {
        configureSessionAndEngine()
    }

    func stopEngine() {
        if didAttachWatchdog, mixer != nil {
            RenderWatchdog.shared.detach()
            didAttachWatchdog = false
        }
        engine.stop()
    }

    func addToMixer(node: Node, caller: String = #function) {
        let nodeID = ObjectIdentifier(node)
        if addedFaderIDs.contains(nodeID) {
            print("AudioEngineManager: ⚠️ Node already connected: \(node)")
            return
        }
        mixer.addInput(node)
        addedFaderIDs.insert(nodeID)
    }

    func removeFromMixer(node: Node, caller: String = #function) {
        let nodeID = ObjectIdentifier(node)
        print("AudioEngineManager: 🧯 [Mixer] removeInput called from \(caller). Node: \(node).")
        mixer.removeInput(node)
        addedFaderIDs.remove(nodeID)
        logMixerState("removeFromMixer() - after removal")
    }

    func removeAllInputsFromMixer(caller: String = #function) {
        print("AudioEngineManager: 🧯 [Mixer] removeAllInputsFromMixer called from \(caller). ")
        let connections = mixer.connections
        for node in connections {
            let nodeID = ObjectIdentifier(node)
            mixer.removeInput(node)
            addedFaderIDs.remove(nodeID)
        }
        logMixerState("removeAllInputsFromMixer() - after removal")
    }

    /// Logs the current mixer state for debugging.
    func logMixerState(_ context: String) {
        let connections = mixer.connections
        print("AudioEngineManager: 🔍 Mixer State (\(context)) — Total Inputs: \(connections.count)")
    }

    // MARK: - Private: Configuration
    private func configureSessionAndEngine() {
        configureBufferLength()
        configureCategoryAndMode()
        applyPreferredSampleRate(48_000)
        activateSession()
        enforceBuiltInMic()
        clearOutputOverride()
        logRoute("after activation")

        updateSettingsFromHardware()
        setupMixerAndStartEngine()

        // Nudge iOS to settle the route shortly after launch
        stabilizeRouteAfterLaunch(delay: 0.3)
    }

    private func configureBufferLength() {
        // Detect device and adjust buffer length
        let model = UIDevice.current.modelIdentifier
        print("AudioEngineManager: Detected device: \(model)")

        var chosen: Settings.BufferLength = .longest
        if model.hasPrefix("iPhone") {
            let parts = model.replacingOccurrences(of: "iPhone", with: "").split(separator: ",")
            if let majorString = parts.first, let major = Int(majorString) {
                if major >= 16 {
                    chosen = .long
                } else if major >= 13 {
                    chosen = .huge
                } else {
                    chosen = .longest
                }
            }
        }
        Settings.bufferLength = chosen
        print("AudioEngineManager: Selected buffer length: \(Settings.bufferLength)")

        do {
            try audioSession.setPreferredIOBufferDuration(Settings.bufferLength.duration)
        } catch {
            print("AudioEngineManager: ⚠️ setPreferredIOBufferDuration failed: \(error)")
        }
    }

    private func configureCategoryAndMode() {
        do {
            try audioSession.setCategory(
                .playAndRecord,
                options: [
                    .mixWithOthers,
                    .allowBluetoothA2DP // keep high-quality BT output
                ]
            )
            // Mode chosen to encourage A2DP with built-in mic
            try audioSession.setMode(.videoRecording)
        } catch {
            print("AudioEngineManager: ⚠️ setCategory/setMode failed: \(error)")
        }
    }

    private func applyPreferredSampleRate(_ rate: Double) {
        do { try audioSession.setPreferredSampleRate(rate) } catch {
            print("AudioEngineManager: ⚠️ setPreferredSampleRate failed: \(error)")
        }
    }

    private func activateSession() {
        do { try audioSession.setActive(true) } catch {
            print("AudioEngineManager: ⚠️ setActive(true) failed: \(error)")
        }
    }

    private func enforceBuiltInMic() {
        guard let builtIn = audioSession.availableInputs?.first(where: { $0.portType == .builtInMic }) else { return }
        do {
            try audioSession.setPreferredInput(builtIn)
            // Re-activate to ensure route applies the preferred input immediately
            try audioSession.setActive(true)
        } catch {
            print("AudioEngineManager: ⚠️ Failed to set preferred built-in mic: \(error)")
        }
    }

    private func clearOutputOverride() {
        do { try audioSession.overrideOutputAudioPort(.none) } catch {
            print("AudioEngineManager: ⚠️ Failed to clear output override: \(error)")
        }
    }

    private func logRoute(_ context: String) {
        let route = audioSession.currentRoute
        print("AudioEngineManager: Route (\(context)) in=\(route.inputs.map { $0.portType.rawValue }) out=\(route.outputs.map { $0.portType.rawValue })")
    }

    private func updateSettingsFromHardware() {
        let hwRate = audioSession.sampleRate
        Settings.sampleRate = hwRate
        Settings.audioFormat = AVAudioFormat(standardFormatWithSampleRate: hwRate, channels: 2) ?? AVAudioFormat()
        print("AudioEngineManager: Hardware sample rate: \(hwRate)")
    }

    private func setupMixerAndStartEngine() {
        let hwRate = audioSession.sampleRate
        let desiredFormat = AVAudioFormat(standardFormatWithSampleRate: hwRate, channels: 2)!

        mixer = Mixer()
        do {
            try mixer.avAudioNode.auAudioUnit.outputBusses[0].setFormat(desiredFormat)
        } catch {
            print("AudioEngineManager: ⚠️ Failed to set mixer output format: \(error)")
        }
        engine.output = mixer

        didAttachWatchdog = false
        do {
            try engine.start()
            print("AudioEngineManager: AudioEngine started")
            print("AudioEngineManager: 🔧 Mixer initialized with format: \(mixer.avAudioNode.outputFormat(forBus: 0))")
            if !didAttachWatchdog {
                RenderWatchdog.shared.attach(to: mixer.avAudioNode, engine: engine.avEngine)
                didAttachWatchdog = true
            }
        } catch {
            Log("AudioEngineManager: AudioEngine start error: \(error)")
        }
    }

    private func updateMixerFormatToHardware() {
        guard let mixer = mixer else { return }
        let hwRate = audioSession.sampleRate
        do {
            let format = AVAudioFormat(standardFormatWithSampleRate: hwRate, channels: 2)!
            try mixer.avAudioNode.auAudioUnit.outputBusses[0].setFormat(format)
        } catch {
            print("AudioEngineManager: ⚠️ Failed to update mixer format to hardware: \(error)")
        }
    }

    private func restartEngine() {
        engine.stop()
        do {
            try engine.start()
            print("AudioEngineManager: Engine restarted")
        } catch {
            print("AudioEngineManager: ⚠️ Engine restart failed: \(error)")
        }
    }

    private func ensureEngineRunning() {
        if !engine.avEngine.isRunning {
            restartEngine()
        }
    }

    private func stabilizeRouteAfterLaunch(delay: TimeInterval) {
        guard !didStabilizeAfterLaunch else { return }
        let session = audioSession
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            do {
                // Re-assert built-in mic and clear overrides
                if let builtIn = session.availableInputs?.first(where: { $0.portType == .builtInMic }) {
                    try session.setPreferredInput(builtIn)
                }
                try session.setActive(true)
                try session.overrideOutputAudioPort(.none)
            } catch {
                print("AudioEngineManager: ⚠️ post-launch (phase 1) route prep failed: \(error)")
            }

            // Small kick: briefly switch to playback (A2DP), then back to playAndRecord with built-in mic
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                guard let self else { return }
                do {
                    // Phase 2a: encourage A2DP output
                    try session.setCategory(.playback, options: [.mixWithOthers, .allowBluetoothA2DP])
                    try session.setActive(true)
                } catch {
                    print("AudioEngineManager: ⚠️ post-launch (phase 2a) playback kick failed: \(error)")
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    guard let self else { return }
                    do {
                        // Phase 2b: restore playAndRecord with built-in mic
                        try session.setCategory(.playAndRecord, options: [.mixWithOthers, .allowBluetoothA2DP])
                        try session.setMode(.videoRecording)
                        if let builtIn = session.availableInputs?.first(where: { $0.portType == .builtInMic }) {
                            try session.setPreferredInput(builtIn)
                        }
                        try session.setActive(true)

                        // Align and restart engine to bind to final route
                        self.updateSettingsFromHardware()
                        self.updateMixerFormatToHardware()
                        self.restartEngine()

                        self.logRoute("post-launch stabilize")
                        self.didStabilizeAfterLaunch = true
                    } catch {
                        print("AudioEngineManager: ⚠️ post-launch (phase 2b) restore failed: \(error)")
                    }
                }
            }
        }
    }

    // MARK: - Notifications
    @objc private func handleRouteChange(_ notification: Notification) {
        let route = audioSession.currentRoute
        let isHFPInput = route.inputs.contains { $0.portType == .bluetoothHFP }
        let isHFPOutput = route.outputs.contains { $0.portType == .bluetoothHFP }

        if isHFPInput || isHFPOutput {
            do {
                if let builtIn = audioSession.availableInputs?.first(where: { $0.portType == .builtInMic }) {
                    try audioSession.setPreferredInput(builtIn)
                    try audioSession.setActive(true, options: [.notifyOthersOnDeactivation])
                    logRoute("after HFP avoidance")
                }
            } catch {
                print("AudioEngineManager: ⚠️ Failed to restore built-in mic after HFP: \(error)")
            }
        } else {
            logRoute("route change")
        }

        clearOutputOverride()
        updateSettingsFromHardware()
        updateMixerFormatToHardware()
        ensureEngineRunning()
    }

    @objc private func handleMediaServicesReset(_ notification: Notification) {
        print("AudioEngineManager: Media services reset — restarting engine")
        stopEngine()
        configureSessionAndEngine()
    }
}
