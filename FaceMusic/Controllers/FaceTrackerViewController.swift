//
//  ViewController.swift
//  FaceMusic
//
//  Created by Ryan Ross on 6/11/24.
//

import UIKit
import SceneKit
import ARKit

class FaceTrackerViewController: UIViewController, ARSessionDelegate {

    @IBOutlet weak var sceneView: ARSCNView!
    
    private var customStatsLabel: UILabel!
    
    var faceAnchorsAndContentControllers: [ARFaceAnchor: VirtualContentController] = [:]
    var currentFaceAnchor: ARFaceAnchor?
    var selectedVirtualContent: VirtualContentType! = .texture
    
    let conductor = VoiceConductor()
    let faceDataBrain = FaceDataBrain()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.automaticallyUpdatesLighting = true
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
       
        // Create custom stats box
        createCustomStats()
        
        // Register for face data updates
        NotificationCenter.default.addObserver(self, selector: #selector(updateCustomStats(_:)), name: .faceDataUpdated, object: nil)
        
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
        // Actions to take when the view appears on the screen.
        UIApplication.shared.isIdleTimerDisabled = true
        
        resetTracking()
        // Disable the idle timer and reset AR tracking.
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
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
        if #available(iOS 13.0, *) {
            configuration.maximumNumberOfTrackedFaces = ARFaceTrackingConfiguration.supportedNumberOfTrackedFaces
        }
        configuration.isLightEstimationEnabled = true
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        
        faceAnchorsAndContentControllers.removeAll()
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
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
    
    // MARK: - Custom Stats

      func createCustomStats() {
          // Create and add a custom label
          customStatsLabel = UILabel()
          customStatsLabel.translatesAutoresizingMaskIntoConstraints = false
          customStatsLabel.textColor = .white
          customStatsLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
          customStatsLabel.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .medium)
          customStatsLabel.text = "Custom Info: Loading..."
          customStatsLabel.numberOfLines = 0
          sceneView.addSubview(customStatsLabel)

          // Position the label at the top
          NSLayoutConstraint.activate([
              customStatsLabel.leadingAnchor.constraint(equalTo: sceneView.leadingAnchor, constant: 10),
              customStatsLabel.trailingAnchor.constraint(lessThanOrEqualTo: sceneView.trailingAnchor, constant: -10),
              customStatsLabel.topAnchor.constraint(equalTo: sceneView.topAnchor, constant: 20),
              customStatsLabel.heightAnchor.constraint(lessThanOrEqualToConstant: 100)
          ])
      }

      @objc func updateCustomStats(_ notification: Notification) {
          guard let faceData = notification.object as? FaceData else { return }

          // Update the custom stats label with the FaceData
          DispatchQueue.main.async {
              self.customStatsLabel.text = """
              Yaw: \(faceData.yaw)
              Pitch: \(faceData.pitch)
              Roll: \(faceData.roll)
              Vertical Direction: \(faceData.vertPosition.toString())
              Horizontal Direction: \(faceData.horizPosition.toString())
              """
          }
      }

}

//MARK: - ARSCNViewDelegate
extension FaceTrackerViewController: ARSCNViewDelegate {
    
    func renderer(_ renderer: any SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        
        
        // Conductor Start
        
        conductor.start()
        conductor.isPlaying.toggle()
        
        
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
        
        conductor.updateWithNewData(faceData: faceData)
        
        // Post a notification with the FaceData
        NotificationCenter.default.post(name: .faceDataUpdated, object: faceData)


        contentController.renderer(renderer, didUpdate: contentNode, for: anchor)
        // Update the content controller with new data.
    }

    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        // Handle the removal of an ARFaceAnchor.

        faceAnchorsAndContentControllers[faceAnchor] = nil
        // Remove the face anchor from the dictionary.
    }
    
    
}

// MARK: - Notification Name Extension
extension Notification.Name {
    static let faceDataUpdated = Notification.Name("faceDataUpdated")
}
