//
//  FaceTrackerViewModel.swift
//  FaceMusic
//
//  Created by Ryan Ross
//

import Foundation
import Combine
import ARKit
import SceneKit

/// ViewModel for coordinating face tracking, audio, and UI state
class FaceTrackerViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var isARSessionRunning: Bool = false
    @Published var currentPatchName: String = ""
    @Published var showStats: Bool = true
    @Published var isChordGridVisible: Bool = false

    // MARK: - Properties

    let faceTracker: FaceTracker
    let patchSelectorViewModel = PatchSelectorViewModel()

    private var cancellables = Set<AnyCancellable>()
    private(set) var didStartAR = false

    // Stats tracking
    private var lastStatsUpdate: TimeInterval = 0
    private let statsUpdateInterval: TimeInterval = 0.25 // 4 times per second

    // MARK: - Callbacks for UI

    var onStatsUpdate: ((FaceData, String, String) -> Void)?
    var onError: ((String, String) -> Void)?
    var onChordGridToggleRequested: (() -> Void)?

    // MARK: - Initialization

    init(faceTracker: FaceTracker = FaceTracker()) {
        self.faceTracker = faceTracker
        self.faceTracker.delegate = self

        setupPatchSelector()
    }

    // MARK: - Setup

    private func setupPatchSelector() {
        Log.line(actor: "🎛️ FaceTrackerViewModel", fn: "setupPatchSelector", "calling patchSelectorViewModel.loadPatches()")

        patchSelectorViewModel.loadPatches()

        patchSelectorViewModel.onPatchSelected = { [weak self] patch in
            guard let self = self else { return }

            Log.line(actor: "🎛️ FaceTrackerViewModel", fn: "setupPatchSelector", "onPatchSelected() callback fired for patch: \(patch.name)")

            // Future implementation: load patch by ID
            // self.loadPatchByID(Int(patch.id) ?? -1)
        }
    }

    // MARK: - AR Session Management

    func startARSessionIfNeeded(session: ARSession) {
        guard !didStartAR else { return }
        didStartAR = true

        DispatchQueue.main.async { [weak self] in
            self?.resetTracking(session: session)
        }
    }

    func resetTracking(session: ARSession) {
        faceTracker.resetTracking(session: session)
        isARSessionRunning = true
    }

    func pauseSession(session: ARSession) {
        faceTracker.pauseSession(session)
        isARSessionRunning = false
    }

    // MARK: - Patch Management

    func loadPatchByID(_ id: Int) {
        Log.line(actor: "🎛️ FaceTrackerViewModel", fn: "loadPatchByID", "loading patch id: \(id)")

        guard let settings = PatchManager.shared.getPatchData(forID: id) else {
            Log.line(actor: "🎛️ FaceTrackerViewModel", fn: "loadPatchByID", "Patch with ID \(id) not found.")
            return
        }
        loadAndApplyPatch(settings: settings, patchID: id)
    }

    private func loadAndApplyPatch(settings: PatchSettings, patchID: Int?) {
        Log.line(actor: "🎛️ FaceTrackerViewModel", fn: "loadAndApplyPatch", "loadAndApplyPatch() called for patchID: \(patchID ?? -1) with settings: \(settings)")

        VoiceConductorManager.shared.setActiveConductor(settings: settings)

        let activeConductor = VoiceConductorManager.shared.activeConductor
        activeConductor.applyConductorSpecificSettings(from: settings)

        MusicBrain.shared.updateKeyAndScale(
            key: settings.tonicKey,
            chordType: settings.tonicChord,
            scaleMask: settings.scaleMask,
            voicePitchLevel: settings.voicePitchLevel,
            noteRangeSize: settings.noteRangeSize
        )

        currentPatchName = settings.name ?? "Untitled"

        if let id = patchID {
            UserDefaults.standard.set(id, forKey: "LastPatchID")
        }
    }

    func createAndLoadNewPatch() {
        let defaultSettings = PatchSettings.default()
        VoiceConductorManager.shared.setActiveConductor(settings: defaultSettings)
        currentPatchName = defaultSettings.name ?? "Default"
    }

    func savePatch(withName name: String) {
        let currentSettings = VoiceConductorManager.shared.activeConductor.exportCurrentSettings()
        var newSettings = currentSettings
        newSettings.id = PatchManager.shared.generateNewPatchID()
        newSettings.name = name

        PatchManager.shared.save(settings: newSettings)
        PatchManager.shared.currentPatchID = newSettings.id

        // Refresh patch selector and select new patch
        patchSelectorViewModel.loadPatches()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            if let newItem = self.patchSelectorViewModel.patchBarItems.first(where: { $0.patchID == newSettings.id }) {
                self.patchSelectorViewModel.selectPatch(newItem)
            }
        }

        currentPatchName = name

        Log.line(actor: "🎛️ FaceTrackerViewModel", fn: "savePatch", "💾 New patch saved with ID \(newSettings.id) and name '\(name)'")
    }

    // MARK: - Settings Management

    func getCurrentPatchSettings() -> PatchSettings {
        let conductor = VoiceConductorManager.shared.activeConductor
        return conductor.exportCurrentSettings()
    }

    // MARK: - Face Pitch Management

    func resetFacePitchCenter() {
        Log.line(actor: "🎛️ FaceTrackerViewModel", fn: "resetFacePitchCenter", "starting with lastFacePitch: \(String(describing: faceTracker.lastFacePitch))")

        if let pitchProvider = faceTracker.getCurrentRawPitchProvider() {
            MusicBrain.currentRawPitchProvider = pitchProvider

            Log.line(actor: "🎛️ FaceTrackerViewModel", fn: "resetFacePitchCenter", "calling MusicBrain.shared.recenterPitchRangeFromCurrentFacePitch()")

            MusicBrain.shared.recenterPitchRangeFromCurrentFacePitch()
        } else {
            Log.line(actor: "🎛️ FaceTrackerViewModel", fn: "resetFacePitchCenter", "No recent face pitch available yet.")
        }
    }

    // MARK: - Button Actions

    func handleResetTrackingAction(session: ARSession) {
        resetTracking(session: session)
        resetFacePitchCenter()
    }

    func handleSavePatchAction(completion: @escaping (String) -> Void) {
        // Request patch name from UI
        completion("Patch Name Request")
    }

    func handleVoiceSettingsAction() -> PatchSettings {
        return getCurrentPatchSettings()
    }

    func handleNoteSettingsAction() -> PatchSettings {
        return getCurrentPatchSettings()
    }

    func handleChordGridToggle() {
        isChordGridVisible.toggle()
        onChordGridToggleRequested?()
    }

    func getChordGridPatchSettings() -> PatchSettings {
        let conductor = VoiceConductorManager.shared.activeConductor
        return conductor.exportCurrentSettings()
    }

    // MARK: - Stats Management

    func shouldUpdateStats(currentTime: TimeInterval) -> Bool {
        return showStats && (currentTime - lastStatsUpdate > statsUpdateInterval)
    }

    func updateStatsTimestamp(_ timestamp: TimeInterval) {
        lastStatsUpdate = timestamp
    }

    func getStatsStrings() -> (audioStats: String, musicStats: String) {
        let conductor = VoiceConductorManager.shared.activeConductor
        let bufferLength = AudioEngineManager.shared.engine.avEngine.outputNode.outputFormat(forBus: 0).sampleRate * Double(AVAudioSession.sharedInstance().ioBufferDuration)
        var audioStatsString = "Buffer Length: \(bufferLength) samples\n"
        audioStatsString += conductor.returnAudioStats()
        let musicStatsString = conductor.returnMusicStats()

        return (audioStatsString, musicStatsString)
    }

    // MARK: - Cleanup

    func cleanup() {
        AudioEngineManager.shared.removeAllInputsFromMixer()
    }
}

