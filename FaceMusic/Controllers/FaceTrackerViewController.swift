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
    }
  
    
    private func createButtons() {
        // Create buttons with SF Symbols and consistent tint
        let gearButton = UIButton(type: .system)
        gearButton.setImage(UIImage(systemName: "gearshape.fill"), for: .normal)
        gearButton.tintColor = .white
        gearButton.translatesAutoresizingMaskIntoConstraints = false
        gearButton.addTarget(self, action: #selector(settingsButtonTapped), for: .touchUpInside)

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

        // Stack the buttons vertically, plus at top, then folder, then gear at bottom
        let buttonStack = UIStackView(arrangedSubviews: [plusButton, folderButton, gearButton])
        buttonStack.axis = .vertical
        buttonStack.alignment = .center
        buttonStack.spacing = 10
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(buttonStack)

        // Constraints: align to lower right (safe area), plus at top, gear at bottom
        NSLayoutConstraint.activate([
            buttonStack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            buttonStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
        // Set fixed size for all buttons
        [gearButton, folderButton, plusButton].forEach { btn in
            btn.widthAnchor.constraint(equalToConstant: 40).isActive = true
            btn.heightAnchor.constraint(equalToConstant: 40).isActive = true
        }
    }
    
    @objc private func settingsButtonTapped() {
        displaySettingsPopup()
    }
    
    @objc private func newPatchTapped() {
        let defaults = PatchSettings.default()
        // If the current patch has no name or is untitled, prompt to save
        if let conductor = self.conductor, (conductor.exportCurrentSettings().name == nil || conductor.exportCurrentSettings().name == "Untitled Patch") {
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
                        glissandoSpeed: conductor.glissandoSpeed,
                        lowestNote: conductor.lowestNote,
                        highestNote: conductor.highestNote,
                        activeVoiceID: type(of: conductor).id
                    )
                    PatchManager.shared.save(settings: currentSettings, forID: newID)
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

    private func createAndLoadNewPatch() {
        let defaultSettings = PatchSettings.default()
        
        // Stop the old conductor
        self.conductor?.stopEngine(immediate: false)

        let newConductor = VocalTractConductor()
        newConductor.applySettings(defaultSettings)

        self.conductor = newConductor
        self.conductor?.startEngine()
    }
    
    @objc private func openPatchTapped() {
        let patchListVC = PatchListViewController()
        patchListVC.onPatchSelected = { [weak self] patchID, settings in
            guard let self = self else { return }

            guard let settings = settings else {
                print("Could not load settings for patch ID \(patchID)")
                return
            }

            let selectedID = settings.activeVoiceID
            let conductorType = VoiceConductorRegistry.allTypes.first { $0.id == selectedID } ?? VocalTractConductor.self
            
            
            self.conductor?.stopEngine(immediate: false)

            let newConductor = conductorType.init()
            newConductor.applySettings(settings)

            self.conductor = newConductor
            self.conductor?.startEngine()
            

            self.conductor = newConductor
        }

        let nav = UINavigationController(rootViewController: patchListVC)
        present(nav, animated: true)
    }
    
    // Loads a patch by its ID, dynamically selects the VoiceConductor implementation,
    // initializes it, applies the settings, and assigns it to self.conductor.
    func loadPatchByID(_ id: Int) {
        guard let settings = PatchManager.shared.load(forID: id) else {
            print("Patch with ID \(id) not found.")
            return
        }

        let selectedID = settings.activeVoiceID
        let conductorType = VoiceConductorRegistry.allTypes.first { $0.id == selectedID } ?? VocalTractConductor.self

        // Stop the old conductor
        self.conductor?.stopEngine(immediate: true)

        let newConductor = conductorType.init()
        newConductor.applySettings(settings)

        self.conductor = newConductor

        // Start the new conductor
        self.conductor?.startEngine()

        
        // Save this as the last used patch
        UserDefaults.standard.set(id, forKey: "LastPatchID")
    }
    
    private func displaySettingsPopup() {
        let settingsViewController = SettingsViewController()
        
        if let conductor = conductor {
            settingsViewController.patchSettings = conductor.exportCurrentSettings()
        }
        
        // Pass the conductor instance to SettingsViewController
        settingsViewController.conductor = self.conductor
        
        
        var attributes = EKAttributes()
        attributes.displayDuration = .infinity
        attributes.name = "Top Note"
        attributes.windowLevel = .normal
        attributes.position = .center
        attributes.entryInteraction = .absorbTouches
        attributes.screenInteraction = .dismiss
        attributes.scroll = .enabled(swipeable: true, pullbackAnimation: .easeOut)
        attributes.positionConstraints = .fullScreen
        attributes.screenBackground = .color(color: EKColor(UIColor.black.withAlphaComponent(0.3)))
        attributes.entryBackground = .clear

        SwiftEntryKit.display(entry: settingsViewController, using: attributes)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        //let configuration = ARWorldTrackingConfiguration()
        
        // Run the view's session
        //sceneView.session.run(configuration)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        print("viewDidAppear")
        
        // Actions to take when the view appears on the screen.
        UIApplication.shared.isIdleTimerDisabled = true
        
        resetTracking()
        // Disable the idle timer and reset AR tracking.
        
        let patchManager = PatchManager.shared
        
        print("patchManager.currentPatchID is: \(patchManager.currentPatchID!)")

        // Check if patches exist
        if !PatchManager.shared.listPatches().isEmpty {
            // There are saved patches
            if let lastID = patchManager.currentPatchID {
                print("Loading current patch ID: \(lastID)")
                loadPatchByID(lastID)
            } else {
                // No ID saved, load the first available patch
                if let firstID = patchManager.listPatches().first {
                    print("No last patch ID saved, loading first patch ID: \(firstID)")
                    loadPatchByID(firstID)
                }
            }
        } else {
            // No patches exist, create a new default patch
            let defaultSettings = patchManager.defaultPatchSettings
            let newID = patchManager.generateNewPatchID()
            patchManager.save(settings: defaultSettings, forID: newID)

            // Save this as the last used patch
            UserDefaults.standard.set(newID, forKey: "LastPatchID")
            loadPatchByID(newID)
        }

        if conductor == nil {
            // As a fallback, create a default conductor
            print("No conductor assigned, creating default")
            let newConductor = VocalTractConductor()
            newConductor.applySettings(PatchManager.shared.defaultPatchSettings)
            conductor = newConductor
        }
        conductor?.startEngine()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
        
        print("viewWillDisappear")
        conductor?.stopEngine(immediate: false)
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
        print("SessionWasInterrupted")
        conductor?.stopEngine(immediate: true)
    }
        
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        print("SessionInterruptionEnded")
        conductor?.startEngine()
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
                audioStatsManager.updateStats(with: conductor.returnAudioStats())
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

        print("REMOVED AR ANCHOR")
        
        faceAnchorsAndContentControllers[faceAnchor] = nil
        // Remove the face anchor from the dictionary.
    }
    
    
}
