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
    var activeConductorID: String?
    
    private init() {
        for descriptor in VoiceConductorRegistry.all {
            let conductor = descriptor.makeInstance()
            conductors[descriptor.id] = conductor
        }
        activeConductorID = VoiceConductorRegistry.defaultDescriptor.id
    }
    
    /// Returns the currently active VoiceConductor (optional)
    func getActiveConductor() -> VoiceConductorProtocol? {
        guard let id = activeConductorID else { return nil }
        return conductors[id]
    }
    
    /// Computed property for the active conductor, returns a default if not found
    var activeConductor: VoiceConductorProtocol {
        //print("####################### VoiceConductorManager.activeConductor getter called, activeConductorID: \(activeConductorID ?? "nil"), conductors[id]: \(String(describing: conductors[activeConductorID ?? "nil"]))")
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
    
    /// Sets the active VoiceConductor and applies its settings
    func setActiveConductor(settings: PatchSettings) {
        print("👨‍✈️ VoiceConductorManager.setActiveConductor() called with conductorID: \(settings.conductorID)")
        
        let id = settings.conductorID

        // Do nothing if the same conductor is already active
        if activeConductorID == id {
            if let existing = conductors[id] {
                existing.applySettings(settings)
                logPatches(settings, label: "👨‍✈️ VoiceConductorManager.setActiveConductor applySettings() called on existing conductor with settings")
                return
            }
        }

        // Stop old conductor and clean up
        if let oldID = activeConductorID, let oldConductor = conductors[oldID] {
            oldConductor.stopAllVoices()
            AudioEngineManager.shared.removeAllInputsFromMixer()
        }

        // Look up the descriptor and initialize
        guard let descriptor = VoiceConductorRegistry.descriptor(for: id) else {
            print("👨‍✈️VoiceConductorManager.  No VoiceConductorDescriptor found for ID '\(id)'")
            return
        }

        let newConductor = descriptor.makeInstance()
        conductors[id] = newConductor
        activeConductorID = id
        newConductor.applySettings(settings)
        print("👨‍✈️VoiceConductorManager.setActiveConductor FINISHED.")
    }
    
    /// Passthrough method to stop all voices on active conductor
    func stopAllVoices() {
        getActiveConductor()?.stopAllVoices()
    }
}
