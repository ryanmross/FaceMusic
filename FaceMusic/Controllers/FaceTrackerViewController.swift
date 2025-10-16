//
//  ViewController.swift
//  FaceMusic
//
//  Created by Ryan Ross on 6/11/24.
//

import UIKit
import SceneKit
import ARKit
import SwiftEntryKit
import SwiftUI

class FaceTrackerViewController: UIViewController, ARSessionDelegate {
    
    private var patchSelectorHostingController: UIHostingController<PatchSelectorViewRepresentable>?
    private var patchSelectorViewModel = PatchSelectorViewModel()
    @IBOutlet weak var sceneView: ARSCNView!
    
    private var chordGridHostingController: UIViewController?
    
    private var bottomOverlayStackView: UIStackView!
    
    var statsStackView: UIStackView!
    
    private var faceStatsManager: FaceStatsManager!
    private var audioStatsManager: StatsWindowManager!
    private var musicStatsManager: StatsWindowManager!
    
    private var faceAnchorsAndContentControllers: [ARFaceAnchor: VirtualContentController] = [:]
    
    private let showStats = false
    private var lastStatsUpdate: TimeInterval = 0
    
    private let faceDataBrain = FaceDataBrain.shared
    private var lastFacePitch: Float?
    
    var currentFaceAnchor: ARFaceAnchor?
    var selectedVirtualContent: VirtualContentType! = .texture
    
    private var didStartAR = false
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Log.line(actor: "😮 FaceTrackerViewController", fn: "viewDidLoad", "ARVC viewDidLoad bounds: \(sceneView.bounds), scale: \(sceneView.contentScaleFactor)")
        
        // Set the view's delegate
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.automaticallyUpdatesLighting = true
        sceneView.preferredFramesPerSecond = 24 // Lower frame rate to prioritize audio
        
        // Show statistics such as fps and timing information for testing purposes
        sceneView.showsStatistics = false
        
        
        
        if showStats {
            statsStackView = UIStackView()
            statsStackView.axis = .vertical
            statsStackView.spacing = 10
            statsStackView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(statsStackView)

            NSLayoutConstraint.activate([
                statsStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
                statsStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
                statsStackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10)
            ])