// MARK: - FaceTrackerDelegate

extension FaceTrackerViewModel: FaceTrackerDelegate {

    func faceTracker(_ tracker: FaceTracker, didUpdateFaceData faceData: FaceData) {
        // Update the active conductor with face data
        VoiceConductorManager.shared.activeConductor.updateWithFaceData(faceData)

        // Update stats if needed
        let now = CACurrentMediaTime()
        if shouldUpdateStats(currentTime: now) {
            let (audioStats, musicStats) = getStatsStrings()
            onStatsUpdate?(faceData, audioStats, musicStats)
            updateStatsTimestamp(now)
        }
    }

    func faceTracker(_ tracker: FaceTracker, didUpdatePitch pitch: Float) {
        // Pitch updates are already handled in didUpdateFaceData
        // This can be used for specific pitch-only updates if needed
    }

    func faceTracker(_ tracker: FaceTracker, didAddFaceAnchor anchor: ARFaceAnchor, node: SCNNode, renderer: SCNSceneRenderer) {
        Log.line(actor: "🎛️ FaceTrackerViewModel", fn: "didAddFaceAnchor", "Face anchor added")
    }

    func faceTracker(_ tracker: FaceTracker, didUpdateFaceAnchor anchor: ARFaceAnchor, node: SCNNode, renderer: SCNSceneRenderer) {
        // Face anchor updates are handled through didUpdateFaceData
    }

    func faceTracker(_ tracker: FaceTracker, didRemoveFaceAnchor anchor: ARFaceAnchor) {
        Log.line(actor: "🎛️ FaceTrackerViewModel", fn: "didRemoveFaceAnchor", "Face anchor removed")
    }

    func faceTrackerSessionWasInterrupted(_ tracker: FaceTracker) {
        AudioEngineManager.shared.setSessionInterrupted(true)
        isARSessionRunning = false
    }

    func faceTrackerSessionInterruptionEnded(_ tracker: FaceTracker) {
        AudioEngineManager.shared.setSessionInterrupted(false)
        AudioEngineManager.shared.restartEngine()
        isARSessionRunning = true
    }

    func faceTracker(_ tracker: FaceTracker, didFailWithError error: Error) {
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")

        DispatchQueue.main.async { [weak self] in
            self?.onError?("The AR session failed.", errorMessage)
        }
    }
}
