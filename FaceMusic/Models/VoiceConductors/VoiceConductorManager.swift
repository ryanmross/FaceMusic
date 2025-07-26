//
//  VoiceConductorManager.swift
//  FaceMusic
//
//  Created by Ryan Ross on 7/8/25.
//

import Foundation

class VoiceConductorManager {
    
    static let shared = VoiceConductorManager()
    
    /// Dictionary of available VoiceConductors keyed by ID
    private var conductors: [String: VoiceConductorProtocol] = [:]
    
    /// ID of the currently active conductor
    private var activeConductorID: String?
    
    private init() {
        for type in VoiceConductorRegistry.allTypes {
            let conductor = type.init()
            conductors[type.id] = conductor
        }
        activeConductorID = VoiceConductorRegistry.defaultType.id
    }
    
    /// Returns the currently active VoiceConductor (optional)
    func getActiveConductor() -> VoiceConductorProtocol? {
        guard let id = activeConductorID else { return nil }
        return conductors[id]
    }
    
    /// Computed property for the active conductor, returns a default if not found
    var activeConductor: VoiceConductorProtocol {
        if let id = activeConductorID, let conductor = conductors[id] {
            return conductor
        }
        return VocalTractConductor()
    }
    
    /// Exposes the currently active conductor ID
    func getActiveConductorID() -> String? {
        return activeConductorID
    }
    
    /// Returns all conductor IDs
    func allConductorIDs() -> [String] {
        return Array(conductors.keys)
    }
    
    /// Returns all conductor instances
    func allConductors() -> [VoiceConductorProtocol] {
        return Array(conductors.values)
    }
    
    /// Sets the active VoiceConductor by ID
    func setActiveConductor(id: String) {
        guard conductors[id] != nil else {
            print("VoiceConductor with ID '\(id)' does not exist.")
            return
        }
        activeConductorID = id
    }
    
    /// Switches to a new conductor type and applies settings, returns the new conductor
    func switchToConductor(settings: PatchSettings) -> VoiceConductorProtocol {
        print("VoiceConductorManager.switchToConductor() called with settings: \(settings)")
        
        let id = settings.activeVoiceID

        if let oldID = activeConductorID, let oldConductor = conductors[oldID] {
            oldConductor.stopAllVoices()
            AudioEngineManager.shared.removeAllInputsFromMixer()
        }

        guard let type = VoiceConductorRegistry.allTypes.first(where: { $0.id == id }) else {
            print("No VoiceConductor type found for ID '\(id)'")
            return VocalTractConductor()
        }

        let newConductor = type.init()
        conductors[id] = newConductor
        activeConductorID = id
        newConductor.applySettings(settings)
        return newConductor
    }
    
    /// Passthrough method to stop all voices on active conductor
    func stopAllVoices() {
        getActiveConductor()?.stopAllVoices()
    }
}
