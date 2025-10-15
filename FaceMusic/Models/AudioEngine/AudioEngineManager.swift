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
    Log.line(actor: "🔧 AVAudioSession", fn: "var session", "Initialized AVAudioSession")
    
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

    // MARK: - Session Interruption
    private var isSessionInterrupted = false

    // Centralized session reference
    private let audioSession = AVAudioSession.sharedInstance()
    
    private var lastKnownRoute: AVAudioSessionRouteDescription?
    /// Public method to set the session interruption flag
    func setSessionInterrupted(_ value: Bool) {
        isSessionInterrupted = value
    }

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
        guard mixer != nil else {
            Log.line(actor: "🚗 AudioEngineManager", fn: "addToMixer", "⚠️ Mixer is nil or not yet initialized. Cannot add to mixer. Called from \(caller).")
            return
        }
        let nodeID = ObjectIdentifier(node)
        if addedFaderIDs.contains(nodeID) {
            Log.line(actor: "🚗 AudioEngineManager", fn: "addToMixer", "⚠️ Node already connected: \(node)")
            return
        }
        mixer.addInput(node)
        addedFaderIDs.insert(nodeID)
    }

    func removeFromMixer(node: Node, caller: String = #function) {
        guard mixer != nil else {
            Log.line(actor: "🚗 AudioEngineManager", fn: "removeFromMixer", "⚠️ Mixer is nil or not yet initialized. Cannot remove inputs. Called from \(caller).")
            return
        }
        let nodeID = ObjectIdentifier(node)
        Log.line(actor: "🚗 AudioEngineManager", fn: "removeFromMixer", "🧯 [Mixer] removeInput called from \(caller). Node: \(node)")

        mixer.removeInput(node)
        addedFaderIDs.remove(nodeID)
        logMixerState("removeFromMixer()")

    }

