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

class FaceTrackerViewController: UIViewController, ARSessionDelegate {
    
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
    
    
    // loads the default VocalTractConductor(), but will be overwritten later with loadPatchByID()
    private var conductor: VoiceConductorProtocol?

    // Label for displaying patch name
    private var patchNameLabel: UILabel!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
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

        // Add patch name label overlay at the bottom of the screen
        patchNameLabel = UILabel()
        patchNameLabel.translatesAutoresizingMaskIntoConstraints = false
        patchNameLabel.text = "Untitled Patch"
        patchNameLabel.textColor = .white
        patchNameLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        patchNameLabel.textAlignment = .center
        patchNameLabel.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        patchNameLabel.layer.cornerRadius = 8
        patchNameLabel.layer.masksToBounds = true

        view.addSubview(patchNameLabel)

        NSLayoutConstraint.activate([
            patchNameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            patchNameLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            patchNameLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            patchNameLabel.heightAnchor.constraint(equalToConstant: 30)
        ])

        // Observe patch change notifications
        NotificationCenter.default.addObserver(self, selector: #selector(updatePatchNameLabel), name: NSNotification.Name("PatchDidChange"), object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func updatePatchNameLabel() {
        if let id = PatchManager.shared.currentPatchID, let patch = PatchManager.shared.getPatchData(forID: id) {
            patchNameLabel.text = patch.name ?? "Untitled Patch"
        }
    }
  
    
    private func createButtons() {
        // Create buttons with SF Symbols and consistent tint
        let gearButton = UIButton(type: .system)
        gearButton.setImage(UIImage(systemName: "pianokeys"), for: .normal)
        gearButton.tintColor = .white
        gearButton.translatesAutoresizingMaskIntoConstraints = false
        gearButton.addTarget(self, action: #selector(noteSettingsButtonTapped), for: .touchUpInside)

        let folderButton = UIButton(type: .system)
        folderButton.setImage(UIImage(systemName: "folder.fill"), for: .normal)
        folderButton.tintColor = .white
        folderButton.translatesAutoresizingMaskIntoConstraints = false
        folderButton.addTarget(self, action: #selector(openPatchTapped), for: .touchUpInside)

        let plusButton = UIButton(type: .system)
        plusButton.setImage(UIImage(systemName: "plus.circle.fill"), for: .normal)
        plusButton.tintColor = .white
        plusButton.translatesAutoresizingMaskIntoConstraints = false
        plusButton.addTarget(self, action: #selector(newPatchTapped), for: .touchUpInside)

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

        // Stack the buttons vertically: plus at top, then folder, then voiceSettings, then gear, then reset at bottom
        let buttonStack = UIStackView(arrangedSubviews: [plusButton, folderButton, voiceSettingsButton, gearButton, resetButton])
        buttonStack.axis = .vertical
        buttonStack.alignment = .center
        buttonStack.spacing = 10
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(buttonStack)

        // Constraints: align to lower right (safe area), plus at top, reset at bottom
        NSLayoutConstraint.activate([
            buttonStack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            buttonStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
        // Set fixed size for all buttons
        [gearButton, folderButton, plusButton, voiceSettingsButton, resetButton].forEach { btn in
            btn.widthAnchor.constraint(equalToConstant: 40).isActive = true
            btn.heightAnchor.constraint(equalToConstant: 40).isActive = true
        }
    }
    
    
    // MARK: - Plus Button / New Patch
    @objc private func newPatchTapped() {
        let defaults = PatchSettings.default()
        // If the current patch has no name or is untitled, prompt to save
        if let conductor = self.conductor, (conductor.exportCurrentSettings().name == nil || conductor.exportCurrentSettings().name == "Untitled Patch") {
            print("FaceTrackerViewController.newPatchTapped(): Prompting to save patch")
            AlertHelper.promptToSavePatch(
                presenter: self,
                saveHandler: { [weak self] patchName in
                    guard let self = self else { return }
                    let newID = PatchManager.shared.generateNewPatchID()
                    let currentSettings = PatchSettings(
                        id: newID,
                        name: patchName ?? "Untitled Patch",
                        key: MusicBrain.shared.currentKey,
                        chordType: conductor.chordType,
                        numOfVoices: conductor.numOfVoices,
                        vibratoAmount: conductor.vibratoAmount,
                        glissandoSpeed: conductor.glissandoSpeed,
                        lowestNote: conductor.lowestNote,
                        highestNote: conductor.highestNote,
                        activeVoiceID: type(of: conductor).id
                    )
                    PatchManager.shared.save(settings: currentSettings, forID: newID)
                    NotificationCenter.default.post(name: NSNotification.Name("PatchDidChange"), object: nil)
                    self.createAndLoadNewPatch()
                },
                skipHandler: { [weak self] in
                    self?.createAndLoadNewPatch()
                }
            )
        } else {
            // Otherwise, create and load a new patch immediately
            self.createAndLoadNewPatch()
        }
    }

    // MARK: - Folder Button / Load Patch
    @objc private func openPatchTapped() {
        let patchListVC = PatchListViewController()
        patchListVC.onPatchSelected = { [weak self] patchID, settings in
            guard let self = self else { return }
            guard let settings = settings else {
                print("Could not load settings for patch ID \(patchID)")
                return
            }
            self.loadAndApplyPatch(settings: settings, patchID: patchID)
        }
        let nav = UINavigationController(rootViewController: patchListVC)
        present(nav, animated: true)
    }

    // Loads a patch by its ID, dynamically selects the VoiceConductor implementation,
    // initializes it, applies the settings, and assigns it to self.conductor.
    func loadPatchByID(_ id: Int) {
        print("FaceTrackerViewController.loadPatchById(\(id))")
        guard let settings = PatchManager.shared.getPatchData(forID: id) else {
            print("FaceTrackerViewController.loadPatchByID: Patch with ID \(id) not found.")
            return
        }
        self.loadAndApplyPatch(settings: settings, patchID: id)
    }

    // MARK: - Voice Settings Button
    @objc private func voiceSettingsButtonTapped() {
        let voiceSettingsViewController = VoiceSettingsViewController()
        
        if let conductor = conductor {
            voiceSettingsViewController.patchSettings = conductor.exportCurrentSettings()
        }
        
        voiceSettingsViewController.conductor = self.conductor

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
        let noteSettingsViewController = NoteSettingsViewController()

        if let conductor = conductor {
            noteSettingsViewController.patchSettings = conductor.exportCurrentSettings()
        }

        // Pass the conductor instance to SettingsViewController
        noteSettingsViewController.conductor = self.conductor

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

        AudioEngineManager.shared.removeAllInputsFromMixer()
        conductor = nil

        let newConductor = VocalTractConductor()
        newConductor.applySettings(defaultSettings)

        self.conductor = newConductor
        AudioEngineManager.shared.addToMixer(node: newConductor.outputNode)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        UIApplication.shared.isIdleTimerDisabled = true
        resetTracking()

        let patchManager = PatchManager.shared
        if !PatchManager.shared.listPatches().isEmpty {
            if let lastID = patchManager.currentPatchID {
                print("FaceTrackerViewController.viewWillAppear: Loading last patch ID with loadPatchByID(\(lastID))")
                if let settings = patchManager.getPatchData(forID: lastID) {
                    self.loadAndApplyPatch(settings: settings, patchID: lastID)
                }
            } else if let firstID = patchManager.listPatches().first {
                print("FaceTrackerViewController.viewWillAppear: Loading first patch ID with loadPatchByID(\(firstID))")
                if let settings = patchManager.getPatchData(forID: firstID) {
                    self.loadAndApplyPatch(settings: settings, patchID: firstID)
                }
            }
        } else {
            let defaultSettings = patchManager.defaultPatchSettings
            let newID = patchManager.generateNewPatchID()
            patchManager.save(settings: defaultSettings, forID: newID)
            UserDefaults.standard.set(newID, forKey: "LastPatchID")
            print("FaceTrackerViewController.viewWillAppear: Creating new patch ID with loadPatchByID(\(newID))")
            self.loadAndApplyPatch(settings: defaultSettings, patchID: newID)
        }

        if conductor == nil {
            print("FaceTrackerViewController.viewWillAppear: Conductor is nil.  Creating new conductor")
            let newConductor = VocalTractConductor()
            newConductor.applySettings(PatchManager.shared.defaultPatchSettings)
            conductor = newConductor
        }
        // Create a session configuration
        //let configuration = ARWorldTrackingConfiguration()
        // Run the view's session
        //sceneView.session.run(configuration)
    }

    // MARK: - Patch Loading Helper
    private func loadAndApplyPatch(settings: PatchSettings, patchID: Int?) {
        let selectedID = settings.activeVoiceID
        let conductorType = VoiceConductorRegistry.allTypes.first { $0.id == selectedID } ?? VocalTractConductor.self

        AudioEngineManager.shared.removeAllInputsFromMixer()
        conductor = nil

        let newConductor = conductorType.init()
        newConductor.applySettings(settings)

        MusicBrain.shared.updateKeyAndScale(
            key: settings.key,
            chordType: settings.chordType,
            scaleMask: settings.scaleMask
        )

        self.conductor = newConductor
        patchNameLabel.text = settings.name ?? "Untitled Patch"

        if let id = patchID {
            UserDefaults.standard.set(id, forKey: "LastPatchID")
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("FaceTrackerViewController: viewDidAppear")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
        
        print("FaceTrackerViewController.viewWillDisappear: Removing all inputs mixer")
        AudioEngineManager.shared.removeAllInputsFromMixer()
        conductor = nil

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
        
        print("FaceTrackerViewController.SessionWasInterrupted.")
        //AudioEngineManager.shared.removeAllInputsFromMixer()
        //conductor = nil

    }
        
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
        print("FaceTrackerViewController.sessionInterruptionEnded.")
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
        conductor?.updateWithFaceData(faceData)
        
        // Throttle stats updates to 4 times per second
        let now = CACurrentMediaTime()
        if now - lastStatsUpdate > 0.25 {
            faceStatsManager.updateFaceStats(with: faceData)
            if let conductor = conductor {
                let bufferLength = AudioEngineManager.shared.engine.avEngine.outputNode.outputFormat(forBus: 0).sampleRate * Double(AVAudioSession.sharedInstance().ioBufferDuration)
                var audioStatsString = "Buffer Length: \(bufferLength) samples\n"
                audioStatsString += conductor.returnAudioStats()
                audioStatsManager.updateStats(with: audioStatsString)
                musicStatsManager.updateStats(with: conductor.returnMusicStats())
            }
            lastStatsUpdate = now
        }
        
        contentController.renderer(renderer, didUpdate: contentNode, for: anchor)
        // Update the content controller with new data.
    }

    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        // Handle the removal of an ARFaceAnchor.

        print("FaceTrackerViewController.renderer.didRemove: REMOVED AR ANCHOR")
        
        faceAnchorsAndContentControllers[faceAnchor] = nil
        // Remove the face anchor from the dictionary.
    }
    
    
}




