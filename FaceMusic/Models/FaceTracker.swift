//
//  FaceTracker.swift
//  FaceMusic
//
//  Created by Ryan Ross
//

import Foundation
import ARKit
import SceneKit

/// Protocol for receiving face tracking updates
protocol FaceTrackerDelegate: AnyObject {
    func faceTracker(_ tracker: FaceTracker, didUpdateFaceData faceData: FaceData)
    func faceTracker(_ tracker: FaceTracker, didUpdatePitch pitch: Float)
    func faceTracker(_ tracker: FaceTracker, didAddFaceAnchor anchor: ARFaceAnchor, node: SCNNode, renderer: SCNSceneRenderer)
    func faceTracker(_ tracker: FaceTracker, didUpdateFaceAnchor anchor: ARFaceAnchor, node: SCNNode, renderer: SCNSceneRenderer)
    func faceTracker(_ tracker: FaceTracker, didRemoveFaceAnchor anchor: ARFaceAnchor)
    func faceTrackerSessionWasInterrupted(_ tracker: FaceTracker)
    func faceTrackerSessionInterruptionEnded(_ tracker: FaceTracker)
    func faceTracker(_ tracker: FaceTracker, didFailWithError error: Error)
}

/// Model responsible for ARKit face tracking
class FaceTracker: NSObject {

    // MARK: - Properties

    weak var delegate: FaceTrackerDelegate?

    private let faceDataBrain = FaceDataBrain.shared
    private(set) var currentFaceAnchor: ARFaceAnchor?
    private(set) var lastFacePitch: Float?

    private var faceAnchorsAndContentControllers: [ARFaceAnchor: VirtualContentController] = [:]
    var selectedVirtualContent: VirtualContentType = .texture

    // MARK: - ARKit Session Management

    /// Resets face tracking with a new ARFaceTrackingConfiguration
    func resetTracking(session: ARSession) {
        guard ARFaceTrackingConfiguration.isSupported else { return }

        let configuration = ARFaceTrackingConfiguration()
        configuration.maximumNumberOfTrackedFaces = 1
        configuration.isLightEstimationEnabled = false

        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])

        faceAnchorsAndContentControllers.removeAll()
    }

    /// Pauses the AR session
    func pauseSession(_ session: ARSession) {
        session.pause()
    }

    // MARK: - Face Data Processing

    /// Processes face anchor data and returns FaceData
    func processFaceData(_ faceAnchor: ARFaceAnchor, cameraTransform: simd_float4x4? = nil) -> FaceData {
        if let cameraTransform = cameraTransform {
            return faceDataBrain.processFaceData(faceAnchor, cameraTransform: cameraTransform)
        } else {
            return faceDataBrain.processFaceData(faceAnchor)
        }
    }

    /// Returns the current raw pitch provider closure
    func getCurrentRawPitchProvider() -> (() -> Float)? {
        guard let pitch = lastFacePitch else { return nil }

        return { [weak self] in
            if let latest = self?.lastFacePitch {
                return latest
            } else if let current = self?.currentFaceAnchor {
                return self?.faceDataBrain.processFaceData(current).pitch ?? pitch
            } else {
                return pitch
            }
        }
    }
}

// MARK: - ARSessionDelegate

extension FaceTracker: ARSessionDelegate {

    func session(_ session: ARSession, didFailWithError error: Error) {
        guard error is ARError else { return }
        delegate?.faceTracker(self, didFailWithError: error)
    }

    func sessionWasInterrupted(_ session: ARSession) {
        Log.line(actor: "👁️ FaceTracker", fn: "sessionWasInterrupted", "")
        delegate?.faceTrackerSessionWasInterrupted(self)
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        Log.line(actor: "👁️ FaceTracker", fn: "sessionInterruptionEnded", "")
        delegate?.faceTrackerSessionInterruptionEnded(self)
    }
}

// MARK: - ARSCNViewDelegate

extension FaceTracker: ARSCNViewDelegate {

    func renderer(_ renderer: any SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }

        currentFaceAnchor = faceAnchor

        // Create content controller for this face anchor
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let contentController = self.selectedVirtualContent.makeController()
            if node.childNodes.isEmpty, let contentNode = contentController.renderer(renderer, nodeFor: faceAnchor) {
                node.addChildNode(contentNode)
                self.faceAnchorsAndContentControllers[faceAnchor] = contentController
            }

            self.delegate?.faceTracker(self, didAddFaceAnchor: faceAnchor, node: node, renderer: renderer)
        }
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor,
              let contentController = faceAnchorsAndContentControllers[faceAnchor],
              let contentNode = contentController.contentNode else {
            return
        }

        currentFaceAnchor = faceAnchor

        // Process face data
        let faceData: FaceData
        if let session = renderer.session,
           let frame = session.currentFrame {
            faceData = faceDataBrain.processFaceData(faceAnchor, cameraTransform: frame.camera.transform)
        } else {
            faceData = faceDataBrain.processFaceData(faceAnchor)
        }

        lastFacePitch = faceData.pitch

        // Notify delegate of updates
        delegate?.faceTracker(self, didUpdateFaceData: faceData)
        delegate?.faceTracker(self, didUpdatePitch: faceData.pitch)
        delegate?.faceTracker(self, didUpdateFaceAnchor: faceAnchor, node: node, renderer: renderer)

        // Update content controller
        contentController.renderer(renderer, didUpdate: contentNode, for: anchor)
    }

    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }

        Log.line(actor: "👁️ FaceTracker", fn: "renderer.didRemove", "REMOVED AR ANCHOR")

        faceAnchorsAndContentControllers[faceAnchor] = nil

        if currentFaceAnchor == faceAnchor {
            currentFaceAnchor = nil
        }

        delegate?.faceTracker(self, didRemoveFaceAnchor: faceAnchor)
    }
}
