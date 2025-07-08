//
//  VoiceConductorManager.swift
//  FaceMusic
//
//  Created by Ryan Ross on 7/8/25.
//

import Foundation

class VoiceConductorManager {
    
    /// Dictionary of available VoiceConductors keyed by ID
    private var voiceConductors: [String: VoiceConductorProtocol] = [:]
    
    /// ID of the currently active voice
    private var activeVoiceID: String?
    
    init() {
        // Create your default VoiceConductors here
        let defaultConductor = VocalTractConductor()
        voiceConductors["default"] = defaultConductor
        
        // Set default active voice
        activeVoiceID = "default"
    }
    
    /// Returns the currently active VoiceConductor
    func getActiveVoice() -> VoiceConductorProtocol? {
        guard let id = activeVoiceID else { return nil }
        return voiceConductors[id]
    }
    
    /// Sets the active VoiceConductor by ID
    func setActiveVoice(id: String) {
        guard voiceConductors[id] != nil else {
            print("VoiceConductor with ID '\(id)' does not exist.")
            return
        }
        activeVoiceID = id
    }
    
    /// Applies settings to the active VoiceConductor
    func applyPatchSettings(settings: PatchSettings) {
        // Update the active voice ID if needed
        setActiveVoice(id: settings.activeVoiceID)
        
        // Apply settings to the current conductor
        if let conductor = getActiveVoice() {
            conductor.applySettings(settings)
        } else {
            print("No active VoiceConductor to apply settings.")
        }
    }
}