            // Initialize stat boxes
            faceStatsManager = FaceStatsManager(stackView: statsStackView, title: "Face Tracking")
            audioStatsManager = StatsWindowManager(stackView: statsStackView, title: "Audio Debugging")
            musicStatsManager = StatsWindowManager(stackView: statsStackView, title: "Music Debugging")
        }
         
         
        // Setup settings button
        createButtons()




        // Create a bottom overlay stack view to host dismissable bottom overlays
        bottomOverlayStackView = UIStackView()
        bottomOverlayStackView.axis = .vertical
        bottomOverlayStackView.distribution = .fill
        bottomOverlayStackView.alignment = .fill
        bottomOverlayStackView.layoutMargins = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        bottomOverlayStackView.spacing = 0
        //bottomOverlayStackView.backgroundColor = .white.withAlphaComponent(0.2)
        bottomOverlayStackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomOverlayStackView)

        NSLayoutConstraint.activate([
            bottomOverlayStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomOverlayStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomOverlayStackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])

        // Add PatchSelectorView as a SwiftUI hosting controller at the bottom (inside the stack)
        let patchSelectorView = PatchSelectorViewRepresentable(viewModel: patchSelectorViewModel)
        let hostingController = UIHostingController(rootView: patchSelectorView)
        self.patchSelectorHostingController = hostingController

        addChild(hostingController)
        bottomOverlayStackView.addArrangedSubview(hostingController.view)
        hostingController.didMove(toParent: self)

        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = .clear
        // Keep explicit height so the stack knows how tall the patch selector is
        hostingController.view.heightAnchor.constraint(equalToConstant: 100).isActive = true
        hostingController.view.leadingAnchor.constraint(equalTo: bottomOverlayStackView.leadingAnchor).isActive = true
        hostingController.view.trailingAnchor.constraint(equalTo: bottomOverlayStackView.trailingAnchor).isActive = true
        
        
        Log.line(actor: "😮 FaceTrackerViewController", fn: "viewDidLoad", "calling patchSelectorViewModel.loadPatches()")

        patchSelectorViewModel.loadPatches()
        
       
        
        patchSelectorViewModel.onPatchSelected = { [weak self] patch in
            guard let self = self else { return }
            
            Log.line(actor: "😮 FaceTrackerViewController", fn: "viewDidLoad", "onPatchSelected() callback fired but callback does nothing currently.")

            //self.loadPatchByID(Int(patch.id) ?? -1)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

  
    
    private func createButtons() {
        // Create buttons with SF Symbols and consistent tint
        let savePatchButton = UIButton(type: .system)
        savePatchButton.setImage(UIImage(systemName: "plus.circle"), for: .normal)
        savePatchButton.tintColor = .white
        savePatchButton.translatesAutoresizingMaskIntoConstraints = false
        savePatchButton.addTarget(self, action: #selector(savePatchButtonTapped), for: .touchUpInside)

        let gearButton = UIButton(type: .system)
        gearButton.setImage(UIImage(systemName: "pianokeys"), for: .normal)
        gearButton.tintColor = .white
        gearButton.translatesAutoresizingMaskIntoConstraints = false
        gearButton.addTarget(self, action: #selector(noteSettingsButtonTapped), for: .touchUpInside)

        let voiceSettingsButton = UIButton(type: .system)
        voiceSettingsButton.setImage(UIImage(systemName: "waveform.path.ecg.rectangle.fill"), for: .normal)
        voiceSettingsButton.tintColor = .white
        voiceSettingsButton.translatesAutoresizingMaskIntoConstraints = false
        voiceSettingsButton.addTarget(self, action: #selector(voiceSettingsButtonTapped), for: .touchUpInside)

        let chordGridButton = UIButton(type: .system)
        chordGridButton.setImage(UIImage(systemName: "circle.grid.3x3"), for: .normal)
        chordGridButton.tintColor = .white
        chordGridButton.translatesAutoresizingMaskIntoConstraints = false
        chordGridButton.addTarget(self, action: #selector(toggleChordGridTapped), for: .touchUpInside)

        let resetButton = UIButton(type: .system)
        resetButton.setImage(UIImage(systemName: "person.fill.viewfinder"), for: .normal)
        resetButton.tintColor = .white
        resetButton.translatesAutoresizingMaskIntoConstraints = false
        resetButton.addTarget(self, action: #selector(resetTrackingTapped), for: .touchUpInside)

        // Stack the buttons vertically: savePatch, voiceSettings, gear, chordGrid, reset
        let buttonStack = UIStackView(arrangedSubviews: [voiceSettingsButton, gearButton, chordGridButton, resetButton, savePatchButton])
        buttonStack.axis = .vertical
        buttonStack.alignment = .center
        buttonStack.spacing = 10
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(buttonStack)

        // Constraints: align to upper right (safe area), plus at top, reset at bottom
        NSLayoutConstraint.activate([
            buttonStack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            buttonStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20)
        ])
        // Set fixed size for all buttons
        [savePatchButton, gearButton, voiceSettingsButton, chordGridButton, resetButton].forEach { btn in
            btn.widthAnchor.constraint(equalToConstant: 40).isActive = true
            btn.heightAnchor.constraint(equalToConstant: 40).isActive = true
        }
    }

    @objc private func toggleChordGridTapped() {
        if let controller = chordGridHostingController {
            Log.line(actor: "😮 FaceTrackerViewController", fn: "toggleChordGridTapped", "let controller = chordGridHostingController")
            // remove from stack
            controller.willMove(toParent: UIViewController?.none)
            bottomOverlayStackView.removeArrangedSubview(controller.view)
            controller.view.removeFromSuperview()
            controller.removeFromParent()
            chordGridHostingController = nil
        } else {
            Log.line(actor: "😮 FaceTrackerViewController", fn: "toggleChordGridTapped", "let controller is nil, so create a new chordGridHostingController")
            let chordGridViewModel = ChordGridViewModel()
            let chordGridView = ChordGridView(viewModel: chordGridViewModel)
            let controller = UIViewController()
            controller.view = chordGridView
            controller.view.backgroundColor = .clear
            chordGridHostingController = controller

            addChild(controller)
            controller.view.translatesAutoresizingMaskIntoConstraints = false
            bottomOverlayStackView.insertArrangedSubview(controller.view, at: 0)
            controller.didMove(toParent: self)
            controller.view.translatesAutoresizingMaskIntoConstraints = false
            
            // Dynamically calculate height based on rows
            let rowHeight: CGFloat = 60.0 // Adjust per your button + spacing
            let rowCount = max(1, AppSettings().chordGridRows)
            let totalHeight = rowHeight * CGFloat(rowCount) + 20.0 // Add padding
            controller.view.heightAnchor.constraint(equalToConstant: totalHeight).isActive = true
            controller.view.leadingAnchor.constraint(equalTo: bottomOverlayStackView.leadingAnchor).isActive = true
            controller.view.trailingAnchor.constraint(equalTo: bottomOverlayStackView.trailingAnchor).isActive = true
        }
    }
    
    

    // Loads a patch by its ID, dynamically selects the VoiceConductor implementation,
    // initializes it, applies the settings, and assigns it to self.conductor.
    func loadPatchByID(_ id: Int) {
        
        Log.line(actor: "😮 FaceTrackerViewController", fn: "loadPatchByID", "loading patch id: \(id)")

        
        guard let settings = PatchManager.shared.getPatchData(forID: id) else {
            Log.line(actor: "😮 FaceTrackerViewController", fn: "loadPatchByID", "Patch with ID \(id) not found.")
            return
        }
        self.loadAndApplyPatch(settings: settings, patchID: id)
    }
    
    // MARK: - Save Patch Button
    @objc private func savePatchButtonTapped() {
        Log.line(actor: "👉 FaceTrackerViewController", fn: "savePatchButtonTapped", "SavePatchButtonTapped() called")

        
        let alert = UIAlertController(title: "Save Patch", message: "Enter name to save patch:", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "Patch name"
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
            guard let name = alert.textFields?.first?.text, !name.isEmpty else { return }

            let currentSettings = VoiceConductorManager.shared.activeConductor.exportCurrentSettings()
            var newSettings = currentSettings
            newSettings.id = PatchManager.shared.generateNewPatchID()
            newSettings.name = name

            PatchManager.shared.save(settings: newSettings)
            PatchManager.shared.currentPatchID = newSettings.id
            // Refresh patch selector and select new patch
            self.patchSelectorViewModel.loadPatches()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let newItem = self.patchSelectorViewModel.patchBarItems.first(where: { $0.patchID == newSettings.id }) {
                    self.patchSelectorViewModel.selectPatch(newItem)
                }
            }
            Log.line(actor: "😮 FaceTrackerViewController", fn: "savePatchButtonTapped", "💾 New patch saved with ID \(newSettings.id) and name '\(name)'")

        }))
        present(alert, animated: true, completion: nil)
    }

    // MARK: - Voice Settings Button
    @objc private func voiceSettingsButtonTapped() {
        let voiceSettingsViewController = VoiceSettingsViewController()

        let conductor = VoiceConductorManager.shared.activeConductor
        let settings = conductor.exportCurrentSettings()
        voiceSettingsViewController.patchSettings = settings
        
        Log.line(actor: "😮 FaceTrackerViewController", fn: "voiceSettingsButtonTapped", "settings: \(settings)")

        
        var attributes = EKAttributes()
        attributes.displayDuration = .infinity
        attributes.name = "Voice Settings"
        attributes.windowLevel = .normal
        attributes.position = .center
        attributes.entryInteraction = .absorbTouches
        attributes.screenInteraction = .dismiss
        attributes.scroll = .enabled(swipeable: true, pullbackAnimation: .easeOut)
        attributes.positionConstraints = .fullScreen
        attributes.screenBackground = .color(color: EKColor(UIColor.black.withAlphaComponent(0.3)))
        attributes.entryBackground = .clear

        SwiftEntryKit.display(entry: voiceSettingsViewController, using: attributes)
    }

    // MARK: - Note Settings Button
    @objc private func noteSettingsButtonTapped() {
        
        Log.line(actor: "👉 FaceTrackerViewController", fn: "noteSettingsButtonTapped", "noteSettingsButtonTapped() called")

        
        
        let noteSettingsViewController = NoteSettingsViewController()

        let conductor = VoiceConductorManager.shared.activeConductor
        noteSettingsViewController.patchSettings = conductor.exportCurrentSettings()
        

        // noteSettingsViewController.conductor = self.conductor

        var attributes = EKAttributes()
        attributes.displayDuration = .infinity
        attributes.name = "Note Settings"
        attributes.windowLevel = .normal
        attributes.position = .center
        attributes.entryInteraction = .absorbTouches
        attributes.screenInteraction = .dismiss
        attributes.scroll = .enabled(swipeable: true, pullbackAnimation: .easeOut)
        attributes.positionConstraints = .fullScreen
        attributes.screenBackground = .color(color: EKColor(UIColor.black.withAlphaComponent(0.3)))
        attributes.entryBackground = .clear

        SwiftEntryKit.display(entry: noteSettingsViewController, using: attributes)
    }
    
    // MARK: - Reset Tracking Button
    @objc private func resetTrackingTapped() {
        resetTracking()
        resetFacePitchCenter()
    }

    private func createAndLoadNewPatch() {
        let defaultSettings = PatchSettings.default()
        VoiceConductorManager.shared.setActiveConductor(settings: defaultSettings)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        
        UIApplication.shared.isIdleTimerDisabled = true
        
    }


    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        Log.line(actor: "😮 FaceTrackerViewController", fn: "viewDidAppear", "FaceTrackerVC didAppear bounds: \(sceneView.bounds) scale: \(sceneView.contentScaleFactor)")


        guard !didStartAR else { return }
        didStartAR = true
        DispatchQueue.main.async { [weak self] in
            self?.resetTracking() // same ARFaceTrackingConfiguration, just started later
        }
        
        patchSelectorViewModel.scrollToCenterOfSelectedPatch(animated: false)


    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
        
        Log.line(actor: "😮 FaceTrackerViewController", fn: "viewWillDisappear", "Removing all inputs mixer")
        AudioEngineManager.shared.removeAllInputsFromMixer()
        // conductor = nil
    }
    
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        guard error is ARError else { return }
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
        
        DispatchQueue.main.async {
            self.displayErrorMessage(title: "The AR session failed.", message: errorMessage)
        }
    }
    
    
    // MARK: - Patch Loading Helper
    private func loadAndApplyPatch(settings: PatchSettings, patchID: Int?) {
        
        Log.line(actor: "😮 FaceTrackerViewController", fn: "loadAndApplyPatch", "loadAndApplyPatch() called for patchID: \(patchID ?? -1) with settings: \(settings)")

        VoiceConductorManager.shared.setActiveConductor(settings: settings)

        let activeConductor = VoiceConductorManager.shared.activeConductor
        activeConductor.applyConductorSpecificSettings(from: settings)

        MusicBrain.shared.updateKeyAndScale(
            key: settings.key,
            chordType: settings.chordType,
            scaleMask: settings.scaleMask
        )


        if let id = patchID {
            UserDefaults.standard.set(id, forKey: "LastPatchID")
        }
    }
    
    /// - Tag: ARFaceTrackingSetup
    func resetTracking() {
        guard ARFaceTrackingConfiguration.isSupported else { return }
        let configuration = ARFaceTrackingConfiguration()
        
        
        configuration.maximumNumberOfTrackedFaces = 1

        configuration.isLightEstimationEnabled = false
        
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        
        
        
        
        
        faceAnchorsAndContentControllers.removeAll()
        
        
    }
    
    /// - Tag: resetFacePitchCenter
    func resetFacePitchCenter() {
        // Recenter MusicBrain pitch range using the most recent cached face pitch if available
        if let pitch = lastFacePitch {
            MusicBrain.currentRawPitchProvider = { [weak self] in
                // Prefer the freshest cached pitch; if missing, fall back to processing current anchor
                if let latest = self?.lastFacePitch {
                    return latest
                } else if let current = self?.currentFaceAnchor {
                    return self?.faceDataBrain.processFaceData(current).pitch ?? pitch
                } else {
                    return pitch
                }
            }
            
            Log.line(actor: "😮 FaceTrackerViewController", fn: "resetFacePitchCenter", "calling MusicBrain.shared.recenterPitchRangeFromCurrentFacePitch()")

            MusicBrain.shared.recenterPitchRangeFromCurrentFacePitch()
        } else {
            
            Log.line(actor: "😮 FaceTrackerViewController", fn: "resetFacePitchCenter", "No recent face pitch available yet.")

        }
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        Log.line(actor: "😮 ⬅️📱 FaceTrackerViewController", fn: "sessionWasInterrupted", "")
        AudioEngineManager.shared.setSessionInterrupted(true)
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        Log.line(actor: "😮 ➡️📱 FaceTrackerViewController", fn: "sessionInterruptionEnded", "")
        AudioEngineManager.shared.setSessionInterrupted(false)
        AudioEngineManager.shared.restartEngine()
    }
    
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
        // Indicate whether the home indicator should be hidden.
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
        // Indicate whether the status bar should be hidden.
    }
    
    // MARK: - Error handling
    
    func displayErrorMessage(title: String, message: String) {
        // Present an alert informing about the error that has occurred.
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
            alertController.dismiss(animated: true, completion: nil)
            self.resetTracking()
        }
        alertController.addAction(restartAction)
        present(alertController, animated: true, completion: nil)
    }
}

