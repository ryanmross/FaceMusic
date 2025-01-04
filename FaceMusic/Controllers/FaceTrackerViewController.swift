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
    private var audioStatsManager: AudioStatsManager!
    
    private var faceAnchorsAndContentControllers: [ARFaceAnchor: VirtualContentController] = [:]
    
   
    
    private let faceDataBrain = FaceDataBrain()
    
    var currentFaceAnchor: ARFaceAnchor?
    var selectedVirtualContent: VirtualContentType! = .texture
    
    
    
    var conductor: VoiceConductor!
    
    init(conductor: VoiceConductor) {
       self.conductor = conductor
       super.init(nibName: nil, bundle: nil)
   }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    
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
        audioStatsManager = AudioStatsManager(stackView: statsStackView, title: "Audio Debugging")
        
        // Setup settings button
        createSettingsButton()
    }
  
    
    private func createSettingsButton() {
        let gearButton = UIButton(type: .system)
        gearButton.setTitle("⚙️", for: .normal)
        gearButton.frame = CGRect(x: view.frame.width - 60, y: view.frame.height - 60, width: 40, height: 40)
        gearButton.addTarget(self, action: #selector(settingsButtonTapped), for: .touchUpInside)
        view.addSubview(gearButton)
    }
    
    @objc private func settingsButtonTapped() {
        displaySettingsPopup()
    }
    
    private func displaySettingsPopup() {
        let settingsViewController = SettingsViewController()
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
        
        conductor.resumeAudio()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
        
        print("viewWillDisappear")
        conductor.pauseAudio()
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
        conductor.pauseAudio()
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        print("SessionInterruptionEnded")
        conductor.resumeAudio()
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
        
        
        // Conductor Start
        
        conductor.start()
        print("Conductor: Start")
        
        conductor.isPlaying = true
        print("Conductor: isPlaying = true")
        
        
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
        
        conductor.updateWithNewData(with: faceData)
        
        // Update stats
        faceStatsManager.updateFaceStats(with: faceData)
        
        let audioData = "Frequency: \(String(describing: conductor.voc.frequency)) \nConnection Tree: \(String(describing: conductor.voc.parameters)) \nisPlaying: \(String(describing: conductor.isPlaying)) \n"
        
        audioStatsManager.updateAudioStats(with: audioData)

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