func removeAllInputsFromMixer(caller: String = #function) {
    guard mixer != nil else {
        Log.line(actor: "🚗 AudioEngineManager", fn: "removeAllInputsFromMixer", "⚠️ Mixer is nil or not yet initialized. Cannot remove inputs. Called from \(caller).")
        return
    }
    Log.line(actor: "🚗 AudioEngineManager", fn: "removeAllInputsFromMixer", "🧯 [Mixer] removeAllInputsFromMixer called from \(caller).")
    let connections = mixer.connections
    for node in connections {
        let nodeID = ObjectIdentifier(node)
        mixer.removeInput(node)
        addedFaderIDs.remove(nodeID)
    }
    logMixerState("removeAllInputsFromMixer()")
}

    
    /// Logs the current mixer state for debugging.
    func logMixerState(_ context: String) {
        guard mixer != nil else {
            Log.line(actor: "🚗 AudioEngineManager", fn: "logMixerState", "⚠️ Mixer is nil or not yet initialized. Cannot log mixer state")
            return
        }
        let connections = mixer.connections
        Log.line(actor: "🚗 AudioEngineManager", fn: "removeAllInputsFromMixer", "🔍 Mixer State (\(context)) — Total Inputs: \(connections.count)")

    }
    
    func forceSpeakerOutput() {
        do {
            try audioSession.overrideOutputAudioPort(.speaker)
            Log.line(actor: "🚗 AudioEngineManager", fn: "forceSpeakerOutput", "🔊 Forced output to speaker")
        } catch {
            Log.line(actor: "🚗 AudioEngineManager", fn: "forceSpeakerOutput", "⚠️ Failed to force speaker output: \(error)")
        }
    }

    // MARK: - Private: Configuration
    private func configureSessionAndEngine() {
        configureBufferLength()
        configureCategoryAndMode()
        applyPreferredSampleRate(48_000)
        activateSession()
        logRoute("after activation")

        updateSettingsFromHardware()
        setupMixerAndStartEngine()
    }

    private func configureBufferLength() {
        // Detect device and adjust buffer length
        let model = UIDevice.current.modelIdentifier
        Log.line(actor: "🚗 AudioEngineManager", fn: "configureBufferLength", "Detected device: \(model)")


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
        Log.line(actor: "🚗 AudioEngineManager", fn: "configureBufferLength", "Selected buffer length: \(Settings.bufferLength)")

        do {
            try audioSession.setPreferredIOBufferDuration(Settings.bufferLength.duration)
        } catch {
            Log.line(actor: "🚗 AudioEngineManager", fn: "configureBufferLength", "⚠️ setPreferredIOBufferDuration failed: \(error)")

        }
    }

    private func configureCategoryAndMode() {
        do {
            try audioSession.setCategory(
                .playAndRecord,
                options: [
                    .mixWithOthers,
                    .allowBluetoothA2DP,
                    .defaultToSpeaker
                ]
            )
            try audioSession.setMode(.default)
        } catch {
            
            Log.line(actor: "🚗 AudioEngineManager", fn: "configureCategoryAndMode", "⚠️ setCategory/setMode failed: \(error)")
        }
    }

    private func applyPreferredSampleRate(_ rate: Double) {
        do { try audioSession.setPreferredSampleRate(rate) } catch {
            Log.line(actor: "🚗 AudioEngineManager", fn: "applyPreferredSampleRate", "⚠️ setPreferredSampleRate failed: \(error)")
        }
    }

    private func activateSession() {
        do { try audioSession.setActive(true) } catch {
            Log.line(actor: "🚗 AudioEngineManager", fn: "activateSession", "⚠️ setActive(true) failed: \(error)")

        }
    }

    private func logRoute(_ context: String) {
        let route = audioSession.currentRoute
        
        Log.line(actor: "🚗 AudioEngineManager", fn: "logRoute", "Route () in=\(route.inputs.map(\.portType.rawValue).joined(separator: ",")) out=\(route.outputs.map(\.portType.rawValue).joined(separator: ","))")
    }

    private func updateSettingsFromHardware() {
        let hwRate = audioSession.sampleRate
        Settings.sampleRate = hwRate
        Settings.audioFormat = AVAudioFormat(standardFormatWithSampleRate: hwRate, channels: 2) ?? AVAudioFormat()

        Log.line(actor: "🚗 AudioEngineManager", fn: "updateSettingsFromHardware", "Hardware sample rate: \(hwRate)")
    }

    private func setupMixerAndStartEngine() {
        let hwRate = audioSession.sampleRate
        let desiredFormat = AVAudioFormat(standardFormatWithSampleRate: hwRate, channels: 2)!

        mixer = Mixer()
        do {
            try mixer.avAudioNode.auAudioUnit.outputBusses[0].setFormat(desiredFormat)
        } catch {
            Log.line(actor: "🚗 AudioEngineManager", fn: "setupMixerAndStartEngine", "⚠️ Failed to set mixer output format: \(error)")

        }
        engine.output = mixer

        didAttachWatchdog = false
        do {
            try engine.start()
            Log.line(actor: "🚗 AudioEngineManager", fn: "setupMixerAndStartEngine", "AudioEngine started. Mixer initialized with format \(mixer.avAudioNode.outputFormat(forBus: 0))")
            
            if !didAttachWatchdog {
                RenderWatchdog.shared.attach(to: mixer.avAudioNode, engine: engine.avEngine)
                didAttachWatchdog = true
            }
        } catch {
            Log.line(actor: "🚗 AudioEngineManager", fn: "setupMixerAndStartEngine", "AudioEngine start error: \(error)")
        }
    }

    private func updateMixerFormatToHardware() {
        guard let mixer = mixer else { return }
        let hwRate = audioSession.sampleRate
        do {
            let format = AVAudioFormat(standardFormatWithSampleRate: hwRate, channels: 2)!
            try mixer.avAudioNode.auAudioUnit.outputBusses[0].setFormat(format)
        } catch {
            Log.line(actor: "🚗 AudioEngineManager", fn: "updateMixerFormatToHardware", "⚠️ Failed to update mixer format to hardware: \(error)")

        }
    }

    func restartEngine() {
        if isSessionInterrupted {
            Log.line(actor: "🚗 AudioEngineManager", fn: "restartEngine", "🚫 Skipping restart — session is interrupted.")
            return
        }

        let inputDesc = audioSession.currentRoute.inputs.first
        let sampleRate = audioSession.sampleRate

        if inputDesc == nil || sampleRate < 1000 {
            Log.line(actor: "🚗 AudioEngineManager", fn: "restartEngine", "⏳ Delaying restart — input not ready or sampleRate too low (\(sampleRate))")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.restartEngine()
            }
            return
        }

        engine.stop()
        do {
            try engine.start()
            Log.line(actor: "🚗 AudioEngineManager", fn: "restartEngine", "Engine restarted.")
        } catch {
            Log.line(actor: "🚗 AudioEngineManager", fn: "restartEngine", "⚠️ Engine restart failed: \(error)")
        }
    }

    private func ensureEngineRunning() {
        if !engine.avEngine.isRunning {
            restartEngine()
        }
    }

    // MARK: - Notifications
    @objc private func handleRouteChange(_ notification: Notification) {
        if let lastRoute = lastKnownRoute, lastRoute == audioSession.currentRoute {
            Log.line(actor: "🚗 AudioEngineManager", fn: "handleRouteChange", "🔁 Route unchanged, skipping reconfiguration.")
            return
        }
        lastKnownRoute = audioSession.currentRoute
        
        let route = audioSession.currentRoute
        let inPorts = route.inputs.map { $0.portType.rawValue }
        let outPorts = route.outputs.map { $0.portType.rawValue }

        var reasonStr = "unknown"
        if let info = notification.userInfo,
           let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
           let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) {
            reasonStr = String(describing: reason)
            if let prev = info[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription {
                let prevIn = prev.inputs.map { $0.portType.rawValue }
                let prevOut = prev.outputs.map { $0.portType.rawValue }
                Log.line(actor: "🚗 AudioEngineManager", fn: "handleRouteChange", "Route change reason=\(reasonStr) prevIn=\(prevIn) prevOut=\(prevOut) newIn=\(inPorts) newOut=\(outPorts)")

            } else {
                Log.line(actor: "🚗 AudioEngineManager", fn: "handleRouteChange", "Route change reason=\(reasonStr) newIn=\(inPorts) newOut=\(outPorts)")

            }
        } else {
            Log.line(actor: "🚗 AudioEngineManager", fn: "handleRouteChange", "Route change newIn=\(inPorts) newOut=\(outPorts)")
        }
        
        if outPorts.contains(AVAudioSession.Port.builtInReceiver.rawValue) {
            try? audioSession.overrideOutputAudioPort(.none)
        } else if outPorts.contains(AVAudioSession.Port.builtInSpeaker.rawValue) {
            try? audioSession.overrideOutputAudioPort(.speaker)
        }
        
        if inPorts.isEmpty || outPorts.isEmpty {
            Log.line(actor: "🚗 AudioEngineManager", fn: "handleRouteChange", "⚠️ Detected empty input/output routes. Attempting to recover...")
            restartEngine()
        }

        let oldRate = Settings.sampleRate
        updateSettingsFromHardware()

        if Settings.sampleRate != oldRate {
            updateMixerFormatToHardware()
            restartEngine()
        } else {
            ensureEngineRunning()
        }
    }

    @objc private func handleMediaServicesReset(_ notification: Notification) {
        Log.line(actor: "🚗 AudioEngineManager", fn: "handleMediaServicesReset", "Media services reset — restarting engine")

        stopEngine()
        configureSessionAndEngine()
    }
}