//MARK: - ARSCNViewDelegate
extension FaceTrackerViewController: ARSCNViewDelegate {
    
    func renderer(_ renderer: any SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        

        // If this is the first time with this anchor, get the controller to create content.
        // Otherwise (switching content), will change content when setting `selectedVirtualContent`.
        DispatchQueue.main.async {
            let contentController = self.selectedVirtualContent.makeController()
            if node.childNodes.isEmpty, let contentNode = contentController.renderer(renderer, nodeFor: faceAnchor) {
                node.addChildNode(contentNode)
                self.faceAnchorsAndContentControllers[faceAnchor] = contentController
            }
        }
        // Add virtual content to the scene when a face is detected.
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor,
              let contentController = faceAnchorsAndContentControllers[faceAnchor],
              let contentNode = contentController.contentNode else {
            return
        }
        
        let faceData = faceDataBrain.processFaceData(faceAnchor)
        self.lastFacePitch = faceData.pitch
        
        // Update Conductor with new face data
        VoiceConductorManager.shared.activeConductor.updateWithFaceData(faceData)
        
        // Throttle stats updates to 4 times per second
        if showStats {
            let now = CACurrentMediaTime()
            if now - lastStatsUpdate > 0.25 {
                faceStatsManager.updateFaceStats(with: faceData)
                let conductor = VoiceConductorManager.shared.activeConductor
                let bufferLength = AudioEngineManager.shared.engine.avEngine.outputNode.outputFormat(forBus: 0).sampleRate * Double(AVAudioSession.sharedInstance().ioBufferDuration)
                var audioStatsString = "Buffer Length: \(bufferLength) samples\n"
                audioStatsString += conductor.returnAudioStats()
                audioStatsManager.updateStats(with: audioStatsString)
                musicStatsManager.updateStats(with: conductor.returnMusicStats())
                lastStatsUpdate = now
            }
        }
        
        contentController.renderer(renderer, didUpdate: contentNode, for: anchor)
        // Update the content controller with new data.
    }

    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        // Handle the removal of an ARFaceAnchor.

        Log.line(actor: "😮 FaceTrackerViewController", fn: "renderer.didRemove", "REMOVED AR ANCHOR")

        
        faceAnchorsAndContentControllers[faceAnchor] = nil
        // Remove the face anchor from the dictionary.
    }
    
    
}





   



