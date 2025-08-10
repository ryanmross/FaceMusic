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
    
    var statsStackView: UIStackView!
    
    private var faceStatsManager: FaceStatsManager!
    private var audioStatsManager: StatsWindowManager!
    private var musicStatsManager: StatsWindowManager!
    
    private var faceAnchorsAndContentControllers: [ARFaceAnchor: VirtualContentController] = [:]
    
    private var lastStatsUpdate: TimeInterval = 0
    
   
    
    private let faceDataBrain = FaceDataBrain()
    
    var currentFaceAnchor: ARFaceAnchor?
    var selectedVirtualContent: VirtualContentType! = .texture
    
    private var didStartAR = false
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("😮 FaceTrackerViewController: ARVC viewDidLoad  bounds:", sceneView.bounds, "scale:", sceneView.contentScaleFactor)
        
        // Set the view's delegate
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.automaticallyUpdatesLighting = true
        sceneView.preferredFramesPerSecond = 24 // Lower frame rate to prioritize audio
        
        // Show statistics such as fps and timing information for testing purposes
        sceneView.showsStatistics = true
        
        
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
        

        
        // Initialize stat box for testing purposes
        faceStatsManager = FaceStatsManager(stackView: statsStackView, title: "Face Tracking")
        audioStatsManager = StatsWindowManager(stackView: statsStackView, title: "Audio Debugging")
        musicStatsManager = StatsWindowManager(stackView: statsStackView, title: "Music Debugging")
        
        // Setup settings button
        createButtons()




        // Add PatchSelectorView as a SwiftUI hosting controller at the bottom
        let patchSelectorView = PatchSelectorViewRepresentable(viewModel: patchSelectorViewModel)
        let hostingController = UIHostingController(rootView: patchSelectorView)
        self.patchSelectorHostingController = hostingController

        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)

        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = .clear
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            hostingController.view.heightAnchor.constraint(equalToConstant: 100)
        ])
        
        print("😮 FaceTrackerViewController.viewDidLoad calling patchSelectorViewModel.loadPatches()")
        patchSelectorViewModel.loadPatches()
        
       
        
        patchSelectorViewModel.onPatchSelected = { [weak self] patch in
            guard let self = self else { return }
            
            print("😮 FaceTrackerViewController.viewDidLoad onPatchSelected() callback fired")
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

        let resetButton = UIButton(type: .system)
        resetButton.setImage(UIImage(systemName: "person.fill.viewfinder"), for: .normal)
        resetButton.tintColor = .white
        resetButton.translatesAutoresizingMaskIntoConstraints = false
        resetButton.addTarget(self, action: #selector(resetTrackingTapped), for: .touchUpInside)

        // Stack the buttons vertically: savePatch, voiceSettings, gear, reset
        let buttonStack = UIStackView(arrangedSubviews: [voiceSettingsButton, gearButton, resetButton, savePatchButton])
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
        [savePatchButton, gearButton, voiceSettingsButton, resetButton].forEach { btn in
            btn.widthAnchor.constraint(equalToConstant: 40).isActive = true
            btn.heightAnchor.constraint(equalToConstant: 40).isActive = true
        }
    }
    
    

    // Loads a patch by its ID, dynamically selects the VoiceConductor implementation,
    // initializes it, applies the settings, and assigns it to self.conductor.
    func loadPatchByID(_ id: Int) {
        print("😮 FaceTrackerViewController.loadPatchById(\(id))")
        guard let settings = PatchManager.shared.getPatchData(forID: id) else {
            print("😮 FaceTrackerViewController.loadPatchByID: Patch with ID \(id) not found.")
            return
        }
        self.loadAndApplyPatch(settings: settings, patchID: id)
    }
    
    // MARK: - Save Patch Button
    @objc private func savePatchButtonTapped() {
        print("👉 FaceTrackerViewController.savePatchButtonTapped")
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
            print("💾 New patch saved with ID \(newSettings.id) and name '\(name)'")
        }))
        present(alert, animated: true, completion: nil)
    }

    // MARK: - Voice Settings Button
    @objc private func voiceSettingsButtonTapped() {
        let voiceSettingsViewController = VoiceSettingsViewController()

        let conductor = VoiceConductorManager.shared.activeConductor
        let settings = conductor.exportCurrentSettings()
        voiceSettingsViewController.patchSettings = settings
        
        print("😮 FaceTrackerViewController.voiceSettingsButtonTapped  settings: \(settings)")
        
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
        
        print("👉 FaceTrackerViewController.noteSettingsButtonTapped()")
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
        print("😮 FaceTrackerVC didAppear bounds:", sceneView.bounds, "scale:", sceneView.contentScaleFactor)
        guard !didStartAR else { return }
        didStartAR = true
        DispatchQueue.main.async { [weak self] in
            self?.resetTracking() // same ARFaceTrackingConfiguration, just started later
        }

    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
        
        print("😮 FaceTrackerViewController.viewWillDisappear: Removing all inputs mixer")
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
        print("😮 FaceTrackerViewController.loadAndApplyPatch() called for patchID: \(patchID ?? -1) with settings: \(settings)")

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
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
        print("😮 FaceTrackerViewController.SessionWasInterrupted.")
        //AudioEngineManager.shared.removeAllInputsFromMixer()
        //conductor = nil

    }
        
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
        print("😮 FaceTrackerViewController.sessionInterruptionEnded.")
        //AudioEngineManager.shared.addToMixer(node: conductor.outputNode)
        //resetTracking()
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
        
        // Update Conductor with new face data
        VoiceConductorManager.shared.activeConductor.updateWithFaceData(faceData)
        
        // Throttle stats updates to 4 times per second
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
        
        contentController.renderer(renderer, didUpdate: contentNode, for: anchor)
        // Update the content controller with new data.
    }

    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        // Handle the removal of an ARFaceAnchor.

        print("😮 FaceTrackerViewController.renderer.didRemove: REMOVED AR ANCHOR")
        
        faceAnchorsAndContentControllers[faceAnchor] = nil
        // Remove the face anchor from the dictionary.
    }
    
    
}





   
